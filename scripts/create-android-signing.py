#!/usr/bin/env python3
"""Create a persistent private signing key without printing passwords."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
android = root / "app/android"
properties = android / "key.properties"
key_dir = android / "keystores"
keystore = key_dir / "bloodline-release.jks"
if properties.exists() or keystore.exists():
    raise SystemExit("Signing files already exist; keep them for future app updates.")
keytool = shutil.which("keytool")
if not keytool:
    candidate = Path("/snap/android-studio/current/jbr/bin/keytool")
    keytool = str(candidate) if candidate.is_file() else None
if not keytool:
    raise SystemExit("keytool is required. Set JAVA_HOME or install a JDK.")
os.umask(0o077)
key_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
password = secrets.token_urlsafe(36)
env = os.environ.copy()
env["BLOODLINE_SIGNING_PASSWORD"] = password
subprocess.run([
    keytool, "-genkeypair", "-noprompt", "-keystore", str(keystore),
    "-storetype", "JKS", "-keyalg", "RSA", "-keysize", "3072",
    "-validity", "10000", "-alias", "bloodline",
    "-storepass:env", "BLOODLINE_SIGNING_PASSWORD",
    "-keypass:env", "BLOODLINE_SIGNING_PASSWORD",
    "-dname", "CN=BloodLine Android, O=BloodLine, C=IN"
], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
properties.write_text(
    f"storePassword={password}\nkeyPassword={password}\n"
    "keyAlias=bloodline\nstoreFile=keystores/bloodline-release.jks\n"
)
properties.chmod(0o600)
keystore.chmod(0o600)
print("Created private Android release signing files. Back up key.properties and keystores/ securely; neither belongs in Git.")
