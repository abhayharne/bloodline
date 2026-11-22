# Public demo deployment and Android download

The Android APK and the API are separate deployments. GitHub Releases hosts the
APK; a public HTTPS service runs the Go API with a persistent SQLite disk.
A laptop-only URL or emulator localhost cannot serve downloaded apps remotely.

## API

A portable container is in `deploy/Dockerfile`. Build from the repository root:

```sh
docker build -f deploy/Dockerfile -t bloodline-api .
docker run --env-file .env -e DEV=0 -e NEXCONN_FAKE=0 -e NEXCONN_MOCK=0 \
  -v bloodline-data:/data -p 8080:8080 bloodline-api
```

For managed hosting, configure:

- Build context: repository root; Dockerfile: `deploy/Dockerfile`.
- Persistent disk: `/data`, writable by UID/GID 65532.
- Environment: `DB_PATH=/data/bloodline.db`; platform-selected `PORT`.
- Private secrets: `JWT_SECRET`, `NEXCONN_APP_SECRET`.
- Nexconn configuration: `NEXCONN_APP_KEY`, `NEXCONN_API_BASE`,
  `NEXCONN_API_BASE_BACKUP` from the existing private environment.
- `DEV=0`, `NEXCONN_FAKE=0`, `NEXCONN_MOCK=0`.
- HTTPS ingress and health-check route `/health`.

Do not upload `.env`, SQLite data, signing files or secrets to the repository.
The current OTP flow uses demo code `123456`; describe a shared build as a
hackathon demo. It does not deliver SMS or verify real donor identities.

A temporary tunnel may be used for a timed demo, but the laptop, API process and
tunnel must remain running. A rebuilt APK is needed if that tunnel URL changes.

## Android signing and build

Use Flutter and Java 17+. From the repository root:

```sh
python3 scripts/create-android-signing.py
scripts/build-android-release.sh https://YOUR-PUBLIC-API
```

The key generator runs once. Securely back up
`app/android/key.properties` and `app/android/keystores/` together; retain the
same key for app updates. Existing signing files are never overwritten.
Release builds use this key rather than the Android debug key.

The build script checks the public API health/config before building a universal
APK with its API address embedded. Outputs: `dist/bloodline.apk` and
`dist/SHA256SUMS`. Upload these as release assets, not Git source files.

Verify the APK with the Android SDK's `apksigner verify --verbose` and inspect its
manifest with `apkanalyzer manifest permissions`. The release manifest must
contain `android.permission.INTERNET`.

## GitHub Release

Authenticate with `gh auth login` and push the reviewed release commit to
`abhayharne/bloodline`. Publish a versioned release with the APK, checksum and
optional launch video. The release notes must name the API/demo availability,
Android 7.0+ requirement, demo OTP and installation steps.

Once a release is published, the stable direct-download URL is:

`https://github.com/abhayharne/bloodline/releases/latest/download/bloodline.apk`

On an Android phone, open that link, download the APK, allow installation from
the browser if prompted, then install BloodLine. If an earlier debug build is
installed, uninstall it before installing the differently signed release
(uninstalling removes its local session/settings).
