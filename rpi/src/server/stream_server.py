from fastapi import FastAPI, Response
from fastapi.responses import StreamingResponse
from picamera2 import Picamera2
import cv2
import uvicorn

app = FastAPI()

picam = Picamera2()
camera_config = picam.create_video_configuration(
    main={"format": "RGB888", "size": (640, 480)}
)
picam.configure(camera_config)
picam.start()

def camera_stream():
    while True:
        frame = picam.capture_array()
        _, jpeg = cv2.imencode('.jpg', frame)
        yield (
            b"--frame\r\n"
            b"Content-Type: image/jpeg\r\n\r\n" + jpeg.tobytes() + b"\r\n"
        )

@app.get("/video")
def video_feed():
    return StreamingResponse(camera_stream(), media_type="multipart/x-mixed-replace; boundary=frame")

@app.get("/")
def home():
    return {"status": "Camera streaming active"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
