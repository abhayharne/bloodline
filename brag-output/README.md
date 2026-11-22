# BloodLine launch film

22 seconds · 1920×1080 · 30 fps · MP4 with music and UI sound effects.

- `brag.mp4`: shareable video with the product hero poster as frame zero.
- `brag.jpg`: thumbnail selected from the settled chat scene at 13.7s.
- `share-copy.txt`: caption with required music attribution.
- `composition/`: editable Hyperframes source; four scenes, local audio assets.
- `brag-plan.md`, `composition-brief.md`: creative direction and factual grounding.
- `CREDITS.txt`: credits and fictional demo-data note.

The screens are source-grounded, video-sized recreations. This is a launch film rather than a screen recording. All hospital, message and match-count examples are fictional. App and API code are unchanged.

## Edit and render

Local Studio: http://localhost:3017/#project/composition

From `composition/`, use the installed Hyperframes launcher (adjust the path for another installation):

```sh
HYPERFRAMES_CACHE_DIR=/tmp/bloodline-hyperframes-cache node /home/_abhay_/.agents/skills/hyperframes/scripts/plugin-cli.mjs --cli-version 0.9.81 check --json
HYPERFRAMES_CACHE_DIR=/tmp/bloodline-hyperframes-cache node /home/_abhay_/.agents/skills/hyperframes/scripts/plugin-cli.mjs --cli-version 0.9.81 render --quality delivery --workers 1 --output ../brag.mp4
```

Then run `python3 finalize.py` from this folder. FFmpeg and FFprobe required. The `/tmp` cache is rebuildable.

## Verification

Hyperframes lint, runtime, layout, contrast and audio checks passed with zero errors. All 39 sampled text contrast checks passed. The intentional empty source opening frame is replaced by the poster in the delivered MP4. Seven key/end frames inspected before export; metadata and decoded delivery frames checked afterward.

Music attribution accompanies shares: Music: Sascha Ende, ende.app (CC BY 4.0).
