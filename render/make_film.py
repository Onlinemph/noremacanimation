#!/usr/bin/env python3
"""Render every shot in timeline.json (skipping up-to-date ones), build the audio, and mux the final film.

    python3 render/make_film.py            # render what's stale, then assemble build/OBJECT9.mp4
    python3 render/make_film.py --force    # re-render every shot
    python3 render/make_film.py --only s05_corridor,s07_fight
    python3 render/make_film.py --shared   # also treat shared shader/engine edits as making every shot stale
"""
import json, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FFMPEG = os.environ.get('FFMPEG') or __import__('imageio_ffmpeg').get_ffmpeg_exe()
os.chdir(ROOT)

tl = json.load(open('timeline.json'))
force = '--force' in sys.argv
only = None
if '--only' in sys.argv:
    only = set(sys.argv[sys.argv.index('--only') + 1].split(','))

shared = ['shaders/common.glsl', 'shaders/post.glsl', 'render/engine.js', 'render/render.mjs']

def mtime(p):
    return os.path.getmtime(p) if os.path.exists(p) else 0

for shot in tl['shots']:
    name = shot['name']
    out = f'build/shots/{name}.mp4'
    srcs = [f'shots/{name}/shot.glsl', f'shots/{name}/shot.js'] + (shared if '--shared' in sys.argv else [])
    stale = force or mtime(out) < max(mtime(s) for s in srcs)
    if only is not None:
        stale = name in only
    if not stale:
        print(f'{name}: up to date')
        continue
    t0 = time.time()
    subprocess.run(['node', 'render/render.mjs', name], check=True)
    print(f'{name}: rendered in {(time.time() - t0) / 60:.1f} min')

# audio
subprocess.run([sys.executable, 'audio/build_audio.py'], check=True)

# concat video (re-encode for exact frame-accurate cuts)
with open('build/concat.txt', 'w') as f:
    for shot in tl['shots']:
        f.write(f"file 'shots/{shot['name']}.mp4'\n")
total = sum(s['duration'] for s in tl['shots'])
subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', 'build/concat.txt',
                '-i', 'build/audio.wav', '-map', '0:v', '-map', '1:a',
                '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', str(tl['fps']),
                '-c:a', 'aac', '-b:a', '256k', '-t', str(total), '-movflags', '+faststart',
                'build/OBJECT9.mp4'], check=True)
print('-> build/OBJECT9.mp4')
