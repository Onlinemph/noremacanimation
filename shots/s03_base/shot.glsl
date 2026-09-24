// s03_base — reveal of Object 9, half-buried Soviet station, from beside the Sno-Cat.
#define V_BODY   20.0
#define V_LAMP   22.0
#define B_CONCRETE 30.0
#define B_DOOR     31.0
#define B_MODULE   32.0
#define B_STILT    33.0
#define B_MAST     34.0
#define B_BEACON   35.0
#define B_LAMPOFF  36.0
#define B_DRUM     37.0
#define B_SIGN     38.0

const vec2 WIND = vec2(0.92, 0.39);
const float WSPD = 1.4;

// ---------------------------------------------------------------- terrain ---
float terrainH(vec2 p){
  float base = (noise2(p * 0.012) * 2.0 - 1.0) * 0.45;
  vec2 w = vec2(dot(p, WIND), dot(p, vec2(-WIND.y, WIND.x)));
  float n1 = noise2(vec2(w.x * 0.025, w.y * 0.16) + base * 0.8);
  float ridge = pow(1.0 - abs(2.0 * n1 - 1.0), 2.4) * 0.22;
  float n2 = noise2(vec2(w.x * 0.05, w.y * 0.34) + base * 1.3 + 11.0);
  ridge += pow(1.0 - abs(2.0 * n2 - 1.0), 3.0) * 0.1;
  float fine = (noise2(p * 1.1 + base) - 0.5) * 0.018;
  return base * 0.3 + ridge + fine;
}
const float TERR_RANGE = 60.0;
const float TERR_STEP = 0.85;
bool terrainHit(vec3 ro, vec3 rd, out float dist){
  if (rd.y > 0.02) { dist = TERR_RANGE; return false; }
  float prevY = ro.y - terrainH(ro.xz);
  float prevD = 0.0;
  for (int i = 1; i <= 70; i++){
    float dd = float(i) * TERR_STEP;
    vec3 p = ro + rd * dd;
    float y = p.y - terrainH(p.xz);
    if (y < 0.0 && prevY >= 0.0){
      float lo = prevD, hi = dd;
      for (int k = 0; k < 5; k++){
        float mid = (lo + hi) * 0.5;
        vec3 pm = ro + rd * mid;
        if (pm.y - terrainH(pm.xz) < 0.0) hi = mid; else lo = mid;
      }
      dist = hi; return true;
    }
    prevY = y; prevD = dd;
  }
  dist = TERR_RANGE; return false;
}
vec3 terrainNrm(vec3 p){
  vec2 e = vec2(.04, 0.);
  float hL = terrainH(p.xz - e.xy), hR = terrainH(p.xz + e.xy);
  float hD = terrainH(p.xz - e.yx), hU = terrainH(p.xz + e.yx);
  return normalize(vec3(hL - hR, 2.0 * e.x, hD - hU));
}

// ------------------------------------------------------------- foreground vehicle (partial) ---
// We ride just behind/beside the Sno-Cat; only its rear-hood corner and headlights need to read.
vec2 sdVehicleLite(vec3 p){
  vec2 r = vec2(1e5, V_BODY);
  float hull = sdRoundBox(p - vec3(0., .78, 0.), vec3(1.05, .5, 2.1), .18);
  r = opU(r, vec2(hull, V_BODY));
  vec3 cq = p - vec3(0., 1.6, -.6);
  float cab = sdRoundBox(cq, vec3(.92, .46, 1.0), .12);
  r = opU(r, vec2(cab, V_BODY));
  for (int s = 0; s < 2; s++){
    float sg = s == 0 ? -1. : 1.;
    r = opU(r, vec2(sdSphere(p - vec3(.62 * sg, .92, 2.05), .1), V_LAMP));
  }
  return r;
}

