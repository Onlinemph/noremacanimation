// s10_end (0-15s)
//  0-7s   exterior: Object 9 burning on the horizon under aurora; the Kharkovchanka drives away into the night
//  7-13s  black, then the same green CRT from s01 (code copied verbatim), new decoded lines
//  13-15s hard cut to black, title card (drawn entirely in overlay)

// ============================================================ exterior ===
// Camera stands on the escape track looking back-left at the base (~650 m away). The tractor
// passes on the right and drives away from camera, tail lights toward us.
vec3 gRo, gF, gR, gU;
const float FOCAL = 1.9;
void setupCam(float t){
  gRo = vec3(0.0, 1.55 + .03 * sin(t * .7), 0.0);
  vec3 ta = vec3(-40. + t * 4., 22., 450.);
  gF = normalize(ta - gRo);
  gR = normalize(cross(vec3(0., 1., 0.), gF));   // screen right = world +x
  gU = cross(gF, gR);
}
vec3 camDir(vec2 uv){ return normalize(uv.x * gR + uv.y * gU + FOCAL * gF); }
vec3 project(vec3 wp){ vec3 r = wp - gRo; float z = dot(r, gF); return vec3(vec2(dot(r, gR), dot(r, gU)) / max(z, .001) * FOCAL, z); }

float fireFlicker(float t){ return .8 + .2 * noise2(vec2(t * 7., 3.)) + .1 * noise2(vec2(t * 23., 7.)); }
float fbm4(vec2 p){ float a = .5, s = 0.; for (int i = 0; i < 4; i++){ s += a * noise2(p); p = p * 2.07 + 11.3; a *= .5; } return s; }

const vec3 BASE = vec3(-150., 0., 430.);     // base origin in world
const vec3 FIREP = vec3(-135., 14., 430.);   // hangar fire (world)

// silhouette of the base in base-local meters (x right, y up). returns sdf (m), negative inside
float baseSDF(vec2 q, out float windows){
  windows = 0.;
  float d = 1e5;
  // long modules on stilts
  for (int i = 0; i < 3; i++){
    float fi = float(i);
    vec2 c = vec2(-70. + fi * 34., 7.5 + 1.5 * fi);
    d = min(d, sdBox2(q - c, vec2(14., 3.2)));
    d = min(d, sdBox2(vec2(mod(q.x - c.x + 3.5, 7.) - 3.5, q.y - 2.2), vec2(.35, 2.4)) + max(0., abs(q.x - c.x) - 13.));
    // window strip
    vec2 wq = q - c - vec2(0., .6);
    float wx = mod(wq.x + 1.5, 3.) - 1.5;
    if (abs(wq.x) < 12.5 && abs(wx) < .7 && abs(wq.y) < .8) windows = 1. + fi;
  }
  // hangar: broken arch, roof partly collapsed on the right
  vec2 h = q - vec2(15., 0.);
  float arch = max(length(vec2(h.x * .7, h.y)) - 16., -h.y);
  arch = max(arch, -(h.y - 11. + .3 * (h.x - 4.) * step(4., h.x) - 2. * noise2(vec2(h.x * .6, 1.))));  // torn roof
  d = min(d, arch);
  // bunker with dome
  d = min(d, sdBox2(q - vec2(50., 4.), vec2(10., 4.)));
  d = min(d, length(q - vec2(50., 8.)) - 6.5);
  // lattice mast with guy wires
  float mast = sdBox2(q - vec2(-20., 35.), vec2(.9 - q.y * .008, 35.));
  d = min(d, mast);
  for (int i = 0; i < 3; i++){
    float fi = float(i);
    vec2 a = vec2(-20., 20. + fi * 18.), b = vec2(-20. + (38. + fi * 10.) * (fi == 1. ? -1. : 1.), 0.);
    vec2 pa = q - a, ba = b - a;
    float hh = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    d = min(d, length(pa - ba * hh) - .12);
  }
  return d;
}

