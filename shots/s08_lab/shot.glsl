// s08_lab — Soviet biology lab. Row of glass specimen tanks, sickly green light.
// Camera tracks laterally along the tanks (room runs along Z, tanks against +X wall).
// t=100..113 shot-local 0..13. Custom material ids on top of shared M_*:
#define MI_FLOOR    20.0
#define MI_CEIL     21.0
#define MI_WALLL    22.0
#define MI_WALLR    23.0
#define MI_BENCH    24.0
#define MI_GLASS    25.0
#define MI_TERM     26.0
#define MI_PAPER    27.0
#define MI_CLOCK    28.0
#define MI_PIPE     29.0
#define MI_HAND     30.0
#define MI_SHARD    31.0

const float ROOM_CEIL = 2.65;
const float TANK_X = 1.30;      // tank row against the right wall
const float BENCH_X = -1.35;    // benches / terminal against the left wall
const int   NTANK = 4;
const float LAST_T0 = 7.0, LAST_CRACK1 = 10.0, BURST_T = 10.2, CUT_T = 11.2;

float tankZ(int i){ return 2.4 + float(i) * 3.0; }   // 2.4, 5.4, 8.4, 11.4

// ---- cheap deterministic layout helpers ----
float camZ_(float t){
  float k = clamp(t / 6.0, 0., 1.);
  k = smoothstep(0., 1., k);
  return mix(0.4, 10.6, k);            // arrive near tank 3 (z=11.4) by t=6
}
float camPush_(float t){ return clamp((t - 6.0) / 4.6, 0., 1.); }

// last tank "hand press" origin, in local tank space (feet-based frame)
vec3 handLocal(){ return vec3(-0.30, 1.42, 0.02); }

// crack pattern on a 2D unrolled cylinder uv (arc-length x, height y)
float crackLines(vec2 uv, vec2 origin, float growth, float seedk){
  vec2 p = (uv - origin) * 16.0;
  float d = 1e5;
  for (int i = 0; i < 6; i++){
    float fi = float(i);
    float ang = hash11(seedk + fi) * TAU;
    vec2 dir = vec2(cos(ang), sin(ang) * 1.6);
    float len = 3.0 + hash11(seedk + fi + 12.3) * 5.0;
    vec2 a = vec2(0.), b = dir * len;
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    // jitter the segment so it doesn't look like a perfect star
    float jag = sin(h * 18.0 + fi * 4.1) * 0.35 * h;
    vec2 seg = a + ba * h + vec2(-dir.y, dir.x) * jag;
    d = min(d, length(p - seg));
    // a couple of side-branches
    if (h > 0.35 && h < 0.75){
      float bang = ang + (hash11(fi + 30.0) - 0.5) * 2.2;
      vec2 bd = vec2(cos(bang), sin(bang) * 1.6) * len * 0.4;
      vec2 pb = p - seg;
      float hb = clamp(dot(pb, bd) / dot(bd, bd), 0., 1.);
      d = min(d, length(pb - bd * hb));
    }
  }
  float lineMask = smoothstep(0.85, 0.0, d);
  float distO = length(uv - origin);
  float grown = smoothstep(growth + 0.35, growth - 0.35, distO * 3.0);
  return lineMask * grown;
}

