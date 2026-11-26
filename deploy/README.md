# Public demo deployment and Android download

The Android APK and the API are separate deployments. GitHub Releases hosts the
APK; a public HTTPS service runs the Go API with a persistent SQLite disk.
A laptop-only URL or emulator localhost cannot serve downloaded apps remotely.

## Free public demo on Render

[Deploy the API on Render](https://render.com/deploy?repo=https://github.com/abhayharne/bloodline)
using the root `render.yaml` Blueprint. Sign in, connect this repository, and keep
the service on the **Free** instance in Singapore. No paid disk or database is
required. The container creates its SQLite database under `/data`.

During Blueprint creation, enter the Nexconn app key and secret privately in
Render's prompts. The client APK must use the same project app key. Render
generates `JWT_SECRET`; the Singapore endpoints and demo settings are prefilled.
Never paste secrets into issues, release notes or source files.

The Blueprint disables automatic deploys so documentation commits do not reset the
demo. Deploy API updates manually after checks pass. Keep `DEV`, `NEXCONN_FAKE`
and `NEXCONN_MOCK` at `0`. Copy the assigned HTTPS service URL after the initial
deployment and verify `/health` and `/config` before building the APK.

Render's free tier sleeps after 15 idle minutes and discards local files on sleep,
restart and redeploy. Accounts, requests and stock may reset; startup seeds only
fictional profiles and stock. Chat rooms are hosted separately by Nexconn, but old
rooms are no longer linked to an account after the SQLite data resets. The app
waits up to 90 seconds for a cold service and offers a retry if unavailable.
Free-tier quotas can also suspend availability. See
[Render's documented limits](https://render.com/docs/free).

To publish a verified build:

```sh
scripts/build-android-release.sh https://YOUR-SERVICE.onrender.com
gh release create v1.0.0 dist/bloodline.apk dist/SHA256SUMS \
  --title 'BloodLine 1.0.0 — public Android demo' \
  --notes-file deploy/RELEASE_NOTES.md
```

Before publication, install the signed APK on a physical Android phone over mobile
data and verify registration, profile save, request creation, donor acceptance,
live chat and fulfillment. Confirm `/dev/reset` returns 404. Recheck login after
a service restart. Attach only the APK and checksum, not private build state.

## API

A portable container is in `deploy/Dockerfile`. Build from the repository root:

```sh
docker build -f deploy/Dockerfile -t bloodline-api .
docker run --env-file .env -e PORT=8080 -e DEV=0 -e NEXCONN_FAKE=0 -e NEXCONN_MOCK=0 \
  -v bloodline-data:/data -p 8080:8080 bloodline-api
```

Copy the variable names in [ENV.example](ENV.example) into the hosting environment, supplying secrets privately. For managed hosting, configure:

- Build context: repository root; Dockerfile: `deploy/Dockerfile`.
- Persistent disk: `/data`, writable by UID/GID 65532.
- Environment: `DB_PATH=/data/bloodline.db`; platform-selected `PORT`.
- Private secrets: `JWT_SECRET`, `NEXCONN_APP_SECRET`.
- Nexconn configuration: `NEXCONN_APP_KEY`, `NEXCONN_API_BASE`,
  `NEXCONN_API_BASE_BACKUP` from the existing private environment.
- `DEV=0`, `NEXCONN_FAKE=0`, `NEXCONN_MOCK=0`.
- `SEED_ON_EMPTY=1` initializes fictional accounts and stock once. Existing data survives restarts; live requests create real rooms through the API.
- On a private development server only, `DEV=1` also requires a private `DEV_KEY`; resets require the matching `X-Dev-Key` header.
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

## Temporary public demo

Build the server at `dist/public-demo/server`, install official cloudflared at
`/tmp/bloodline-deploy-tools/cloudflared-linux-amd64`, then run
`python3 scripts/start-public-demo.py`. This launcher never opens .env; the
server's configuration loader uses it privately. Safe environment overrides
force real Nexconn, demo OTP 123456, startup seeding, and all dev routes off.
It uses a separate demo database under ignored `dist/public-demo/`.

The API and tunnel PIDs are saved in `dist/public-demo/api.pid` and
`tunnel.pid`; logs remain private there. Stop those two owned processes to
end the public demo. A quick tunnel is temporary: it needs this computer awake
and online, and a restart usually changes the public URL. This is not permanent
hosting. Use only fictional demo information.