// Kharkovchanka seen from behind, local meters (x right, y up), origin at ground center
float tractorSDF(vec2 q, out float mat){
  mat = 0.;
  float tracks = min(sdBox2(q - vec2(-1.8, .72), vec2(.7, .72)), sdBox2(q - vec2(1.8, .72), vec2(.7, .72))) - .05;
  float body = sdBox2(q - vec2(0., 2.85), vec2(2.3, 1.45)) - .2;
  float roof = sdBox2(q - vec2(0., 4.6), vec2(2.05, .12));
  float rack = sdBox2(vec2(mod(q.x + .25, .5) - .25, q.y - 4.9), vec2(.04, .25));
  rack = max(rack, abs(q.x) - 1.9);
  rack = min(rack, sdBox2(q - vec2(0., 5.12), vec2(1.95, .04)));
  float stack = sdBox2(q - vec2(1.6, 5.2), vec2(.1, .55));
  float d = min(min(tracks, body), min(min(roof, rack), stack));
  // gap between the tracks under the belly stays open
  d = max(d, -sdBox2(q - vec2(0., .6), vec2(1.05, .62)));
  // rear door with a dim interior lamp, ladder beside it
  if (sdBox2(q - vec2(-.35, 3.), vec2(.5, .6)) < 0.) mat = 1.;
  if (abs(q.x - .6) < .3 && q.y > 1.4 && q.y < 4.5 && (abs(abs(q.x - .6) - .25) < .04 || abs(mod(q.y, .38) - .19) < .03)) mat = 3.;
  // track wheels (visible as lighter rings on the track ends)
  vec2 tw = vec2(abs(q.x) - 1.8, q.y - .72);
  if (abs(tw.x) < .6 && abs(mod(q.y, .22) - .11) < .025 && abs(tw.y) < .6) mat = 4.;   // track tread
  // tail lights
  if (length(q - vec2(-1.9, 1.85)) < .18 || length(q - vec2(1.9, 1.85)) < .18) mat = 2.;
  return d;
}

vec3 skyCol(vec3 rd, float t){
  vec3 c = mix(vec3(.004, .006, .012), vec3(.0015, .002, .005), smoothstep(0., .5, rd.y));
  c += stars(rd) * vec3(.8, .85, 1.) * smoothstep(.02, .15, rd.y);
  if (rd.y > -.02) c += aurora(rd, t) * .9;
  // horizon haze of blowing snow
  c += vec3(.012, .016, .026) * exp(-max(rd.y, 0.) * 18.);
  return c;
}

