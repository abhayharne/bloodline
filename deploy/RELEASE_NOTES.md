# BloodLine 1.0.0 — public Android demo

Coordinate a blood request with nearby donors and blood banks in one live chat room.

## Install

1. Download `bloodline.apk` from this release on an Android 7.0+ device.
2. Allow your browser to install the downloaded app when Android prompts you.
3. Open BloodLine and wait for the demo service to connect, then choose a role.
4. Use fictional profile details and the demo code **123456**. No SMS is sent.

If an older debug build is installed, uninstall it before installing this signed
release. Uninstalling removes its saved local session and preferences.

Verify the download using `SHA256SUMS` attached to this release.

## Demo availability

The API runs on Modal and live conversations use Nexconn. The first connection
after inactivity can take up to 90 seconds. The demo may pause when its included
compute credits are exhausted.

SQLite data is stored on a persistent volume, but this shared demo may be reset.
Register again if your account no longer exists. Use fictional information; this
build does not send SMS or verify donor identities and is not a service for real
emergency coordination. Sample hospitals are included for demonstration.

## Try the flow

Create requester and donor profiles near the same sample hospital with matching
blood groups. Broadcast a request, accept it as the donor, exchange messages in
the shared room, then fulfill the request as its requester.