// ---------------------------------------------------------------- base cluster ---
// Bunker facade + recessed blast door, corrugated modules on stilts, lattice mast with a
// blinking beacon, a dead sodium lamp, half-buried fuel drums. Positions are world-fixed.
const vec3 BUNKER_C = vec3(-2.5, 2.5, 33.0);
const vec3 BUNKER_H = vec3(5.2, 2.5, 2.9);
const vec3 MAST_BASE = vec3(6.2, 0.0, 31.0);
const float MAST_H = 15.5;

float sdLatticeMast(vec3 p){
  vec3 q = p - MAST_BASE;
  float taper = clamp(q.y / MAST_H, 0.0, 1.0);
  float half = mix(.62, .12, taper);
  float d = 1e5;
  // four corner rods
  for (int i = 0; i < 4; i++){
    float sx = (i == 0 || i == 1) ? -1. : 1.;
    float sz = (i == 0 || i == 2) ? -1. : 1.;
    vec3 top = vec3(sx * mix(.62, .12, 1.0), MAST_H, sz * mix(.62, .12, 1.0));
    vec3 bot = vec3(sx * .62, 0., sz * .62);
    d = min(d, sdCapsule(q, bot, top, .035));
  }
  // rungs every ~2.6m
  for (int i = 0; i < 6; i++){
    float h = float(i) * 2.6 + 0.5;
    if (h > MAST_H) continue;
    float hf = clamp(h / MAST_H, 0.0, 1.0);
    float hh = mix(.62, .12, hf);
    vec3 c = vec3(0., h, 0.);
    d = min(d, sdBox(rotY(q - c, PI * 0.25), vec3(hh * 1.42, .025, .025)));
    d = min(d, sdBox(rotY(q - c, -PI * 0.25), vec3(hh * 1.42, .025, .025)));
  }
  return d;
}
float sdGuyWires(vec3 p){
  vec3 top = MAST_BASE + vec3(0., MAST_H * 0.62, 0.);
  float d = 1e5;
  for (int i = 0; i < 3; i++){
    float a = float(i) / 3.0 * TAU + 0.4;
    vec3 anchor = MAST_BASE + vec3(cos(a), 0., sin(a)) * 6.5;
    d = min(d, sdCapsule(p, top, anchor, .012));
  }
  return d;
}

vec2 sdBase(vec3 p){
  vec2 r = vec2(1e5, B_CONCRETE);

  // bunker facade with a recessed trench for the blast door
  float facade = sdBox(p - BUNKER_C, BUNKER_H);
  vec3 dq = p - (BUNKER_C - vec3(0., BUNKER_H.y - 1.3, BUNKER_H.z));
  float trench = sdBox(dq, vec3(1.15, 1.3, 0.5));
  facade = smax(facade, -trench, .04);
  r = opU(r, vec2(facade, B_CONCRETE));
  vec3 doorQ = p - (BUNKER_C - vec3(0., BUNKER_H.y - 1.3, BUNKER_H.z + 0.15));
  float door = sdBox(doorQ, vec3(1.0, 1.15, .12));
  r = opU(r, vec2(door, B_DOOR));
  // signage panel on the facade, upper-left of the door
  vec3 sq = p - (BUNKER_C + vec3(-1.6, 0.55, -BUNKER_H.z - 0.02));
  float sign = sdBox(sq, vec3(1.7, 1.15, .03));
  r = opU(r, vec2(sign, B_SIGN));

  // corrugated modules on stilts, off to the side
  for (int m = 0; m < 2; m++){
    vec3 mc = vec3(-11.5 - float(m) * 7.2, 2.35, 30.5 + float(m) * 1.4);
    vec3 mq = p - mc;
    float mod_ = sdRoundBox(mq, vec3(4.6, .95, 1.5), .12);
    r = opU(r, vec2(mod_, B_MODULE));
    for (int s = 0; s < 5; s++){
      float sx = mix(-3.8, 3.8, float(s) / 4.0);
      vec3 legBase = mc + vec3(sx, -mc.y, 1.0);
      float legH = terrainH(legBase.xz);
      vec3 legTop = mc + vec3(sx, -0.9, 1.0);
      vec3 legBot = vec3(legBase.x, legH, legBase.z);
      r = opU(r, vec2(sdCylY(p - mix(legTop, legBot, .5), .05, length(legTop - legBot) * .5 + .02), B_STILT));
    }
  }

  // dead sodium lamp near the entrance
  vec3 lp = vec3(2.6, 0., 29.5);
  float lampH = terrainH(lp.xz);
  r = opU(r, vec2(sdCylY(p - vec3(lp.x, lampH + 1.75, lp.z), .04, 1.75), B_LAMPOFF));
  r = opU(r, vec2(sdSphere(p - vec3(lp.x, lampH + 3.55, lp.z), .18), B_LAMPOFF));

  // fuel drums, half sunk
  for (int i = 0; i < 3; i++){
    vec3 dc = vec3(-6.0 + float(i) * 0.9, 0., 27.0 - float(i) * 0.5);
    float dh = terrainH(dc.xz);
    vec3 dq2 = p - vec3(dc.x, dh + 0.15, dc.z);
    dq2.xz *= rot2(float(i) * 1.3);
    r = opU(r, vec2(sdCylY(dq2, .32, .46), B_DRUM));
  }

  return r;
}

