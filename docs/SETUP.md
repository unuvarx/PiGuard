# PiGuard (Raspberry Pi) — Setup & Run Guide

This document describes how to set up and run the PiGuard face recognition server on a Raspberry Pi from scratch. It assumes you have Raspbian / Raspberry Pi OS with Python 3.9+ installed and have basic familiarity with the terminal.

Prerequisites
- Raspberry Pi 3/4 with Raspberry Pi OS
- Internet access
- Camera module or USB camera compatible with libcamera / Picamera2
- A user account with sudo privileges

1) Update OS and install system packages

Open a terminal and run:

sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake libopenblas-dev liblapack-dev libx11-dev libgtk-3-dev libatlas-base-dev libjpeg-dev libtiff-dev libpng-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev pkg-config

Install dependencies required by face_recognition/dlib:

sudo apt install -y libboost-python-dev libboost-thread-dev libboost-system-dev

2) Install Python and virtual environment

Install Python3 and pip if not present:

sudo apt install -y python3 python3-venv python3-pip

Create and activate a virtual environment (recommended):

cd /home/pi/Desktop/pi/PiGuard
python3 -m venv .venv
source .venv/bin/activate

3) Install Python packages

We provided a requirements file at docs/requirements.txt. Install packages with pip:

pip install --upgrade pip
pip install -r docs/requirements.txt

Note: Building dlib and face_recognition on Raspberry Pi can be slow and may require swap increase or prebuilt wheels. If pip install fails for dlib, try installing a compatible wheel for your platform or compile dlib from source.

4) Initialize the database

The first step is to initialize the SQLite database schema. Run the database init script:

source .venv/bin/activate  # if not already active
python3 /home/pi/Desktop/pi/PiGuard/rpi/src/database/db_init.py

This script will create necessary tables and prepare the data folders.

5) Prepare camera and permissions

- Ensure the camera is enabled in Raspberry Pi Configuration (raspi-config) or that a USB camera is connected.
- If using the Raspberry Pi Camera Module, ensure libcamera and picamera2 are correctly installed.

Optional: Access via Tailscale (for remote devices)

If you want to access the PiGuard server from other networks or devices without configuring router NAT/port forwarding, Tailscale provides a simple, secure VPN-like mesh.

Install Tailscale on the Raspberry Pi:

sudo apt install -y curl
curl -fsSL https://tailscale.com/install.sh | sh

Authenticate and bring the node online:

# Interactive login (opens a browser on another machine)
sudo tailscale up

# OR - headless login using an auth key (recommended for headless setups):
# 1) Create an auth key at https://login.tailscale.com/admin/settings/keys
# 2) Run on the Pi:
sudo tailscale up --authkey <your-auth-key>

Find the Pi's Tailscale IP address:

tailscale ip -4

Now access the PiGuard server from any device on your Tailscale network using the Tailscale IP:

Video stream (MJPEG): http://<tailscale-ip>:8000/video
Root/health: http://<tailscale-ip>:8000/
Notifications/WS endpoints: replace <raspi-ip> with <tailscale-ip>

Notes:
- Install the Tailscale client on your other devices (Windows, macOS, Linux, iOS, Android) and log in with the same Tailscale account or be on the same tailnet.
- If you need the Pi to be reachable by a stable hostname, use the Tailscale machine name (e.g. <name>.beta.tailscale.net) or enable MagicDNS in your Tailscale admin settings.
- For advanced use (subnet routing, ACLs), configure these from the Tailscale admin console.

6) Run the face registration service (optional)

If you plan to register known users via the face_service, start it first (it may create the flag file to force reload):

source .venv/bin/activate
python3 /home/pi/Desktop/pi/PiGuard/rpi/src/server/face_service.py

7) Start the stream server (main app)

Start the main FastAPI server which streams video and runs background face detection:

source .venv/bin/activate
python3 /home/pi/Desktop/pi/PiGuard/rpi/src/server/stream_server.py

By default the server listens on http://0.0.0.0:8000

8) How to use

- Video stream (MJPEG): http://<raspi-ip>:8000/video
- Health/root: http://<raspi-ip>:8000/
- Notifications REST API: http://<raspi-ip>:8000/notifications (GET)
- Delete notification: DELETE http://<raspi-ip>:8000/notifications/{id}
- Save strangers images are served at: http://<raspi-ip>:8000/strangers/<filename>
- WebSocket notifications: ws://<raspi-ip>:8000/ws/notifications (connect and send occasional pings)

Typical workflow
1. Initialize DB: python3 rpi/src/database/db_init.py
2. (Optional) Run face registration UI/service: python3 rpi/src/server/face_service.py
3. Start stream server: python3 rpi/src/server/stream_server.py
4. Visit /video to see the camera stream, or connect a client that listens for notifications.

Troubleshooting
- If face_recognition or dlib installation fails, try installing prebuilt wheels for your Python version and Raspberry Pi architecture.
- If camera capture fails, verify picamera2 and libcamera are installed and that camera access is enabled.
- Check logs printed to the console for errors like [FRAME GRAB ERROR], [FACE ENCODINGS ERROR], [DB ERROR].

Files of interest
- rpi/src/server/stream_server.py  -> main server, MJPEG stream, background detection, notification endpoints
- rpi/src/server/face_service.py  -> face registration helper/service
- rpi/src/database/db_init.py     -> creates SQLite DB and directories
- rpi/data/assets/registered_faces -> place registered user images here
- rpi/data/assets/strangers       -> saved stranger images

End of document.
