# How to build a shot

Everything is rendered by GLSL fragment shaders in headless Chromium (SwiftShader, CPU) plus a
Canvas2D overlay, piped to ffmpeg. There is no GPU. Every pixel costs CPU time, so be deliberate.

## Files

- `shots/<name>/shot.glsl` — must define `vec3 render(vec2 fc)` returning **linear HDR** color for
  pixel `fc` (gl_FragCoord.xy). Tonemapping (ACES), gamma, bloom, grain etc. happen in post. Values
  above 1.0 bloom. Pixels inside the letterbox bars are skipped automatically.
- `shots/<name>/shot.js` — ES module, `export default { ... }` with:
  - `duration` (seconds, required), `fps` (default 24)
  - `sceneScale` (optional, e.g. `0.75`: scene is raymarched at 75% res and upscaled; post & overlay stay full res)
  - `params(t)` → array of up to 16 floats, available in GLSL as `uP[0..15]`. Use this for event
    timing you want to control from JS (cuts, flashes, positions), or ignore it and use `iTime`.
  - `post(t)` → object overriding post-process defaults (all optional):
    `grain .06, aberr .0015, vignette .9, flash 0, flashColor [1,.85,.6], shake 0, exposure 1, fade 0 (1 = black),
    bloom .35, bar .12 (letterbox), scan 0 (CRT scanlines), sat 1, contrast 1.05, temp 0 (+warm/-cold), lift [0,0,0]`
  - `overlay(ctx, t, W, H)` → draw text/UI with Canvas2D after post (W=1280, H=720 at full res; scale
    everything by `W/1280` so previews at `--scale 0.5` look right).
  - `textures: [{w, h, draw(ctx, w, h)}]` → up to 4 canvases drawn once at init and bound as
    `iTex0..iTex3` (mipmapped, REPEAT, y already flipped so `texture(iTex0, uv)` with uv.y up reads
    the canvas upright). Use these for in-world signage, stencils, posters, documents.
- `shots/<name>/cues.json` — sound cues for the audio build, see below.

Fonts available in overlays and textures (Cyrillic supported): `"Special Elite"` (typewriter),
`"Oswald"` (condensed titles), `"Russo One"` (Soviet display), `"Rubik Mono One"` (heavy stencil-ish),
`"PT Mono"`, `"IBM Plex Mono"`, `"Share Tech Mono"` (terminal/CRT).

## Shared library `shaders/common.glsl` (prepended automatically; do not edit it)

Hashes/noise (`hash11 hash21 hash31 hash22 hash33 noise2 noise3 fbm2 fbm3 fbm3lo`), SDF primitives
(`sdBox sdRoundBox sdSphere sdCapsule sdTaper sdCylX/Y/Z sdTorus sdEllipsoid smin smax opU`),
`rot2 rotX rotY rotZ`, camera `camRay(fc, ro, ta, focal, roll)`, `spotLight`, `flashCookie`,
`hgPhase`, `bloodSplat(vec2 p, float seed)`, `stars(dir)`, `aurora(dir, t)`, material ids `M_*`.

Characters/props shared across shots (use these so the film is consistent):
- `vec2 sdMonster(vec3 p, float t, float seed, float run)` — the former staff. Feet at y=0, facing +Z,
  ~2 m tall. `run` 0 = twitching idle, 1 = sprinting lunge. Returns (dist, material). **Always bound
  it** first: `float b = sdCapsule(p, vec3(0,.2,0), vec3(0,2.,0), 1.0); if (b > .2) d = b; else d = sdMonster(...)`.
  Shade with `monsterAlbedo(mat, p)` and `monsterSpec(mat)`. It is being improved in parallel by
  the lead; the signature won't change.
- `vec2 sdKS23(vec3 p, float pump)` — the KS-23, barrel along +Z, meters. `gunAlbedo(mat, p)`.

If you need your own helpers, put them in your shot.glsl.

## Commands

    node render/render.mjs <shot> --stills 1,4.5,9 --scale 0.5    # quick look, writes build/stills/<shot>_<t>.png
    node render/render.mjs <shot> --stills 4.5                     # full-res still
    node render/render.mjs <shot> --from 3 --to 4                  # 1 s of full-res video, prints s/frame
    node render/render.mjs <shot> --scale 0.5 --fps 8              # cheap motion preview (build/shots/<shot>_preview.mp4)

Look at stills with the Read tool (it displays PNGs). Judge them honestly and iterate: composition,
readability of the silhouette, mood, whether it looks like a film frame or a programmer test.
Other agents render at the same time on a 4-core machine, so timings are noisy; renders can take a
while. Never run `playwright install`.

**Performance budget: ≤ 2.5 s/frame at full res** (measure with a 1 s `--from/--to` clip). Tools:
bound expensive SDFs, cap raymarch steps (~100-160), step multipliers, fewer fbm octaves, `sceneScale: .75`,
cheap fake volumetrics (analytic fog, few-sample light shafts with dithered start offsets), fewer
lights. Do NOT render the full shot to video; the lead does final renders.

## Style bar

See `docs/SHOTLIST.md` for story and palette. This is a horror short, not a tech demo:
darkness, fog/volumetric light, strong silhouettes and backlight, motivated light sources
(flashlights, sodium lamps, red emergency lamps, muzzle flash), camera movement with intent
(slow push-ins, handheld shake via `post.shake` or camera noise), grain. Avoid flat grey "SDF demo"
looks: every surface should have grime, frost, noise-based variation; use AO and soft shadows where
it matters. Silhouettes should read in one glance.

## Sound cues (`shots/<name>/cues.json`)

Times are shot-local seconds. Format:

    { "ambience": "blizzard" | "interior_hum" | "interior_dead" | "hangar" | "none",
      "cues": [ { "t": 3.2, "type": "door_slam", "gain": 1.0 }, ... ] }

Allowed types: `typewriter_key, radio_static, radio_signal, morse, engine_idle, engine_rev, wind_gust,
door_grind, door_slam, bolt_lock, power_down, power_up, light_flicker, fluorescent_buzz, footsteps,
heartbeat, breath, stinger, drone_swell, shriek, growl, gore_hit, body_fall, ks23_shot, pump_rack,
ak_burst, ppsh_burst, makarov_shot, flare_shot, grenade_pin, explosion, glass_break, metal_clang,
tank_burst, liquid_splash, impact, whoosh, music_hit`. Optional `"dur"` (seconds) for sustained ones.
Sync cues exactly to visual events (muzzle flash frame = shot cue).

Do not edit files outside your own `shots/<name>/` directories. Do not commit.