vec2 mapBaseBounded(vec3 p){
  vec3 c = vec3(-3.5, 6.5, 32.0);
  float bound = sdBox(p - c, vec3(18.0, 8.5, 8.0));
  if (bound > .5) return vec2(bound + .3, B_CONCRETE);
  vec2 r = sdBase(p);
  float mastB = sdBox(p - (MAST_BASE + vec3(0., MAST_H * .5, 0.)), vec3(1.2, MAST_H * .5 + 1., 1.2));
  if (mastB < .6){
    r = opU(r, vec2(sdLatticeMast(p), B_MAST));
    r = opU(r, vec2(sdGuyWires(p), B_MAST));
    r = opU(r, vec2(sdSphere(p - (MAST_BASE + vec3(0., MAST_H, 0.)), .22), B_BEACON));
  } else {
    r = opU(r, vec2(mastB, B_MAST));
  }
  return r;
}

vec3 baseNrm(vec3 p){
  vec2 e = vec2(.015, 0.);
  return normalize(vec3(
    mapBaseBounded(p + e.xyy).x - mapBaseBounded(p - e.xyy).x,
    mapBaseBounded(p + e.yxy).x - mapBaseBounded(p - e.yxy).x,
    mapBaseBounded(p + e.yyx).x - mapBaseBounded(p - e.yyx).x));
}
vec3 vehLiteNrm(vec3 p){
  vec2 e = vec2(.01, 0.);
  return normalize(vec3(
    sdVehicleLite(p + e.xyy).x - sdVehicleLite(p - e.xyy).x,
    sdVehicleLite(p + e.yxy).x - sdVehicleLite(p - e.yxy).x,
    sdVehicleLite(p + e.yyx).x - sdVehicleLite(p - e.yyx).x));
}