// ------------------------------------------------------------------- map ---
vec2 map(vec3 p){
  vec2 r = vec2(1e5, 0.0);
  float t = iTime;

  r = opU(r, vec2(p.y, MI_FLOOR));
  r = opU(r, vec2(ROOM_CEIL - p.y, MI_CEIL));
  r = opU(r, vec2(p.x - (-1.75), MI_WALLL));
  r = opU(r, vec2(3.4 - p.x, MI_WALLR));
  r = opU(r, vec2(p.z - (-0.6), M_CONCRETE));
  r = opU(r, vec2(14.4 - p.z, M_CONCRETE));

  // ceiling pipes running the length of the room
  for (int i = 0; i < 2; i++){
    float px = -0.5 + float(i) * 1.0;
    r = opU(r, vec2(sdCylZ(p - vec3(px, ROOM_CEIL - 0.12, 7.0), 0.045, 8.0), MI_PIPE));
  }

  // ---- bench run + terminal + clipboard on the left wall ----
  {
    vec3 bc = vec3(BENCH_X, 0.44, 7.0);
    vec2 bench = vec2(sdRoundBox(p - bc, vec3(0.28, 0.44, 7.5), 0.015), MI_BENCH);
    r = opU(r, bench);
    // terminal housing near the start of the track
    vec3 tc = vec3(BENCH_X + 0.05, 1.02, 1.6);
    vec2 term = vec2(sdRoundBox(p - tc, vec3(0.22, 0.24, 0.18), 0.02), MI_TERM);
    r = opU(r, term);
    // clipboard flat on the bench
    vec3 cc = vec3(BENCH_X + 0.02, 0.90, 4.2);
    vec3 cq = p - cc; cq.xz *= rot2(0.25);
    r = opU(r, vec2(sdRoundBox(cq, vec3(0.16, 0.01, 0.22), 0.005), MI_PAPER));
    // stopped wall clock
    vec3 kc = vec3(BENCH_X + 0.02, 2.05, 6.0);
    float clock = sdCylX(p - kc, 0.16, 0.02);
    r = opU(r, vec2(clock, MI_CLOCK));
  }

  // ---- specimen tanks ----
  for (int i = 0; i < NTANK; i++){
    bool last = (i == NTANK - 1);
    float tz = tankZ(i);
    vec3 c = vec3(TANK_X, 0.0, tz);
    float seed = 0.15 + float(i) * 0.33;

    bool burst = last && t >= BURST_T;
    if (!burst){
      // tank glass is NOT solid geometry (see through it): rendered as an analytic
      // rim/tint pass in render() so the suspended figure stays visible inside.
      // a thin liquid floor disc anchors the tank visually.
      vec3 lp = p - c;
      float floorDisc = max(sdCylY(lp - vec3(0., 0.10, 0.), 0.40, 0.02), lp.y - 0.30);
      r = opU(r, vec2(floorDisc, MI_GLASS));

      // suspended monster inside, feet near tank floor, facing the corridor (-X, toward camera)
      vec3 feet = c + vec3(0., 0.14, 0.);
      vec3 mp = p - feet;
      mp.y -= sin(t * 0.35 + seed * 7.0) * 0.05 + 0.02;   // slow drift
      mp.xz *= rot2(PI * 0.5 + sin(t * 0.22 + seed * 4.0) * 0.25 + seed * 2.0);
      float bnd = sdCapsule(mp, vec3(0., .2, 0.), vec3(0., 1.85, 0.), .34);
      if (bnd < 0.22){
        vec2 mo = sdMonster(mp, t * 0.6, seed, 0.0);
        r = opU(r, mo);
      }

      if (last && t >= LAST_T0){
        // pressed hand on the inner glass
        float fade = smoothstep(LAST_T0 + 1.3, LAST_T0 + 1.9, t) * (1.0 - step(BURST_T, t));
        if (fade > 0.001){
          vec3 hc = c + vec3(0., 0., 0.) + vec3(cos(PI) * 0.0, 0., 0.); // origin marker (unused geo offset)
          vec3 hl = handLocal();
          vec3 hpLocal = vec3(-0.335, hl.y, hl.z);
          vec3 hq = p - (c + hpLocal);
          float palm = sdRoundBox(hq, vec3(0.015, 0.055, 0.05), 0.01);
          float hd = palm;
          for (int f = 0; f < 4; f++){
            float ff = float(f) - 1.5;
            vec3 tip = hq - vec3(0.02, 0.06 + ff * 0.028, -0.02);
            hd = min(hd, sdCapsule(hq, vec3(0., 0.04 + ff * 0.028, 0.0), vec3(0.02, 0.075 + ff * 0.03, -0.03), 0.009));
          }
          hd -= fade * 0.001;
          r = opU(r, vec2(hd, MI_HAND));
        }
      }
    } else {
      // ---- burst: shards + green wave + lunge ----
      float bt = t - BURST_T;
      vec3 feet = c + vec3(0., 0.14, 0.);
      vec3 lungeC = feet + vec3(-min(bt, 1.4) * 2.1, -min(bt,1.0)*0.15, 0.0);
      vec3 mp = p - lungeC;
      float bnd = sdCapsule(mp, vec3(0., .2, 0.), vec3(0., 1.85, 0.), .5);
      if (bnd < 0.3) r = opU(r, sdMonster(mp, t, seed, 1.0));

      // shards: small thin boxes flying outward
      for (int s = 0; s < 10; s++){
        float fs = float(s);
        vec3 dir = normalize(hash33(vec3(fs, seed * 9.0, 3.1)) - 0.5 + vec3(-0.3,0.1,0.));
        float dist = min(bt * 3.0, 2.2) * (0.6 + 0.5 * hash11(fs + 5.0));
        vec3 sc = c + vec3(0., 1.0 + dir.y * 0.5, 0.) + dir * dist;
        vec3 sq = p - sc;
        sq.xy *= rot2(bt * (2.0 + hash11(fs)) );
        r = opU(r, vec2(sdRoundBox(sq, vec3(0.05, 0.07, 0.004), 0.002), MI_SHARD));
      }
    }
  }

  return r;
}

