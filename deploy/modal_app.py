"""Deploy the Go API with: scripts/deploy-modal.sh."""

import os
from pathlib import Path
import subprocess
import threading

import modal

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "dist" / "modal" / "bloodline-api"
RUNTIME = {
    "PORT": "8080",
    "DB_PATH": "/data/bloodline.db",
    "NEXCONN_API_BASE": "https://api.sg-light-api.com",
    "NEXCONN_API_BASE_BACKUP": "https://api-b.sg-light-api.com",
    "DEMO_OTP": "123456",
    "MATCH_RADIUS_KM": "10",
    "FEATURES": "",
    "SEED_ON_EMPTY": "1",
    "DEV": "0",
    "NEXCONN_FAKE": "0",
    "NEXCONN_MOCK": "0",
}

app = modal.App("bloodline")
data = modal.Volume.from_name("bloodline-data", create_if_missing=True, version=2)
image = (
    modal.Image.debian_slim(python_version="3.12")
    .add_local_file(BINARY, "/usr/local/bin/bloodline", copy=True)
    .env(RUNTIME)
)


@app.function(
    image=image,
    secrets=[modal.Secret.from_name(
        "bloodline-api",
        required_keys=["JWT_SECRET", "NEXCONN_APP_KEY", "NEXCONN_APP_SECRET"],
    )],
    volumes={"/data": data},
    cpu=(0.125, 0.5),
    memory=(256, 512),
    min_containers=0,
    max_containers=1,
    scaledown_window=30,
    timeout=120,
    region="ap",
    routing_region="ap-south",
)
@modal.concurrent(max_inputs=32)
@modal.web_server(8080, startup_timeout=60, label="bloodline-api")
def api():
    # Override flags even if the Secret contains additional development settings.
    environment = os.environ.copy()
    environment.update(RUNTIME)
    process = subprocess.Popen(["/usr/local/bin/bloodline"], env=environment)

    def watch_server():
        process.wait()
        # A dead Go process must not leave a healthy-looking gateway container.
        os._exit(1)

    threading.Thread(target=watch_server, daemon=True).start()