// -------------------------------------------------------------- snow fx -----
float gustEnv(float t){
  float g = exp(-pow((t - 2.0) / 1.4, 2.0)) + exp(-pow((t - 6.5) / 1.6, 2.0));
  return clamp(g, 0.0, 1.2);
}
float snowStreaks(vec2 uv, float t, float gust){
  float s = 0.0;
  vec2 dir = normalize(vec2(.4, -1.0));
  vec2 perp = vec2(-dir.y, dir.x);
  for (int i = 0; i < 3; i++){
    float fi = float(i);
    float scale = mix(20.0, 52.0, fi / 2.0);
    float speed = mix(0.9, 2.0, fi / 2.0);
    float elong = mix(1.6, 3.2, fi / 2.0);
    vec2 st = uv + vec2(fi * 5.3, fi * 2.1);
    vec2 q = vec2(dot(st, dir), dot(st, perp)) * scale;
    q.y += t * speed * scale * 0.05;
    vec2 id = floor(q);
    vec2 f = fract(q) - .5;
    vec2 hh = hash22(id + fi * 23.7);
    if (hh.x > 0.14) continue;
    vec2 fa = vec2(f.x / elong, f.y);
    float dd = length(fa);
    float flake = smoothstep(0.22, 0.02, dd);
    s += flake * (0.5 + 0.5 * hh.y) * (1.0 - fi * 0.2);
  }
  return clamp(s * (0.5 + gust * 0.6), 0.0, 1.0);
}

// ------------------------------------------------------------------ shade ---
vec3 baseAlbedo(float m, vec3 p, float beacon){
  if (m == B_DOOR){
    float rust = smoothstep(.4, .85, fbm3lo(p * 2.5 + 6.));
    return mix(vec3(.10, .11, .115), vec3(.14, .07, .04), rust);
  }
  if (m == B_MODULE || m == B_STILT || m == B_MAST || m == B_LAMPOFF){
    float rust = smoothstep(.45, .85, fbm3lo(p * 3.0 + 2.));
    vec3 base = mix(vec3(.13, .15, .13), vec3(.16, .09, .05), rust);
    return base;
  }
  if (m == B_DRUM){
    float rust = smoothstep(.3, .8, fbm3lo(p * 4.0 + 9.));
    return mix(vec3(.35, .1, .04), vec3(.15, .05, .02), rust);
  }
  if (m == B_BEACON) return vec3(1.0, .08, .04) * (2.0 + beacon * 9.0);
  if (m == B_SIGN) return vec3(.28, .29, .27);
  // concrete
  float grime = fbm3lo(p * 1.6 + 1.);
  float frost = smoothstep(.4, .85, fbm3lo(p * 5.0 - 4.));
  vec3 c = mix(vec3(.24, .24, .22), vec3(.14, .14, .13), smoothstep(.4, .75, grime));
  return mix(c, vec3(.55, .58, .62), frost * .55);
}
vec3 vehLiteAlbedo(vec3 p){
  float grime = smoothstep(.35, .8, fbm3lo(p * 3.5 + 4.));
  return mix(vec3(.55, .08, .05), vec3(.18, .03, .02), grime);
}

