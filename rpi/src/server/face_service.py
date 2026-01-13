from fastapi import FastAPI, UploadFile, Form
from fastapi.staticfiles import StaticFiles
import shutil
import sqlite3
import os 
from datetime import datetime

# -------------------------------
# Paths
# -------------------------------
BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, "../../data/db/PiGuardDB.db")
ASSETS_DIR = os.path.join(BASE_DIR, "../../data/assets/registered_faces")

if not os.path.exists(ASSETS_DIR):
    os.makedirs(ASSETS_DIR)

# Strangers directory (serve via HTTP and list from DB)
STRANGERS_DIR = os.path.join(BASE_DIR, "../../data/assets/strangers")
if not os.path.exists(STRANGERS_DIR):
    os.makedirs(STRANGERS_DIR)

# Flag file used to signal the stream server to reload registered encodings
RELOAD_FLAG = os.path.join(BASE_DIR, "../../data/.registered_update")
# ensure parent dir exists
os.makedirs(os.path.dirname(RELOAD_FLAG), exist_ok=True)

# -------------------------------
# RPi IP'si
# -------------------------------
RPi_IP = "100.80.70.109"  

# -------------------------------
# FastAPI app
# -------------------------------
app = FastAPI(title="PiGuard Face Upload Server")

app.mount("/assets", StaticFiles(directory=ASSETS_DIR), name="assets")
app.mount("/strangers", StaticFiles(directory=STRANGERS_DIR), name="strangers")

# -------------------------------
# Photo upload endpoint
# -------------------------------
@app.post("/upload_face")
async def upload_face(
    name: str = Form(...),
    image0: UploadFile = None,
    image1: UploadFile = None,
    image2: UploadFile = None
):
    """
    Flutter'dan gelen 3 fotoğrafı kaydeder ve SQLite'a ekler.
    """
    image_paths = []
    for idx, image in enumerate([image0, image1, image2]):
        if image:
            filename = f"{name}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{idx}.jpg"
            file_path = os.path.join(ASSETS_DIR, filename)
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(image.file, buffer)
            image_paths.append(filename)   
    
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute("""
        INSERT INTO registered_faces (name, image1, image2, image3)
        VALUES (?, ?, ?, ?)
    """, (
        name,
        image_paths[0] if len(image_paths) > 0 else None,
        image_paths[1] if len(image_paths) > 1 else None,
        image_paths[2] if len(image_paths) > 2 else None,
    ))

    conn.commit()
    conn.close()

    # touch the reload flag so the stream server reloads encodings immediately
    try:
        with open(RELOAD_FLAG, 'w') as f:
            f.write(datetime.now().isoformat())
    except Exception:
        pass

    return {"status": "success", "images": image_paths}

# -------------------------------
# List all registered faces
# -------------------------------
@app.get("/faces")
def list_faces():
    """
    SQLite DB'den kayıtlı yüzleri çeker ve Flutter'a JSON verir.
    """
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute("SELECT id, name, image1, image2, image3 FROM registered_faces")
    rows = c.fetchall()
    conn.close()

    faces = []
    for row in rows:
        (face_id, name, img1, img2, img3) = row

        images = []
        for img in [img1, img2, img3]:
            if img:
                images.append(f"http://{RPi_IP}:8001/assets/{img}")  

        faces.append({
            "id": face_id,
            "name": name,
            "images": images
        })

    return faces

# -------------------------------
# List strangers
# -------------------------------
@app.get("/strangers")
def list_strangers():
    """
    SQLite DB'deki strangers tablosunu döner. Her kayıt için image URL, metadata ve eklenme zamanı verilir.
    """
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    try:
        c.execute("SELECT id, image_path, metadata, added_at FROM strangers ORDER BY added_at DESC")
        rows = c.fetchall()
    except Exception:
        rows = []
    finally:
        conn.close()

    out = []
    for row in rows:
        sid, image_path, metadata, added_at = row
        if image_path:
            fname = os.path.basename(image_path)
            url = f"http://{RPi_IP}:8001/strangers/{fname}"
        else:
            url = None
        out.append({
            "id": sid,
            "image": url,
            "metadata": metadata,
            "added_at": added_at
        })
    return out

# -------------------------------
# Health check
# -------------------------------
@app.get("/")
def home():
    return {
        "status": "Server running",
        "upload_endpoint": "/upload_face",
        "face_list": "/faces"
    }

# -------------------------------
# Run server
# -------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
