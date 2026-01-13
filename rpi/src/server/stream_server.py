from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi import Request
from fastapi import WebSocket
from typing import List
from picamera2 import Picamera2
import cv2
import os
import sqlite3
import face_recognition
import time
from datetime import datetime
import numpy as np
from PIL import Image, ImageOps
import uvicorn
import asyncio
import threading

# =============================
# PATHS
# =============================
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
REGISTERED_DIR = os.path.join(BASE_DIR, 'data/assets/registered_faces')
STRANGERS_DIR = os.path.join(BASE_DIR, 'data/assets/strangers')
DB_PATH = os.path.join(BASE_DIR, 'data/db/PiGuardDB.db')
RELOAD_FLAG = os.path.join(BASE_DIR, 'data/.registered_update')

os.makedirs(STRANGERS_DIR, exist_ok=True)

# =============================
# TUNING (Pi Friendly)
# =============================
PROCESS_EVERY_N_FRAMES = 1
MATCH_THRESHOLD = 0.50  # stricter match threshold (lower = stricter)
STRANGER_THRESHOLD = 0.75
UNKNOWN_TIME_SEC = 5
TRACK_TIMEOUT_SEC = 2.0
RELOAD_REGISTERED_INTERVAL = 10  # seconds
MIN_SEEN_FRAMES = 3  # require a face to be seen for this many frames before deciding
SECOND_BEST_MARGIN = 0.15  # require this margin between best and second-best match
SAVE_DELAY_SEC = 3.0  # wait this many seconds before saving a stranger (gives time to confirm known)

# =============================
# UTILS
# =============================
def to_rgb_contiguous(img):
    if img.dtype != np.uint8 or not img.flags['C_CONTIGUOUS']:
        return np.ascontiguousarray(img, dtype=np.uint8)
    return img

profile_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_profileface.xml')
if profile_cascade.empty():
    print('[WARN] profile face cascade not loaded - profile detection disabled')

frontal_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
if frontal_cascade.empty():
    print('[WARN] frontal face cascade not loaded - frontal detection via cascade disabled')


def _rect_to_box(x, y, w, h):
    return (y, x + w, y + h, x)


def _expand_box(box, pad=0.15, imshape=None):
    t, r, btm, l = box
    w = max(1, r - l)
    h = max(1, b - t)
    padw = int(w * pad)
    padh = int(h * pad)
    nt = max(0, t - padh)
    nl = max(0, l - padw)
    if imshape is not None:
        nr = min(imshape[1] - 1, r + padw)
        nb = min(imshape[0] - 1, b + padh)
    else:
        nr = r + padw
        nb = b + padh
    return (nt, nr, nb, nl)

