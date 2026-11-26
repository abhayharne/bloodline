# Public demo deployment and Android download

The Android APK and the API are separate deployments. GitHub Releases hosts the
APK; a public HTTPS service runs the Go API with a persistent SQLite disk.
A laptop-only URL or emulator localhost cannot serve downloaded apps remotely.

## Public demo on Modal

Install the Modal CLI and sign in with `modal setup`. In the Modal dashboard,
create a Secret named **bloodline-api** containing only:

- `JWT_SECRET`: a generated private random signing secret, retained across deploys.
- `NEXCONN_APP_KEY`: the existing Nexconn project app key, also used by the APK.
- `NEXCONN_APP_SECRET`: that project's private server secret.

Set the workspace's **spend limit to $0** under Usage & Billing before deploying.
Modal's Starter plan includes monthly compute credits; it is not unlimited free
hosting. With this spend limit, the demo can stop when applicable credits run out.
See [Modal pricing](https://modal.com/pricing) and [budget controls](https://modal.com/docs/guide/budgets).

From the repository root, with Go and Modal on PATH:

```sh
scripts/deploy-modal.sh
```

The script builds a stripped Linux binary under ignored `dist/modal/` and uploads
that executable and the deployment module into a small Python image. It never
opens `.env` or uploads SQLite files, Android signing material or runtime logs.
The deployment fixes DEV/FAKE/MOCK at `0`, uses live Singapore Nexconn and seeds
fictional accounts and stock only on an empty database.

The API uses a single container, a persistent v2 Modal Volume named
`bloodline-data`, and up to 32 concurrent HTTP requests. SQLite still serializes
its database connection. A 15-minute idle window keeps the API awake while users
fill forms, after which it scales to zero. Modal
periodically commits the volume and commits it on normal shutdown. This is demo
storage, not a replicated database or a guarantee against abrupt-crash data loss.

**Always deploy with the script's `--strategy=recreate` setting.** It prevents
old and new versions from writing the same SQLite file concurrently. Redeploys
can briefly interrupt requests. Do not start a second deployment against this
volume. Stopping the app retains its volume; deleting the volume deletes its data.

The command prints the public HTTPS URL. Verify `/health`, `/config` and a 404
for `/dev/reset`, then build the APK with the same Nexconn app key:

```sh
scripts/build-android-release.sh https://YOUR-WORKSPACE--bloodline-api.modal.run
```

Set `NEXCONN_APP_KEY` when invoking the build script if using a different project
from the default. The final signed APK must be built with the actual assigned URL,
not a guessed hostname. On a phone over mobile data, verify registration, profile
save, requester broadcast, donor acceptance, chat and fulfillment before release.
Also verify that saved data survives a container restart.

Publish the verified APK and checksum:

```sh
gh release create v1.0.0 dist/bloodline.apk dist/SHA256SUMS \
  --title 'BloodLine 1.0.0 — public Android demo' \
  --notes-file deploy/RELEASE_NOTES.md
```

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
