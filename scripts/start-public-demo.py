#!/usr/bin/env python3
"""Start the real API and a quick tunnel without opening or displaying .env."""
from pathlib import Path
import json
import os
import subprocess
import time
import urllib.request

root = Path(__file__).resolve().parent.parent
state = root / "dist/public-demo"
state.mkdir(parents=True, exist_ok=True, mode=0o700)
state.chmod(0o700)
server = state / "server"
cloudflared = Path("/tmp/bloodline-deploy-tools/cloudflared-linux-amd64")
if not server.is_file() or not cloudflared.is_file():
    raise SystemExit("Build dist/public-demo/server and install cloudflared in /tmp/bloodline-deploy-tools first.")
for pid_file in state.glob("*.pid"):
    try:
        os.kill(int(pid_file.read_text()), 0)
    except (ProcessLookupError, ValueError):
        continue
    raise SystemExit(f"A prior demo process may still be running ({pid_file.name}); inspect it before restarting.")
env = os.environ.copy()
env.update({
    "PORT": "8080", "DB_PATH": str(state / "demo.db"),
    "DEV": "0", "NEXCONN_FAKE": "0", "NEXCONN_MOCK": "0",
    "SEED_ON_EMPTY": "1", "DEMO_OTP": "123456",
    "NEXCONN_APP_KEY": "qf3d5gbjqvm5h",
})
# The server's configuration loader owns .env loading; this script never opens it.
with (state / "api.log").open("ab") as output:
    api = subprocess.Popen([str(server)], cwd=root, env=env, stdout=output,
                           stderr=subprocess.STDOUT, start_new_session=True)
(state / "api.pid").write_text(str(api.pid))
for _ in range(30):
    if api.poll() is not None:
        raise SystemExit("API startup failed; private server log saved in dist/public-demo/api.log.")
    try:
        with urllib.request.urlopen("http://localhost:8080/health", timeout=1) as response:
            if json.load(response).get("status") == "ok":
                break
    except Exception:
        time.sleep(0.5)
else:
    api.terminate()
    raise SystemExit("API did not become healthy.")
with (state / "tunnel.log").open("ab") as output:
    tunnel = subprocess.Popen([str(cloudflared), "--no-autoupdate", "tunnel",
                               "--url", "http://localhost:8080"],
                              cwd=root, stdout=output, stderr=subprocess.STDOUT,
                              start_new_session=True)
(state / "tunnel.pid").write_text(str(tunnel.pid))
print("Real Nexconn API started with DEV/FAKE/MOCK off and isolated demo data.")
print("Quick tunnel starting; connection details are in dist/public-demo/tunnel.log.")
