from fastapi import FastAPI, UploadFile, Form
import shutil
import sqlite3
import os
from datetime import datetime

# -------------------------------
# Paths
# -------------------------------
BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, "../../data/db/registered_faces.db")
ASSETS_DIR = os.path.join(BASE_DIR, "../../data/assets")

if not os.path.exists(ASSETS_DIR):
    os.makedirs(ASSETS_DIR)

# -------------------------------
# FastAPI app
# -------------------------------
app = FastAPI(title="PiGuard Face Upload Server")

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
    Flutter veya başka istemciden 3 fotoğraf alır, 
    data/assets klasörüne kaydeder ve SQLite DB'ye ekler.
    """
    image_paths = []
    for idx, image in enumerate([image0, image1, image2]):
        if image:
            filename = f"{name}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{idx}.jpg"
            file_path = os.path.join(ASSETS_DIR, filename)
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(image.file, buffer)
            image_paths.append(file_path)
    
    # SQLite'a kaydet
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("""
        INSERT INTO registered_faces (name, image1, image2, image3)
        VALUES (?, ?, ?, ?)
    """, (name, *image_paths))
    conn.commit()
    conn.close()

    return {"status": "success", "images": image_paths}

# -------------------------------
# Health check / home
# -------------------------------
@app.get("/")
def home():
    return {"status": "Server running", "upload_endpoint": "/upload_face"}

# -------------------------------
# Run server
# -------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
