"""Pick the settled chat hero and replace frame zero, preserving timing."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parent
VIDEO = ROOT / 'brag.mp4'
POSTER = ROOT / 'brag.jpg'
TEMP = ROOT / 'brag.poster.mp4'

def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)
    ]))

def run(*args):
    subprocess.run(args, check=True)

before = probe(VIDEO)
run('ffmpeg', '-y', '-loglevel', 'error', '-ss', '13.7', '-i', str(VIDEO),
    '-frames:v', '1', '-q:v', '2', str(POSTER))
run('ffmpeg', '-y', '-loglevel', 'error', '-i', str(VIDEO), '-i', str(POSTER),
    '-filter_complex', "[0:v][1:v]overlay=0:0:enable='eq(n,0)'[v]",
    '-map', '[v]', '-map', '0:a?', '-c:v', 'libx264', '-crf', '18',
    '-preset', 'medium', '-pix_fmt', 'yuv420p', '-c:a', 'copy',
    '-movflags', '+faststart', '-metadata', 'title=BloodLine — One request. One room.', str(TEMP))
after = probe(TEMP)
bv = next(s for s in before['streams'] if s['codec_type'] == 'video')
av = next(s for s in after['streams'] if s['codec_type'] == 'video')
assert (av['width'], av['height']) == (1920, 1080)
assert av['nb_frames'] == bv['nb_frames'] == '660'
assert abs(float(after['format']['duration']) - float(before['format']['duration'])) < 0.04
assert any(s['codec_type'] == 'audio' for s in after['streams'])
TEMP.replace(VIDEO)
print(json.dumps({'video': str(VIDEO), 'poster': str(POSTER), 'frames': av['nb_frames'],
                  'duration': after['format']['duration'], 'width': av['width'], 'height': av['height']}, indent=2))