vec3 render(vec2 fc){
  float t = iTime;
  vec2 uv2 = screenUV(fc);

  // camera rides just behind/beside the Sno-Cat, slow push toward the base
  vec3 camPos0 = vec3(1.15, 1.35, -1.6);
  float push = t * 0.55;
  vec3 ro = camPos0 + vec3(0., 0., push);
  ro.y = max(ro.y, terrainH(ro.xz) + 0.85);
  vec3 ta = vec3(-1.0, 1.3, 30.0);
  float shakeN = (noise2(vec2(t * 2.6, 9.)) - .5) * .012;
  vec3 rd = camRay(fc, ro, ta + vec3(shakeN, shakeN * .4, 0.), 1.55, 0.006 * sin(t * .5));

  // foreground vehicle sits just left of / behind camera; only its corner enters frame
  vec3 vRef = camPos0 + vec3(-1.05, -0.42, 0.35 + push);
  vec3 lightL = vRef + vec3(-.62, .92, 2.05);
  vec3 lightR = vRef + vec3(.62, .92, 2.05);
  vec3 aimDir = normalize(vec3(0.02, -0.02, 1.0));

  float tDist; bool tHit = terrainHit(ro, rd, tDist);
  float vd = 0.25; bool vHit = false; float vMat = 0.;
  for (int i = 0; i < 60; i++){
    vec3 p = ro + rd * vd - vRef;
    vec2 h = sdVehicleLite(p);
    if (h.x < .0015) { vHit = true; vMat = h.y; break; }
    vd += h.x;
    if (vd > 30.0) break;
  }
  float bd = 0.3; bool bHit = false; float bMat = 0.;
  for (int i = 0; i < 110; i++){
    vec3 p = ro + rd * bd;
    vec2 h = mapBaseBounded(p);
    if (h.x < .0025) { bHit = true; bMat = h.y; break; }
    bd += h.x;
    if (bd > 70.0) break;
  }

  float dists[3];
  dists[0] = tHit ? tDist : 1e5;
  dists[1] = vHit ? vd : 1e5;
  dists[2] = bHit ? bd : 1e5;
  int which = 0;
  float dist = dists[0];
  if (dists[1] < dist) { dist = dists[1]; which = 1; }
  if (dists[2] < dist) { dist = dists[2]; which = 2; }
  bool anyHit = dist < 1e4;

  vec3 upDir = normalize(vec3(0.03, 1.0, 0.02));
  vec3 skyCol = vec3(.003, .006, .014) + vec3(.006, .01, .02) * max(0., rd.y);
  skyCol += stars(rd) * vec3(.8, .85, 1.0) * smoothstep(-.05, .3, rd.y);
  skyCol += aurora(rd, t) * 1.2;
  skyCol += vec3(.02, .03, .05) * exp(-max(rd.y, 0.0) * 6.0);

  // mast beacon: sharp aviation-style flash
  float beaconPhase = fract(t / 1.6);
  float beacon = smoothstep(.88, .93, beaconPhase) * smoothstep(1.0, .95, beaconPhase);

  vec3 col;
  if (anyHit){
    vec3 p = ro + rd * dist;
    vec3 n = which == 0 ? terrainNrm(p) : (which == 1 ? vehLiteNrm(p - vRef) : baseNrm(p));
    float mat = which == 0 ? M_SNOW : (which == 1 ? vMat : bMat);
    vec3 albedo = (mat == M_SNOW) ? mix(vec3(.5, .58, .74), vec3(.82, .87, .96), smoothstep(-.1, .35, n.y)) * (0.8 + 0.3 * fbm3lo(p * 5.0))
                  : (which == 1 ? vehLiteAlbedo(p - vRef) : baseAlbedo(mat, p, beacon));

    vec3 amb = (aurora(upDir, t) * 3.0 + vec3(.022, .028, .05)) * (0.55 + 0.45 * max(n.y, 0.0));
    // beacon bathes nearby surfaces in a faint red pulse
    vec3 beaconPos = MAST_BASE + vec3(0., MAST_H, 0.);
    float bDist = length(beaconPos - p);
    vec3 beaconLight = vec3(1.0, .1, .05) * beacon * 4.0 / (1.0 + bDist * bDist * .02);
    vec3 col3 = albedo * (amb + beaconLight);

    if (mat != B_SIGN) {
      for (int li = 0; li < 2; li++){
        vec3 lp = li == 0 ? lightL : lightR;
        vec3 L = lp - p; float ld = length(L); L /= ld;
        float atten = 1.0 / (1.0 + ld * ld * .03);
        float cone = spotLight(p, lp, aimDir, .8, .94);
        float dif = max(dot(n, L), 0.0);
        float spec = pow(max(dot(reflect(-L, n), -rd), 0.0), 20.0);
        vec3 lc = vec3(1.0, .82, .55) * cone * dif * atten * 3.4;
        float scatter = dif * atten * 0.35;
        col3 += albedo * (lc + vec3(1.0, .8, .55) * scatter) + spec * cone * atten * 1.2;
      }
    } else {
      // signage: sample the drawn texture (stencil Cyrillic + faded star) mapped to the panel
      vec2 su = vec2((p.x - (BUNKER_C.x - 1.6 - 1.7)) / 3.4, (p.y - (BUNKER_C.y + 0.55 - 1.15)) / 2.3);
      vec4 tex = texture(iTex0, clamp(su, 0.0, 1.0));
      vec3 wallLit = albedo * amb;
      for (int li = 0; li < 2; li++){
        vec3 lp = li == 0 ? lightL : lightR;
        vec3 L = lp - p; float ld = length(L); L /= ld;
        float atten = 1.0 / (1.0 + ld * ld * .03);
        float cone = spotLight(p, lp, aimDir, .8, .94);
        float dif = max(dot(n, L), 0.0);
        wallLit += albedo * vec3(1.0, .82, .55) * cone * dif * atten * 3.0;
      }
      col3 = mix(wallLit, tex.rgb * (amb.g * 3.0 + 0.3), tex.a * 0.85);
    }
    if (mat == V_LAMP) col3 = vec3(1.0, .86, .55) * 6.0;
    if (mat == B_BEACON) col3 = albedo;
    col = col3;
  } else {
    col = skyCol;
  }

  // volumetric headlight shafts (gated, only near the beam)
  vec3 beamCenter = mix(lightL, lightR, .5) + vec3(0., 0., 6.);
  vec3 toBeam = beamCenter - ro; float distBeam = length(toBeam);
  if (distBeam < 45.0 && dot(rd, toBeam / max(distBeam, .001)) > 0.55){
    vec3 shaft = vec3(0.);
    float maxD = min(dist, 40.0);
    const int NS = 5;
    float stepL = maxD / float(NS);
    float o = hash21(fc);
    for (int i = 0; i < NS; i++){
      float sd = (float(i) + o) * stepL;
      vec3 sp = ro + rd * sd;
      for (int li = 0; li < 2; li++){
        vec3 lp = li == 0 ? lightL : lightR;
        vec3 Ld = lp - sp; float ldist = length(Ld); Ld /= ldist;
        float cone = spotLight(sp, lp, aimDir, .82, .95);
        float ph = hgPhase(dot(rd, -Ld), .55);
        float dens = 0.5 + 0.8 * fbm3lo(sp * .5 + t * vec3(WIND.x, 0., WIND.y) * WSPD);
        shaft += vec3(1.0, .8, .5) * cone * ph * dens * stepL * 0.08;
      }
    }
    col += shaft;
  }
  // faint red volumetric glow from the beacon flash
  if (beacon > 0.01){
    vec3 bp = MAST_BASE + vec3(0., MAST_H, 0.);
    float ang = dot(rd, normalize(bp - ro));
    col += vec3(1.0, .08, .04) * beacon * smoothstep(.995, 1.0, ang) * 1.5;
  }

  // ground drift
  {
    vec3 samp = ro + rd * min(dist, 26.0);
    float heightW = exp(-max(samp.y, 0.0) * 1.4);
    float n = fbm2(samp.xz * 0.1 + t * WIND * WSPD * 0.6);
    float gust = gustEnv(t);
    float drift = heightW * (0.28 + 0.5 * n) * (0.5 + gust * 0.8);
    float distW = 1.0 - exp(-min(dist, 26.0) * 0.04);
    col = mix(col, vec3(.04, .05, .065), clamp(drift * distW, 0., 0.65));
  }

  // atmospheric fog
  float gust = gustEnv(t);
  float fogAmt = 1.0 - exp(-dist * 0.02 * (0.6 + gust * 0.5));
  vec3 fogCol = vec3(.009, .013, .024);
  col = mix(col, fogCol, clamp(fogAmt, 0., 0.92));

  // snow streaks
  vec3 beamDir = normalize(beamCenter - ro);
  float towardLight = smoothstep(.4, .95, max(dot(beamDir, rd), 0.0));
  float streaks = snowStreaks(uv2, t, gust);
  col += streaks * mix(vec3(.2, .22, .28), vec3(1.0, .85, .6), towardLight * 0.8) * 0.4;

  return col;
}