vec3 nrm(vec3 p){
  vec2 e = vec2(0.0012, 0.);
  return normalize(vec3(
    map(p + e.xyy).x - map(p - e.xyy).x,
    map(p + e.yxy).x - map(p - e.yxy).x,
    map(p + e.yyx).x - map(p - e.yyx).x));
}

float shadow(vec3 ro, vec3 rd, float maxT){
  float res = 1.0, tt = 0.03;
  for (int i = 0; i < 14; i++){
    float h = map(ro + rd * tt).x;
    res = min(res, 8.0 * h / tt);
    tt += clamp(h, 0.02, 0.25);
    if (res < 0.04 || tt > maxT) break;
  }
  return clamp(res, 0.0, 1.0);
}

// flashlight: held slightly off the eye-line (parallax gives real shading depth), swings
// around the camera's own forward.
vec3 flashPos(vec3 ro, vec3 camR, vec3 camU){ return ro + camR * 0.22 - camU * 0.16; }
vec3 flashDir(vec3 fwd, vec3 right, vec3 up, float t){
  float sw = sin(t * 0.7) * 0.30;
  return normalize(fwd + right * sw + up * (sw * 0.25));
}

vec3 floorAlb(vec3 p){
  float n = fbm3lo(p * 4.0);
  vec3 base = mix(vec3(.06,.065,.06), vec3(.11,.115,.10), n);
  float wet = smoothstep(.5,.7, fbm3lo(p*8.+vec3(0,4,0)));
  base = mix(base, vec3(.05,.09,.07), wet*0.4);
  return base;
}
vec3 wallAlb(vec3 p, bool right){
  float n = fbm3lo(p*3.2);
  vec3 base = mix(vec3(.20,.24,.21), vec3(.10,.13,.11), n);   // green-grey steel
  base *= 0.8 + 0.4*fbm3lo(p*10.);
  return base;
}
vec3 benchAlb(vec3 p){
  vec3 base = vec3(.22,.23,.22) * (0.7 + 0.4*fbm3lo(p*9.));
  return base;
}

vec3 shade(vec2 h, vec3 p, vec3 n, vec3 rd, vec3 fp, vec3 fd){
  float m = h.y;
  vec3 albedo = vec3(.4);
  float rough = 0.6; bool emissive = false; vec3 emitCol = vec3(0.);

  if (m == MI_FLOOR) albedo = floorAlb(p);
  else if (m == MI_CEIL) albedo = vec3(.05,.06,.055) * (0.6+0.4*fbm3lo(p*3.));
  else if (m == MI_WALLL || m == MI_WALLR) albedo = wallAlb(p, m == MI_WALLR);
  else if (m == M_CONCRETE) albedo = vec3(.09,.10,.095) * (0.7+0.5*fbm3lo(p*4.));
  else if (m == MI_BENCH) albedo = benchAlb(p);
  else if (m == MI_PIPE) { albedo = vec3(.12,.13,.12); rough = 0.35; }
  else if (m == MI_PAPER) {
    vec2 uv = p.xz * 3.0 + 0.5;
    vec4 tex = texture(iTex1, fract(uv));
    albedo = mix(vec3(.75,.72,.62), tex.rgb, tex.a);
    rough = 0.85;
  }
  else if (m == MI_CLOCK) {
    vec2 uv = vec2(p.y - 1.89, p.z - 6.0) * 3.0 + 0.5;
    vec4 tex = texture(iTex2, fract(uv));
    albedo = mix(vec3(.05), tex.rgb, tex.a);
    rough = 0.4;
  }
  else if (m == MI_TERM) {
    vec3 lp = p - vec3(BENCH_X + 0.05, 1.02, 1.6);
    if (lp.x > 0.19){
      vec2 uv = vec2(0.5 - lp.z/0.36, 0.5 - lp.y/0.48);
      vec3 tex = texture(iTex0, uv).rgb;
      albedo = vec3(.02); emitCol = tex * vec3(.3,1.4,.35) * 1.6; emissive = true;
    } else { albedo = vec3(.12,.13,.12); rough = 0.5; }
  }
  else if (m == MI_HAND) { albedo = vec3(.5,.48,.4); rough = 0.45; }
  else if (m == MI_SHARD) { albedo = vec3(.55,.7,.6); rough = 0.08; }
  else if (m <= 10.0) albedo = monsterAlbedo(m, p) * 0.55;   // dim: read as a dark shape behind glass
  else if (m == MI_GLASS) { albedo = vec3(.03,.05,.045); rough = 0.15; }
  else albedo = vec3(.3);

  if (emissive) return emitCol;

  vec3 col = vec3(0.0);

  // flashlight — the dominant light source, s06-style: angular cone x inverse-square atten
  float cone = spotLight(p, fp, fd, 0.80, 0.95);
  float cookie = flashCookie(p, fp, fd);
  vec3 Lf = normalize(fp - p);
  float ldf = length(fp - p);
  float ndlf = max(dot(n, Lf), 0.0);
  float atten = 1.0 / (1.0 + ldf*ldf*0.75);
  float shf = shadow(p + n*0.006, Lf, ldf);
  col += albedo * ndlf * cone * cookie * atten * shf * vec3(1.0, .97, .85) * 2.4;

  vec3 h2 = normalize(Lf - rd);
  float spec = pow(max(dot(n, h2), 0.0), mix(70.0,14.0,rough)) * (1.0-rough) * cone * atten;
  col += spec * vec3(1.0,.95,.85) * shf * 0.5;

  // sickly green glow from the nearest tank only (localized, not room-filling)
  float bestLd = 1e5; vec3 bestDir = vec3(0.);
  for (int i = 0; i < NTANK; i++){
    vec3 lp = vec3(TANK_X - 0.1, 1.2, tankZ(i));
    float ld = length(lp - p);
    if (ld < bestLd){ bestLd = ld; bestDir = (lp - p) / max(ld,1e-4); }
  }
  float ndlg = max(dot(n, bestDir), 0.0);
  float gatten = 1.0 / (1.0 + bestLd*bestLd*2.4);
  col += albedo * ndlg * gatten * vec3(.18, .95, .32) * 1.3;

  // dim cold ambient fill so shadows aren't pure black
  col += albedo * vec3(.012, .018, .02);

  if (m == MI_SHARD){
    float rim = pow(1.0 - abs(dot(n, rd)), 3.0);
    col += rim * vec3(.4, .9, .5) * 0.6;
  }

  return col;
}