def _box_center(b):
    t, r, btm, l = b
    return ((l + r) // 2, (t + btm) // 2)


def _boxes_close(b1, b2, thresh=50):
    c1 = _box_center(b1)
    c2 = _box_center(b2)
    return np.linalg.norm([c1[0] - c2[0], c1[1] - c2[1]]) < thresh

def _clamp_box(box, imshape):
    # Ensure box coordinates are integers and within image bounds
    t, r, btm, l = box
    h, w = imshape[0], imshape[1]
    t = int(max(0, min(h - 1, t)))
    btm = int(max(0, min(h - 1, btm)))
    l = int(max(0, min(w - 1, l)))
    r = int(max(0, min(w - 1, r)))
    # Ensure top < bottom and left < right
    if btm <= t:
        btm = min(h - 1, t + 1)
    if r <= l:
        r = min(w - 1, l + 1)
    return (t, r, btm, l)


def _find_box_index_by_proximity(boxes, target_box, thresh=60):
    if not boxes:
        return None
    tx, ty = _box_center(target_box)
    best_i = None
    best_d = float('inf')
    for i, b in enumerate(boxes):
        bx, by = _box_center(b)
        d = np.linalg.norm([tx - bx, ty - by])
        if d < best_d:
            best_d = d
            best_i = i
    return best_i if best_d < thresh else None

# =============================
# LOAD REGISTERED FACES
# =============================
def load_registered_encodings():
    persons = []
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("SELECT name, image1, image2, image3 FROM registered_faces")
        rows = c.fetchall()
        conn.close()
    except Exception:
        rows = []

    for name, img1, img2, img3 in rows:
        encodings = []
        for img in [img1, img2, img3]:
            if not img:
                continue
            path = os.path.join(REGISTERED_DIR, img)
            if not os.path.exists(path):
                continue
            try:
                pil = Image.open(path)
                pil = ImageOps.exif_transpose(pil).convert('RGB')
                arr = np.ascontiguousarray(np.array(pil), dtype=np.uint8)

                e = face_recognition.face_encodings(arr, model='small')
                if e:
                    encodings.append(e[0])

                # make flipped array contiguous to avoid passing negative-stride views to dlib/OpenCV
                flipped = np.ascontiguousarray(arr[:, ::-1, :])
                e2 = face_recognition.face_encodings(flipped, model='small')
                if e2:
                    encodings.append(e2[0])
            except Exception as ex:
                print('[REGISTER LOAD ERROR]', ex)
        if encodings:
            persons.append({'name': name, 'encodings': encodings})
    print(f'[INFO] Registered persons loaded: {len(persons)}')
    return persons

# =============================
# SAVE STRANGER (DB + FILE)
# =============================
# Replace async save_stranger with synchronous version that schedules websocket broadcasts thread-safely
def save_stranger(frame_rgb, box):
    top, right, bottom, left = box
    ts = datetime.now().strftime('%Y%m%d%H%M%S%f')
    filename = f'stranger_{ts}.jpg'
    path = os.path.join(STRANGERS_DIR, filename)

    # Clamp box to frame and make sure crop is valid
    try:
        h, w = frame_rgb.shape[0], frame_rgb.shape[1]
        top, right, bottom, left = _clamp_box((top, right, bottom, left), frame_rgb.shape)
        if bottom - top <= 0 or right - left <= 0:
            return
        crop_rgb = frame_rgb[top:bottom, left:right]
        if crop_rgb.size == 0:
            return
        crop_bgr = cv2.cvtColor(crop_rgb, cv2.COLOR_RGB2BGR)
    except Exception as e:
        print('[STRANGER CROP ERROR]', e)
        return

    try:
        saved = cv2.imwrite(path, crop_bgr)
        if not saved:
            print('[STRANGER SAVE FAILED] cv2.imwrite returned False', path)
            return
    except Exception as e:
        print('[STRANGER SAVE EXCEPTION]', e)
        return

    conn = None
    try:
        conn = sqlite3.connect(DB_PATH, timeout=10)
        c = conn.cursor()
        c.execute("CREATE TABLE IF NOT EXISTS strangers (id INTEGER PRIMARY KEY AUTOINCREMENT, image_path TEXT, metadata TEXT, added_at TEXT)")
        # store only the filename so clients can fetch via /strangers/<filename>
        added_at = datetime.now().isoformat()
        c.execute('INSERT INTO strangers (image_path, metadata, added_at) VALUES (?, ?, ?)',
                  (filename, f'box=({top},{right},{bottom},{left})', added_at))
        stranger_id = c.lastrowid

        # ensure notifications table exists and insert a notification reference
        c.execute('''CREATE TABLE IF NOT EXISTS notifications (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        stranger_id INTEGER,
                        FOREIGN KEY (stranger_id) REFERENCES strangers(id)
                    )''')
        c.execute('INSERT INTO notifications (stranger_id) VALUES (?)', (stranger_id,))
        conn.commit()

        # schedule websocket broadcast in a thread-safe way using the main app event loop
        try:
            # use the main event loop stored on app.state (set at startup). This decouples broadcasts from
            # active websocket connections so notifications can be scheduled even if no client is currently connected.
            loop = getattr(app.state, 'loop', None)
            if loop:
                asyncio.run_coroutine_threadsafe(
                    manager.broadcast({
                        "type": "stranger_detected",
                        "id": stranger_id,
                        "image": filename,
                        "time": added_at
                    }),
                    loop
                )
        except Exception as e:
            print('[NOTIF BROADCAST ERROR]', e)

        print('[STRANGER SAVED]', path)
    except Exception as e:
        print('[DB ERROR] Could not insert stranger record or notification:', e)
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass

# =============================
# TRACKING
# =============================
class Track:
    def __init__(self, box):
        self.box = box
        self.centroid = self._center(box)
        self.first_seen = time.time()
        self.last_seen = time.time()
        self.best_distance = 1.0
        self.known = False
        self.saved = False
        # number of consecutive frames this track has been observed
        self.seen_frames = 1
        # name of the currently best matched registered person (if any)
        self.matched_name = None
        # consecutive frames matched to matched_name
        self.consecutive_matches = 0
        # timestamp when this track first became a candidate for saving as stranger
        self.save_candidate_since = None

    def _center(self, b):
        t, r, btm, l = b
        return ((l + r) // 2, (t + btm) // 2)


class Tracker:
    def __init__(self):
        self.tracks = []

    def update(self, boxes):
        now = time.time()
        updated = []
        used = set()  # indices of tracks already matched this frame

        for box in boxes:
            # ensure tuple/int
            box = tuple(int(x) for x in box)
            cx, cy = ((box[3] + box[1]) // 2, (box[0] + box[2]) // 2)

            # find nearest unused existing track within threshold
            best_i = None
            best_d = float('inf')
            for i, t in enumerate(self.tracks):
                if i in used:
                    continue
                tx, ty = t.centroid
                d = np.linalg.norm([cx - tx, cy - ty])
                if d < 40 and d < best_d:
                    best_d = d
                    best_i = i

            if best_i is not None:
                # match to this existing track
                t = self.tracks[best_i]
                t.box = box
                t.centroid = (cx, cy)
                t.last_seen = now
                t.seen_frames = getattr(t, 'seen_frames', 0) + 1
                updated.append(t)
                used.add(best_i)
            else:
                # create new track for this box
                updated.append(Track(box))

        # Keep only recently seen tracks
        self.tracks = [t for t in updated if now - t.last_seen < TRACK_TIMEOUT_SEC]
        return self.tracks

# =============================
# FASTAPI + CAMERA
# =============================
app = FastAPI()
# serve saved stranger images so clients can fetch them by filename
app.mount('/strangers', StaticFiles(directory=STRANGERS_DIR), name='strangers')
picam = Picamera2()
picam.configure(picam.create_video_configuration(main={'format': 'RGB888', 'size': (640, 480)}))
picam.start()

# Shared frame buffer and lock (single camera source for both streamer and detector)
latest_frame = None
latest_frame_lock = threading.Lock()

async def frame_grabber():
    """Continuously grab frames from the camera in a thread-friendly way and update latest_frame."""
    global latest_frame
    while True:
        try:
            # capture_array is blocking; run in thread to avoid blocking event loop
            frame = await asyncio.to_thread(picam.capture_array)
            frame = to_rgb_contiguous(frame)
            with latest_frame_lock:
                latest_frame = frame
        except Exception as e:
            print('[FRAME GRAB ERROR]', e)
            await asyncio.sleep(0.1)
            continue
        # small sleep to yield CPU
        await asyncio.sleep(0.01)

async def face_detection_loop():
    """Background loop that performs face detection, encoding, tracking and calls save_stranger as needed.
    This runs continuously regardless of client connections.
    """
    registered = load_registered_encodings()
    last_reload = time.time()
    tracker = Tracker()
    frame_count = 0
    skip_processing_until = 0.0

    while True:
        # obtain a copy of the latest frame in a thread-safe manner
        with latest_frame_lock:
            frame = None if latest_frame is None else latest_frame.copy()

        if frame is None:
            await asyncio.sleep(0.05)
            continue

        frame_count += 1

        # immediate reload when flag file is present (set by face_service) to pick up new registrations
        try:
            if os.path.exists(RELOAD_FLAG):
                registered = load_registered_encodings()
                last_reload = time.time()
                tracker = Tracker()  # reset tracker to avoid stale tracks using old encodings
                skip_processing_until = time.time() + 1.0
                try:
                    os.remove(RELOAD_FLAG)
                except Exception:
                    pass
        except Exception:
            pass

        # reload registered encodings periodically so new users are picked up
        if time.time() - last_reload > RELOAD_REGISTERED_INTERVAL:
            try:
                registered = load_registered_encodings()
                tracker = Tracker()
                skip_processing_until = time.time() + 1.0
            except Exception as e:
                print('[REGISTERED RELOAD ERROR]', e)
            last_reload = time.time()

        # If we recently reloaded, skip face recognition for a short window to avoid stale tracker state
        if time.time() < skip_processing_until:
            await asyncio.sleep(0.01)
            continue

        if frame_count % PROCESS_EVERY_N_FRAMES == 0:
            try:
                boxes = face_recognition.face_locations(frame, model='hog')
            except Exception as e:
                print('[FACE LOCATIONS ERROR]', e)
                boxes = []

            try:
                gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
            except Exception:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY) if frame.ndim == 3 else frame

            try:
                if not frontal_cascade.empty():
                    rects_fr = frontal_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                    for (x, y, w, h) in rects_fr:
                        b = _rect_to_box(x, y, w, h)
                        b = _expand_box(b, pad=0.12, imshape=frame.shape)
                        b = _clamp_box(b, frame.shape)
                        if not any(_boxes_close(b, ob, thresh=60) for ob in boxes):
                            boxes.append(b)
            except Exception:
                pass

            try:
                if not profile_cascade.empty():
                    rects = profile_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                    for (x, y, w, h) in rects:
                        b = _rect_to_box(x, y, w, h)
                        b = _expand_box(b, pad=0.18, imshape=frame.shape)
                        b = _clamp_box(b, frame.shape)
                        if not any(_boxes_close(b, ob, thresh=70) for ob in boxes):
                            boxes.append(b)
            except Exception:
                pass

            try:
                if not profile_cascade.empty():
                    flipped = np.ascontiguousarray(np.fliplr(frame))
                    gray_f = cv2.cvtColor(flipped, cv2.COLOR_RGB2GRAY)
                    rects_f = profile_cascade.detectMultiScale(gray_f, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                    fw = frame.shape[1]
                    for (x, y, w, h) in rects_f:
                        orig_x = fw - (x + w)
                        b = (y, orig_x + w, y + h, orig_x)
                        b = _expand_box(b, pad=0.18, imshape=frame.shape)
                        b = _clamp_box(b, frame.shape)
                        if not any(_boxes_close(b, ob, thresh=70) for ob in boxes):
                            boxes.append(b)
            except Exception:
                pass

            try:
                encs = face_recognition.face_encodings(frame, boxes, model='small') if boxes else []
            except Exception as e:
                print('[FACE ENCODINGS ERROR]', e)
                encs = []

            try:
                import gc
                gc.collect()
            except Exception:
                pass

            tracks = tracker.update(boxes)

            for t in tracks:
                try:
                    idx = _find_box_index_by_proximity(boxes, t.box, thresh=70)
                    if idx is None:
                        continue
                except ValueError:
                    continue

                enc = encs[idx] if idx < len(encs) else None
                if enc is None:
                    if not t.known and not t.saved and getattr(t, 'seen_frames', 0) >= MIN_SEEN_FRAMES:
                        if t.save_candidate_since is None:
                            t.save_candidate_since = time.time()
                        if time.time() - t.save_candidate_since >= SAVE_DELAY_SEC:
                            save_stranger(frame, t.box)
                            t.saved = True
                            t.save_candidate_since = None
                    continue

                dists = []
                for p in registered:
                    try:
                        d = min(face_recognition.face_distance(p['encodings'], enc)) if len(p['encodings']) > 0 else 1.0
                    except Exception:
                        d = 1.0
                    dists.append((p.get('name'), d))

                if dists:
                    dists.sort(key=lambda x: x[1])
                    best_name, best_d = dists[0]
                    second_best_d = dists[1][1] if len(dists) > 1 else 1.0
                else:
                    best_name, best_d, second_best_d = (None, 1.0, 1.0)

                t.best_distance = best_d
                accepted = best_name is not None and best_d <= MATCH_THRESHOLD and (second_best_d - best_d) >= SECOND_BEST_MARGIN

                if accepted:
                    if t.matched_name == best_name:
                        t.consecutive_matches += 1
                    else:
                        t.matched_name = best_name
                        t.consecutive_matches = 1
                else:
                    t.matched_name = None
                    t.consecutive_matches = 0

                if t.consecutive_matches >= MIN_SEEN_FRAMES:
                    t.known = True
                    t.save_candidate_since = None

                if not accepted and not t.saved and getattr(t, 'seen_frames', 0) >= MIN_SEEN_FRAMES:
                    save_stranger(frame, t.box)
                    t.saved = True
                t.save_candidate_since = None

        # small sleep to yield CPU
        await asyncio.sleep(0.01)

# =============================
# STREAM
# =============================
def camera_stream():
    """Stream the latest captured frame as MJPEG. Does not perform detection/encoding.
    Uses the shared latest_frame populated by frame_grabber to avoid multiple camera accesses.
    """
    while True:
        with latest_frame_lock:
            f = None if latest_frame is None else latest_frame.copy()
        if f is None:
            time.sleep(0.05)
            continue
        try:
            draw = f
        except Exception:
            draw = f if isinstance(f, np.ndarray) else None
        if draw is None:
            time.sleep(0.01)
            continue
        try:
            ok, jpeg = cv2.imencode('.jpg', draw)
            if not ok:
                time.sleep(0.05)
                continue
            chunk = jpeg.tobytes()
            yield (b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + chunk + b'\r\n')
        except Exception as e:
            print('[STREAM ENCODE ERROR]', e)
            time.sleep(0.05)
            continue

# =============================
# ROUTES
# =============================
@app.get('/video')
def video():
    return StreamingResponse(camera_stream(), media_type='multipart/x-mixed-replace; boundary=frame')

@app.get('/')
def home():
    return {'status': 'PiGuard face recognition active'}

# New endpoints to expose notifications to clients (e.g., Flutter)
@app.get('/notifications')
def get_notifications(request: Request):
    """Return pending notifications joined with stranger info."""
    rows = []
    conn = None
    try:
        conn = sqlite3.connect(DB_PATH, timeout=10)
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS notifications (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        stranger_id INTEGER,
                        FOREIGN KEY (stranger_id) REFERENCES strangers(id)
                    )''')
        c.execute('''SELECT n.id, n.stranger_id, s.image_path, s.added_at
                     FROM notifications n
                     JOIN strangers s ON n.stranger_id = s.id
                     ORDER BY n.id DESC LIMIT 50''')
        rows = c.fetchall()
    except Exception as e:
        print('[NOTIF READ ERROR]', e)
        rows = []
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass

    base = str(request.base_url).rstrip('/')
    return {'notifications': [
        {
            'id': r[0],
            'stranger_id': r[1],
            'image_path': r[2],
            'image_url': f"{base}/strangers/{os.path.basename(r[2])}",
            'added_at': r[3]
        } for r in rows
    ]}

@app.delete('/notifications/{nid}')
def delete_notification(nid: int):
    """Delete a notification (call from client after handling)."""
    conn = None
    try:
        conn = sqlite3.connect(DB_PATH, timeout=10)
        c = conn.cursor()
        c.execute('DELETE FROM notifications WHERE id = ?', (nid,))
        conn.commit()
        return {'deleted': True, 'id': nid}
    except Exception as e:
        print('[NOTIF DELETE ERROR]', e)
        return {'deleted': False, 'id': nid}
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass




class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        try:
            self.active_connections.remove(websocket)
        except ValueError:
            pass

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                try:
                    self.active_connections.remove(connection)
                except ValueError:
                    pass

manager = ConnectionManager()


@app.websocket("/ws/notifications")
async def websocket_notifications(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()  # ping için
    except:
        manager.disconnect(websocket)

# =============================
# RUN
# =============================
@app.on_event("startup")
async def startup_event():
    # start frame grabber and face detection loop in background
    try:
        # store reference to main event loop so thread-safe broadcasts can be scheduled even when
        # no websocket client is currently connected
        app.state.loop = asyncio.get_running_loop()
        asyncio.create_task(frame_grabber())
        asyncio.create_task(face_detection_loop())
    except Exception as e:
        print('[STARTUP TASK ERROR]', e)

if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8000)




