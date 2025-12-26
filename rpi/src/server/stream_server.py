from fastapi import FastAPI
from fastapi.responses import StreamingResponse
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

# =============================
# PATHS
# =============================
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
REGISTERED_DIR = os.path.join(BASE_DIR, 'data/assets/registered_faces')
STRANGERS_DIR = os.path.join(BASE_DIR, 'data/assets/strangers')
DB_PATH = os.path.join(BASE_DIR, 'data/db/PiGuardDB.db')

os.makedirs(STRANGERS_DIR, exist_ok=True)

# =============================
# TUNING (Pi Friendly)
# =============================
PROCESS_EVERY_N_FRAMES = 1
MATCH_THRESHOLD = 0.65
STRANGER_THRESHOLD = 0.75
UNKNOWN_TIME_SEC = 5
TRACK_TIMEOUT_SEC = 2.0

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

                flipped = arr[:, ::-1, :]
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
def save_stranger(frame_rgb, box):
    top, right, bottom, left = box
    ts = datetime.now().strftime('%Y%m%d%H%M%S%f')
    filename = f'stranger_{ts}.jpg'
    path = os.path.join(STRANGERS_DIR, filename)

    crop_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)[top:bottom, left:right]
    if crop_bgr.size == 0:
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
        c.execute('INSERT INTO strangers (image_path, metadata, added_at) VALUES (?, ?, ?)',
                  (path, f'box=({top},{right},{bottom},{left})', datetime.now().isoformat()))
        conn.commit()
        print('[STRANGER SAVED]', path)
    except Exception as e:
        print('[DB ERROR] Could not insert stranger record:', e)
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

    def _center(self, b):
        t, r, btm, l = b
        return ((l + r) // 2, (t + btm) // 2)


class Tracker:
    def __init__(self):
        self.tracks = []

    def update(self, boxes):
        now = time.time()
        updated = []
        for box in boxes:
            cx, cy = ((box[3] + box[1]) // 2, (box[0] + box[2]) // 2)
            matched = False
            for t in self.tracks:
                tx, ty = t.centroid
                if np.linalg.norm([cx - tx, cy - ty]) < 50:
                    t.box = box
                    t.centroid = (cx, cy)
                    t.last_seen = now
                    updated.append(t)
                    matched = True
                    break
            if not matched:
                updated.append(Track(box))
        self.tracks = [t for t in updated if now - t.last_seen < TRACK_TIMEOUT_SEC]
        return self.tracks

# =============================
# FASTAPI + CAMERA
# =============================
app = FastAPI()
picam = Picamera2()
picam.configure(picam.create_video_configuration(main={'format': 'RGB888', 'size': (640, 480)}))
picam.start()

# =============================
# STREAM
# =============================
def camera_stream():
    registered = load_registered_encodings()
    tracker = Tracker()
    frame_count = 0

    while True:
        frame = to_rgb_contiguous(picam.capture_array())
        frame_count += 1

        if frame_count % PROCESS_EVERY_N_FRAMES == 0:
            boxes = face_recognition.face_locations(frame, model='hog')

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
                        if not any(_boxes_close(b, ob, thresh=70) for ob in boxes):
                            boxes.append(b)
            except Exception:
                pass

            try:
                if not profile_cascade.empty():
                    flipped = np.fliplr(frame)
                    gray_f = cv2.cvtColor(flipped, cv2.COLOR_RGB2GRAY)
                    rects_f = profile_cascade.detectMultiScale(gray_f, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                    fw = frame.shape[1]
                    for (x, y, w, h) in rects_f:
                        orig_x = fw - (x + w)
                        b = (y, orig_x + w, y + h, orig_x)
                        b = _expand_box(b, pad=0.18, imshape=frame.shape)
                        if not any(_boxes_close(b, ob, thresh=70) for ob in boxes):
                            boxes.append(b)
            except Exception:
                pass
            encs = face_recognition.face_encodings(frame, boxes, model='small')
            tracks = tracker.update(boxes)

            for t in tracks:
                try:
                    idx = boxes.index(t.box)
                except ValueError:
                    continue

                enc = encs[idx] if idx < len(encs) else None
                if enc is None:
                    if not t.known and not t.saved:
                        save_stranger(frame, t.box)
                        t.saved = True
                    continue

                for p in registered:
                    try:
                        d = min(face_recognition.face_distance(p['encodings'], enc)) if len(p['encodings']) > 0 else 1.0
                    except Exception:
                        d = 1.0
                    t.best_distance = min(t.best_distance, d)
                    if d <= MATCH_THRESHOLD:
                        t.known = True
                        break

                if not t.known and not t.saved and t.best_distance > STRANGER_THRESHOLD:
                    save_stranger(frame, t.box)
                    t.saved = True

        draw = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        for t in tracker.tracks:
            top, right, bottom, left = t.box
            color = (0, 255, 0) if t.known else (0, 0, 255)
            label = 'Known' if t.known else 'Unknown'
            cv2.rectangle(draw, (left, top), (right, bottom), color, 2)
            cv2.putText(draw, label, (left, top - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)

        _, jpeg = cv2.imencode('.jpg', draw)
        yield (b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')

        time.sleep(0.01)

# =============================
# ROUTES
# =============================
@app.get('/video')
def video():
    return StreamingResponse(camera_stream(), media_type='multipart/x-mixed-replace; boundary=frame')

@app.get('/')
def home():
    return {'status': 'PiGuard face recognition active'}

# =============================
# RUN
# =============================
if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8000)