// Analytic "glass" pass for one tank: the ray isn't blocked by real geometry (see map()),
// so we fake the cylinder wall by intersecting an infinite vertical cylinder analytically
// and adding a fresnel rim + absorption tint for the segment of the ray that's inside it.
// This is what lets the suspended figure stay visible while the tank still reads as glass.
vec3 tankGlassPass(vec3 ro, vec3 rd, float d, vec3 center, float R, float y0, float y1, vec3 tint){
  vec2 oc = ro.xz - center.xz;
  vec2 rdxz = rd.xz;
  float b = dot(oc, rdxz), c2 = dot(oc, oc) - R * R, a = dot(rdxz, rdxz);
  if (a < 1e-6) return vec3(0.);
  float disc = b * b - a * c2;
  if (disc < 0.0) return vec3(0.);
  float sq = sqrt(disc);
  float t0 = (-b - sq) / a, t1 = (-b + sq) / a;
  t0 = max(t0, 0.0); t1 = min(t1, d);
  if (t1 <= t0) return vec3(0.);
  float y0w = ro.y + rd.y * t0, y1w = ro.y + rd.y * t1;
  if (max(y0w, y1w) < y0 || min(y0w, y1w) > y1) return vec3(0.);

  vec3 add = vec3(0.);
  // rim highlights at both crossings (entry/exit) — grazing angle glints
  for (int k = 0; k < 2; k++){
    float tk = k == 0 ? t0 : t1;
    vec3 pk = ro + rd * tk;
    if (pk.y < y0 || pk.y > y1) continue;
    vec3 nrm2 = normalize(vec3(pk.x - center.x, 0., pk.z - center.z));
    float fres = pow(1.0 - abs(dot(nrm2, -rd)), 4.0);
    add += tint * fres * 0.85;
  }
  // absorption tint through the liquid for the segment inside the tank
  float pathLen = clamp(t1 - t0, 0.0, R * 2.2);
  float tintAmt = 1.0 - exp(-pathLen * 1.1);
  add += tint * tintAmt * 0.12;
  return add;
}

