# ОБЪЕКТ 9 / OBJECT 9

A 2 minute 26 second horror short, rendered entirely from code: **[OBJECT9.mp4](OBJECT9.mp4)**.

Midwinter 1989. A team from Amundsen–Scott South Pole Station follows a Russian distress call 340 km
across the plateau to a Soviet station that is on no map. The blast door seals behind them. The staff are
still there. With a KS-23 from the armory, a conscript's AKS-74U, a crate of 1944 PPSh-41s and a flare
pistol, they fight their way to the hangar and the Kharkovchanka snow tractor, and blow the place behind them.

## How it is made

No 3D software and no downloaded footage or sound. Every frame and every sound is computed.

- **Picture.** Each shot is a GLSL fragment shader (`shots/<shot>/shot.glsl`): raymarched signed distance
  fields for the sets, vehicles, weapons and creatures, with procedural materials and lights, fog, volumetric
  beams and particles. Headless Chromium runs the shaders on its software renderer (SwiftShader, no GPU),
  `shaders/post.glsl` adds film grain, bloom, aberration and the 2.39:1 letterbox, and a Canvas2D overlay
  (`shot.js`) draws titles, documents and the weapon plates. `render/render.mjs` pipes frames to ffmpeg.
- **Shared models** live in `shaders/common.glsl`: the former staff (`sdMonster`, IK limbs, split ribcage,
  unhinged jaw, tendrils from the lake organism) and the KS-23.
- **Sound.** `audio/build_audio.py` synthesises everything with numpy/scipy: gunshots, pump actions,
  shrieks, wind, steel doors, radio static, explosions and the score. It places each sound from the
  per-shot `cues.json` files, which are timed to the picture.

See `docs/SHOTLIST.md` for the story and shot list.

## Rebuild

    pip install numpy scipy pillow imageio-ffmpeg
    node render/render.mjs s05_corridor --stills 10.8      # look at one frame
    python3 render/make_film.py                            # render stale shots, build audio, mux build/OBJECT9.mp4

Needs Node with Playwright's Chromium. A full render takes about 2 hours on 4 CPU cores. The fight
(`s07_fight`) is the heaviest shot at about 8 s per frame.
