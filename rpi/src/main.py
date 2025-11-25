from picamera2 import Picamera2
import cv2

picam = Picamera2()
camera_config = picam.create_video_configuration(
    main={"format": "RGB888", "size": (640, 480)})

picam.configure(camera_config)
picam.start()
print("Kamera başlatıldı. Çıkmak için 'q' tuşuna basınız.")
while True:
    frame = picam.capture_array()
    cv2.imshow("Raspberry Pi Kamera", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
picam.stop()
cv2.destroyAllWindows()