vec3 render(vec2 fc){
  float t = iTime;
  float cz = camZ_(t), push = camPush_(t);

  vec3 ro, ta; float focal;
  if (t < 6.0){
    ro = vec3(-1.25, 1.5, cz);
    ta = vec3(TANK_X, 1.25, cz + 2.1);
    focal = 1.85;
  } else {
    // settle & push in on the last tank, 3/4 angle so the cylinder curvature reads
    vec3 lastC = vec3(TANK_X, 1.3, tankZ(NTANK-1));
    ro = mix(vec3(-1.25, 1.5, cz), lastC + vec3(-2.3, 0.0, -1.5), push);
    ta = mix(vec3(TANK_X, 1.25, cz + 2.1), lastC + vec3(0.1,0.05,0.), push);
    focal = mix(1.85, 2.2, push);
  }

  vec3 camF = normalize(ta - ro);
  vec3 camR = normalize(cross(camF, vec3(0.,1.,0.)));
  vec3 camU = cross(camR, camF);
  vec3 fd = flashDir(camF, camR, camU, t);
  vec3 fp = flashPos(ro, camR, camU);

  vec3 rd = camRay(fc, ro, ta, focal, 0.0);

  float d = 0.0; vec2 h; bool hitAny = false;
  for (int i = 0; i < 130; i++){
    vec3 p = ro + rd * d;
    h = map(p);
    float th = 0.0015 * max(d, 1.0);
    if (h.x < th){ hitAny = true; break; }
    d += h.x * 0.82;
    if (d > 16.0) break;
  }

  vec3 col;
  float hitD = hitAny ? d : 16.0;
  if (!hitAny){
    col = vec3(.0025,.0035,.003);
  } else {
    vec3 p = ro + rd * d;
    vec3 n = nrm(p);
    col = shade(h, p, n, rd, fp, fd);

    // eyes opening in the last tank
    if (t >= 7.5 && t < BURST_T){
      vec3 c = vec3(TANK_X, 0.0, tankZ(NTANK-1)) + vec3(0., 0.14, 0.);
      float eyesOn = smoothstep(7.5, 8.3, t);
      for (int e = 0; e < 2; e++){
        float sg = e == 0 ? -1. : 1.;
        vec3 ep = c + vec3(-0.045*sg, 1.76, 0.30);
        float ed = length(p - ep);
        col += vec3(.6,1.0,.4) * eyesOn * smoothstep(0.05, 0.0, ed) * 3.0;
      }
    }

    float fog = 1.0 - exp(-d*d*0.006);
    fog = min(fog, 0.4);
    col = mix(col, vec3(.004,.006,.005), fog);
  }

  // analytic glass cylinders for the idle tanks (see-through, faked)
  for (int i = 0; i < NTANK; i++){
    bool lastTank = (i == NTANK - 1);
    if (lastTank && t >= BURST_T) continue;
    vec3 c = vec3(TANK_X, 0.0, tankZ(i));
    vec3 tint = vec3(.15, .9, .35);
    col += tankGlassPass(ro, rd, hitD, c, 0.42, 0.14, 2.02, tint);

    // crack overlay on the last tank, near burst
    if (lastTank && t >= LAST_T0 && t < BURST_T){
      vec2 oc = ro.xz - c.xz;
      float b = dot(oc, rd.xz), a = dot(rd.xz, rd.xz), c2 = dot(oc,oc) - 0.42*0.42;
      float disc = b*b - a*c2;
      if (disc > 0.0 && a > 1e-6){
        float te = (-b - sqrt(disc)) / a;
        if (te > 0.0 && te < hitD){
          vec3 pe = ro + rd * te;
          vec3 lp = pe - c;
          float ang = atan(lp.z, lp.x);
          vec2 uv = vec2(ang * 0.42, lp.y);
          vec2 origin = vec2(PI * 0.42, handLocal().y);
          float growth = smoothstep(LAST_T0 + 0.3, LAST_CRACK1, t) * 1.4;
          float crack = crackLines(uv, origin, growth, 7.0);
          col += crack * vec3(0.75, 1.0, 0.8) * 2.2;
        }
      }
    }
  }

  // cheap volumetric shaft from the flashlight
  float dither = fract(sin(dot(fc, vec2(12.9898,78.233)))*43758.5453);
  vec3 vol = vec3(0.);
  const int VS = 8;
  for (int i = 0; i < VS; i++){
    float ft = (float(i)+dither)/float(VS);
    float sd = ft * min(hitD, 6.0);
    vec3 sp = ro + rd*sd;
    float c = dot(normalize(sp-fp), fd);
    vol += smoothstep(0.94,0.998,c) / (1.0 + sd*sd*0.08);
  }
  col += vol * vec3(1.0,.95,.8) * 0.012;

  // burst: flash + green wash on the last tank event, brief and hard
  if (t >= BURST_T && t < BURST_T + 0.22){
    float k = 1.0 - smoothstep(BURST_T, BURST_T+0.22, t);
    col += vec3(.5,1.0,.6) * k * k * 1.0;
  }

  return col;
}