vec3 exteriorScene(vec2 fc, vec2 uv, float t){
  setupCam(t);
  vec3 rd = camDir(uv);
  float flick = fireFlicker(t);

  // --- tractor position: starts close on the right, drives away (+z, drifting right)
  vec3 V = vec3(5.5 - t * .35, 0., 20. + t * 6.5);
  vec3 vp = project(V);
  float vScale = FOCAL / vp.z;                 // screen units per meter at the tractor

  // --- base projection
  vec3 bp = project(BASE);
  float bScale = FOCAL / bp.z;
  vec2 bq = (uv - bp.xy) / bScale;              // base-local meters
  vec3 fp = project(FIREP);
  vec2 fq = (uv - fp.xy) / bScale;              // fire-local meters

  vec3 col;
  float horizonY = project(vec3(0., 0., 5000.)).y;

  if (rd.y < 0.){
    // ---------------- snow ground
    float tg = -gRo.y / rd.y;
    vec3 p = gRo + rd * tg;
    // sastrugi: wind-carved ridges, stretched along the wind (x)
    vec2 sp = p.xz * vec2(.35, 1.1);
    float h0 = fbm4(sp * .5);
    vec2 e = vec2(.08, 0.);
    float hx = fbm4((sp + e.xy) * .5), hz = fbm4((sp + e.yx) * .5);
    float bump = .9 * smoothstep(20., 2., tg * .05);
    vec3 n = normalize(vec3(-(hx - h0) * 6. * bump, 1., -(hz - h0) * 6. * bump));
    vec3 alb = vec3(.75, .8, .88);
    // cold ambient from the aurora sky
    col = alb * (.028 + .02 * n.y) * vec3(.5, .75, .85);
    // fire light on the snow
    vec3 Lf = FIREP - p; float df = length(Lf); Lf /= df;
    float fireI = 5000. * flick / (df * df + 8000.);
    col += alb * vec3(1., .42, .12) * fireI * max(dot(n, Lf), 0.) * (1. + .4 * smoothstep(.4, .9, h0));
    // tractor headlights throwing a pool ahead of it (away from camera)
    vec2 hrel = p.xz - V.xz;
    float along = hrel.y - 14.;
    float cone = smoothstep(along * .28 + 1.5, along * .12, abs(hrel.x - along * .2)) * smoothstep(0., 4., along) * exp(-max(along, 0.) * .06);
    col += alb * vec3(.9, .85, .7) * .07 * cone * n.y;
    // red tail-light spill on the snow right behind it
    float dt = length((p - V - vec3(0., 0., -2.5)).xz);
    col += alb * vec3(1., .05, .03) * .12 * exp(-dt * .5) * step(p.z, V.z);
    // track ruts leading to the tractor
    vec2 rel = p.xz - vec2(5.5 - (p.z - 20.) * (.35 / 6.5), p.z);  // follows the tractor's path
    float rut = (smoothstep(.5, .1, abs(abs(rel.x) - 1.75)) ) * step(p.z, V.z - 2.) * step(0., p.z);
    col *= 1. - .5 * rut;
    // glitter
    float g = hash21(floor(p.xz * 30.));
    col += step(.997, g) * fireI * .6 * vec3(1., .6, .3) * smoothstep(60., 5., tg);
    // distance haze
    float fogA = 1. - exp(-tg * .0022);
    col = mix(col, skyCol(vec3(rd.x, .001, rd.z), t) + vec3(.03, .012, .004) * flick * exp(-length(uv - fp.xy) * 5.), fogA);
  } else {
    col = skyCol(rd, t);
  }

  // ---------------- smoke plume (behind the silhouette)
  {
    float hgt = fq.y;                            // meters above the fire
    if (hgt > -5. && hgt < 520.){
      float bend = hgt * hgt * .0009 + hgt * .08; // wind shear pushes it right
      float cx = fq.x - bend;
      float w = 14. + hgt * .38;
      vec2 sp = vec2(cx, hgt - t * 9.) * (.9 / w) + vec2(0., hgt * .004);
      float warp = fbm4(sp * 1.3 + vec2(0., -t * .05));
      float dens = fbm4(sp * 1.8 + warp * 1.4);
      float body = smoothstep(1., .45, abs(cx) / w + (dens - .5) * 1.1);
      body *= smoothstep(-5., 10., hgt) * smoothstep(520., 250., hgt);
      float a = clamp(body * (.6 + dens), 0., 1.) * .97;
      float lit = exp(-max(hgt, 0.) / 28.) * flick;
      vec3 smoke = vec3(.008, .007, .007) * (.4 + dens) + vec3(.9, .28, .06) * lit * (.2 + dens * .9) + vec3(.05, .016, .004) * smoothstep(-.4, .6, -cx / w) * exp(-max(hgt, 0.) / 160.);
      col = mix(col, smoke, a);
    }
  }

  // ---------------- base silhouette with fire rim and burning windows
  float win;
  float bd = baseSDF(bq, win);
  if (bd < 0.){
    vec3 sil = vec3(.004, .003, .003);
    // rim from the fire behind
    float rim = exp(bd * 2.5) * exp(-length(bq - vec2(15., 10.)) * .035) * .5;
    sil += vec3(1., .4, .1) * rim * flick;
    if (win > 0.){
      float wf = .5 + .5 * noise2(vec2(t * 5. + win * 7., bq.x * .3));
      float burning = step(.35, hash11(floor((bq.x + 1.5) / 3.) + win * 13.));
      sil = mix(sil, vec3(2.2, .8, .2) * wf * burning + vec3(.02, .005, 0.), .9);
    }
    col = sil;
  } else {
    // glow halo just outside the silhouette edges near the fire
    col += vec3(1., .35, .08) * .03 * exp(-bd * .5) * exp(-abs(bq.x - 15.) * .04) * flick;
  }

  // ---------------- flames licking out of the torn hangar roof
  {
    vec2 q = fq;
    if (abs(q.x) < 30. && q.y > -12. && q.y < 40.){
      float n = fbm4(vec2(q.x * .12, q.y * .07 - t * 1.6));
      float shape = smoothstep(26., 4., abs(q.x) + q.y * .3) * smoothstep(38., 0., q.y + n * 20.) * smoothstep(-12., -4., q.y);
      float f = smoothstep(.35, .75, n * shape + shape * .35);
      col += mix(vec3(1.6, .35, .05), vec3(4., 2.2, .8), f * f) * f * flick * 1.4;
    }
    // bloom-ish glow around the fire
    col += vec3(1., .35, .07) * .12 * flick * exp(-length(fq * vec2(1., .7)) * .03);
  }

  // ---------------- embers rising and blowing right
  for (int i = 0; i < 10; i++){
    float fi = float(i);
    float life = fract(t * .23 + hash11(fi * 3.1));
    vec2 ep = vec2((hash11(fi) - .5) * 30. + life * life * 90., life * 180. + 5.);
    ep.x += 6. * sin(t * 2. + fi);
    vec2 d2 = (fq - ep) * bScale;
    col += vec3(2., .7, .15) * smoothstep(.0025, 0., length(d2)) * (1. - life);
  }

  // ---------------- the tractor
  {
    vec2 tq = (uv - vp.xy) / vScale;
    float m;
    float td = tractorSDF(tq, m);
    // snow churned up behind the tracks
    float spray = fbm4(vec2(tq.x * .6, tq.y * .9 + t * 4.)) * smoothstep(3.5, 0., tq.y) * smoothstep(3.2, 1.2, abs(tq.x)) ;
    col += vec3(.35, .12, .08) * spray * .08;
    if (td < 0.){
      vec3 c = vec3(.01, .009, .01);
      // fire rim on the left edge (fire is to the left, far away)
      float mm;
      float leftOut = step(0., tractorSDF(tq - vec2(.22, 0.), mm));   // edge facing the fire (left)
      float topOut = step(0., tractorSDF(tq + vec2(0., .15), mm));    // edge facing the sky
      c += vec3(1., .42, .12) * .1 * leftOut * flick;
      c += vec3(.12, .2, .25) * .06 * topOut;
      // orange paint just catching it
      c += vec3(.018, .005, .002) * smoothstep(1.4, 4.4, tq.y) * (.6 + .4 * noise2(tq * 3.));
      if (m == 3.) c += vec3(.012, .01, .009) + vec3(1., .42, .12) * .02 * flick;
      if (m == 4.) c *= .5;
      if (m == 1.){
        c = vec3(.9, .55, .22) * .22 * (.8 + .2 * noise2(vec2(t * 3., 1.)));
        vec2 hq = tq - vec2(-.3, 2.95);                                    // a survivor looking back
        float head = min(length(hq * vec2(1., .85)) - .2, sdBox2(hq + vec2(0., .5), vec2(.36, .28)) - .1);
        if (head < 0.) c = vec3(.012, .008, .006);
      }
      if (m == 2.) c = vec3(3.5, .18, .08);
      col = c;
    }
    // tail light glow + exhaust
    col += vec3(1., .04, .02) * .045 * (exp(-length(tq - vec2(-1.9, 1.9)) * 1.2) + exp(-length(tq - vec2(1.9, 1.9)) * 1.2));
    vec2 eq = tq - vec2(1.6, 5.6);
    float ex = fbm4(vec2(eq.x * .8 - t * 2., eq.y * .6 - t * 1.5)) * smoothstep(0., 1.5, eq.y) * smoothstep(3. + eq.y, 0., abs(eq.x + eq.y * .6)) * smoothstep(9., 2., eq.y);
    col = mix(col, vec3(.03, .02, .02), clamp(ex * .6, 0., .6));
  }

  // ---------------- blowing snow streaks in the foreground (screen space, three depths)
  for (int L = 0; L < 3; L++){
    float fl = float(L);
    float sc = 30. + fl * 28.;
    vec2 sp = uv * sc * vec2(.18, 1.) + vec2(t * (2.6 + fl * 1.3), t * .2 + fl * 7.);
    vec2 id = floor(sp); vec2 fr = fract(sp) - .5;
    float h = hash21(id + fl * 19.);
    if (h > .82){
      vec2 o = (hash22(id) - .5) * .6;
      float s = smoothstep(.07, 0., length((fr - o) * vec2(.35, 3.)));
      col += s * (.035 + .05 * fireFlicker(t) * step(uv.x, fp.x + .3)) * vec3(.8, .8, .85) * (.4 + fl * .3);
    }
  }
  // near-ground drift haze
  if (rd.y < .02){
    float drift = fbm4(vec2(uv.x * 3. + t * 1.4, uv.y * 14.));
    col += vec3(.02, .025, .035) * drift * smoothstep(.02, -.25, rd.y) * .8;
  }
  return col;
}

// ============================================================ CRT (copied from s01) ===
float pulsePattern(float t){
  float loc = mod(t, 2.4);
  float offs[6] = float[6](0.10, 0.35, 0.55, 0.95, 1.45, 1.65);
  float p = 0.0;
  for (int i = 0; i < 6; i++){
    float d = loc - offs[i];
    p = max(p, exp(-d * d * 2200.0));
  }
  return p;
}
float waveform(float x, float t){
  float pulse = pulsePattern(t - x * 0.35);
  float carrier = sin(x * 9.0 - t * 5.0);
  float n = (noise2(vec2(x * 24.0, t * 14.0)) - 0.5);
  return carrier * (0.035 + 0.30 * pulse) + n * 0.05 * (0.3 + pulse);
}
vec3 crtReceiver(vec2 fc, vec2 uv, float tLocal){
  float onT = smoothstep(0.0, 0.55, tLocal);
  float flicker = onT * (0.86 + 0.14 * hash11(floor(tLocal * 41.0) + 3.0));

  float zoom = 1.0;
  vec2 su = uv / zoom;
  float r2 = dot(su, su);
  vec2 cuv = su * (1.0 + 0.20 * r2);
  vec2 scr = cuv / vec2(0.60, 0.40);

  float inScreen = step(max(abs(scr.x), abs(scr.y)), 1.0);
  vec3 phosphor = vec3(0.30, 1.0, 0.42);

  vec3 panel = vec3(0.018, 0.02, 0.019) * (0.65 + 0.35 * fbm2(uv * 5.0 + 4.0));
  panel += vec3(0.03, 0.10, 0.045) * smoothstep(1.4, 1.0, max(abs(scr.x), abs(scr.y))) * flicker;

  vec2 gcell = scr * vec2(5.0, 4.0);
  vec2 gf = abs(fract(gcell) - 0.5);
  float grid = 1.0 - smoothstep(0.02, 0.04, min(gf.x, gf.y));
  float axis = 1.0 - smoothstep(0.01, 0.025, min(abs(scr.x), abs(scr.y)));

  float wx = scr.x;
  float wy = waveform(wx * 3.0, tLocal) * 1.7;
  float distL = abs(scr.y * 0.82 - wy);
  float trace = exp(-distL * 60.0) * 1.7 + exp(-distL * 14.0) * 0.32;

  float stripT = smoothstep(0.62, 0.72, scr.y) * (1.0 - smoothstep(0.9, 0.98, scr.y));
  float col_i = floor((scr.x * 0.5 + 0.5) * 44.0);
  float barH = hash21(vec2(col_i, floor(tLocal * 5.0))) * 0.5 + 0.5 * pulsePattern(tLocal - col_i * 0.015);
  float withinBar = step(1.0 - barH, (scr.y - 0.62) / 0.36 * -1.0 + 1.0);
  float spectro = stripT * withinBar * (0.5 + 0.5 * hash21(vec2(col_i, floor(tLocal * 20.0))));

  vec3 screenCol = vec3(0.0);
  screenCol += grid * 0.05 * phosphor;
  screenCol += axis * 0.08 * phosphor;
  screenCol += trace * phosphor;
  screenCol += spectro * phosphor * 0.7;
  screenCol += phosphor * 0.012;

  float streak = smoothstep(0.06, 0.0, abs(scr.x + scr.y * 0.35 - 0.65)) * 0.05;
  screenCol += streak;

  float tubeVig = clamp(1.0 - 0.35 * dot(scr, scr), 0.0, 1.0);
  screenCol *= tubeVig * flicker;

  vec3 col = mix(panel, screenCol, inScreen);
  vec3 prevCol = texture(iPrev, fc / iResolution).rgb;
  col = max(col, prevCol * 0.80 - 0.004);
  return col;
}

// ============================================================ render ===
vec3 render(vec2 fc){
  vec2 uv = screenUV(fc);

  if (iTime < 7.0){
    return exteriorScene(fc, uv, iTime);
  }
  if (iTime < 13.0){
    if (iTime < 7.3) return vec3(0.0);
    return crtReceiver(fc, uv, iTime - 7.3);
  }
  // 13-15s: hard black, title drawn in overlay
  return vec3(0.0);
}
