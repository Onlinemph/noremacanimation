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
const float WSPD = 1.3;
const vec2 SWIND = normalize(vec2(1.0, -0.2));

// ---------------------------------------------------------------- terrain ---
float terrainH(vec2 p){
  float base = (noise2(p * 0.012) * 2.0 - 1.0) * 0.4;
  vec2 w = vec2(dot(p, WIND), dot(p, vec2(-WIND.y, WIND.x)));
  float n1 = noise2(vec2(w.x * 0.025, w.y * 0.16) + base * 0.8);
  float ridge = pow(1.0 - abs(2.0 * n1 - 1.0), 2.4) * 0.2;
  float n2 = noise2(vec2(w.x * 0.05, w.y * 0.34) + base * 1.3 + 11.0);
  ridge += pow(1.0 - abs(2.0 * n2 - 1.0), 3.0) * 0.09;
  float fine = (noise2(p * 1.1 + base) - 0.5) * 0.016;
  return base * 0.3 + ridge + fine;
}
const float TERR_RANGE = 30.0;
const float TERR_STEP = 0.75;
bool terrainHit(vec3 ro, vec3 rd, out float dist){
  if (rd.y > 0.02) { dist = TERR_RANGE; return false; }
  float prevY = ro.y - terrainH(ro.xz);
  float prevD = 0.0;
  for (int i = 1; i <= 32; i++){
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
  // analytic flat-plane fallback beyond the detailed range, so ground keeps going to the
  // horizon instead of hard-cutting to sky (fog hides the loss of ridge detail out there).
  if (rd.y < -0.0008){
    float planeD = -ro.y / rd.y;
    if (planeD > TERR_RANGE) { dist = min(planeD, 150.0); return true; }
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
vec2 sdVehicleLite(vec3 p){
  vec2 r = vec2(1e5, V_BODY);
  float hull = sdRoundBox(p - vec3(0., .78, 0.), vec3(1.05, .5, 2.1), .18);
  vec3 cq = p - vec3(0., 1.6, -.6);
  float cab = sdRoundBox(cq, vec3(.9, .44, 1.0), .12);
  r = opU(r, vec2(smin(hull, cab, .12), V_BODY));
  vec3 lp = vec3(abs(p.x) - .8, p.y - .92, p.z - 2.05);
  r = opU(r, vec2(sdSphere(lp, .12), V_LAMP));
  return r;
}
vec3 vehLiteNrm(vec3 p){
  vec2 e = vec2(.01, 0.);
  return normalize(vec3(
    sdVehicleLite(p + e.xyy).x - sdVehicleLite(p - e.xyy).x,
    sdVehicleLite(p + e.yxy).x - sdVehicleLite(p - e.yxy).x,
    sdVehicleLite(p + e.yyx).x - sdVehicleLite(p - e.yyx).x));
}

// ---------------------------------------------------------------- base cluster ---
const vec3 BUNKER_C = vec3(-2.5, 2.4, 21.0);
const vec3 BUNKER_H = vec3(5.0, 2.4, 2.8);
const vec3 MAST_BASE = vec3(6.0, 0.0, 19.0);
const float MAST_H = 14.0;

float sdLatticeMast(vec3 p){
  vec3 q = p - MAST_BASE;
  float d = 1e5;
  for (int i = 0; i < 4; i++){
    float sx = (i == 0 || i == 1) ? -1. : 1.;
    float sz = (i == 0 || i == 2) ? -1. : 1.;
    vec3 top = vec3(sx * .12, MAST_H, sz * .12);
    vec3 bot = vec3(sx * .58, 0., sz * .58);
    d = min(d, sdCapsule(q, bot, top, .032));
  }
  for (int i = 0; i < 5; i++){
    float h = float(i) * 2.6 + 0.5;
    if (h > MAST_H) continue;
    float hf = clamp(h / MAST_H, 0.0, 1.0);
    float hh = mix(.58, .12, hf);
    vec3 c = vec3(0., h, 0.);
    d = min(d, sdBox(rotY(q - c, PI * 0.25), vec3(hh * 1.42, .022, .022)));
    d = min(d, sdBox(rotY(q - c, -PI * 0.25), vec3(hh * 1.42, .022, .022)));
  }
  return d;
}
float sdGuyWires(vec3 p){
  vec3 top = MAST_BASE + vec3(0., MAST_H * 0.6, 0.);
  float d = 1e5;
  for (int i = 0; i < 3; i++){
    float a = float(i) / 3.0 * TAU + 0.4;
    vec3 anchor = MAST_BASE + vec3(cos(a), 0., sin(a)) * 6.0;
    d = min(d, sdCapsule(p, top, anchor, .011));
  }
  return d;
}

// Each sub-cluster is guarded by its own cheap bound first, so a ray marching through open
// space between the bunker/modules/lamp/drums takes big steps instead of paying for every
// thin stilt and drum primitive on every step (the dominant cost in this shot).
vec2 sdBunker(vec3 p){
  vec2 r = vec2(1e5, B_CONCRETE);
  float facade = sdBox(p - BUNKER_C, BUNKER_H);
  vec3 dq = p - (BUNKER_C - vec3(0., BUNKER_H.y - 1.3, BUNKER_H.z));
  float trench = sdBox(dq, vec3(1.1, 1.3, 0.45));
  facade = smax(facade, -trench, .04);
  r = opU(r, vec2(facade, B_CONCRETE));
  vec3 doorQ = p - (BUNKER_C - vec3(0., BUNKER_H.y - 1.3, BUNKER_H.z + 0.12));
  float door = sdBox(doorQ, vec3(0.95, 1.1, .1));
  r = opU(r, vec2(door, B_DOOR));
  vec3 sq = p - (BUNKER_C + vec3(-1.5, 0.5, -BUNKER_H.z - 0.02));
  float sign = sdBox(sq, vec3(1.6, 1.1, .03));
  r = opU(r, vec2(sign, B_SIGN));
  return r;
}
vec2 sdModules(vec3 p){
  vec2 r = vec2(1e5, B_MODULE);
  for (int m = 0; m < 2; m++){
    vec3 mc = vec3(-10.5 - float(m) * 6.8, 2.2, 18.8 + float(m) * 1.2);
    vec3 mq = p - mc;
    float mod_ = sdRoundBox(mq, vec3(4.3, .9, 1.4), .12);
    r = opU(r, vec2(mod_, B_MODULE));
    for (int s = 0; s < 4; s++){
      float sx = mix(-3.5, 3.5, float(s) / 3.0);
      vec3 legTop = mc + vec3(sx, -0.85, 1.0);
      float legH = terrainH(vec2(legTop.x, legTop.z));
      vec3 legBot = vec3(legTop.x, legH, legTop.z);
      r = opU(r, vec2(sdCylY(p - mix(legTop, legBot, .5), .05, length(legTop - legBot) * .5 + .02), B_STILT));
    }
  }
  return r;
}
vec2 sdLampDrums(vec3 p){
  vec2 r = vec2(1e5, B_LAMPOFF);
  vec3 lpp = vec3(2.4, 0., 17.0);
  float lampH = terrainH(lpp.xz);
  r = opU(r, vec2(sdCylY(p - vec3(lpp.x, lampH + 1.7, lpp.z), .04, 1.7), B_LAMPOFF));
  r = opU(r, vec2(sdSphere(p - vec3(lpp.x, lampH + 3.45, lpp.z), .17), B_LAMPOFF));
  for (int i = 0; i < 3; i++){
    vec3 dc = vec3(-5.5 + float(i) * 0.9, 0., 15.0 - float(i) * 0.5);
    float dh = terrainH(dc.xz);
    vec3 dq2 = p - vec3(dc.x, dh + 0.15, dc.z);
    dq2.xz *= rot2(float(i) * 1.3);
    r = opU(r, vec2(sdCylY(dq2, .3, .44), B_DRUM));
  }
  return r;
}
vec2 sdBase(vec3 p){
  vec2 r = vec2(1e5, B_CONCRETE);
  float bunkerB = sdBox(p - (BUNKER_C + vec3(0., 0., -1.5)), BUNKER_H + vec3(0.8, 0.8, 2.0));
  r = opU(r, bunkerB < .6 ? sdBunker(p) : vec2(bunkerB + .4, B_CONCRETE));
  float modB = sdBox(p - vec3(-13.9, 2.2, 19.4), vec3(9.5, 2.0, 2.5));
  r = opU(r, modB < .6 ? sdModules(p) : vec2(modB + .4, B_MODULE));
  float ldB = sdBox(p - vec3(-1.5, 1.8, 15.5), vec3(4.5, 2.0, 2.0));
  r = opU(r, ldB < .6 ? sdLampDrums(p) : vec2(ldB + .4, B_LAMPOFF));
  return r;
}

vec2 mapBaseBounded(vec3 p){
  vec3 c = vec3(-2.5, 6.0, 19.5);
  float bound = sdBox(p - c, vec3(17.0, 8.0, 8.0));
  if (bound > .6) return vec2(bound + .4, B_CONCRETE);
  vec2 r = sdBase(p);
  float mastB = sdBox(p - (MAST_BASE + vec3(0., MAST_H * .5, 0.)), vec3(1.1, MAST_H * .5 + 1., 1.1));
  if (mastB < .7){
    r = opU(r, vec2(sdLatticeMast(p), B_MAST));
    r = opU(r, vec2(sdGuyWires(p), B_MAST));
    r = opU(r, vec2(sdSphere(p - (MAST_BASE + vec3(0., MAST_H, 0.)), .2), B_BEACON));
  } else {
    r = opU(r, vec2(mastB, B_MAST));
  }
  return r;
}
vec3 baseNrm(vec3 p){
  vec2 e = vec2(.018, 0.);
  return normalize(vec3(
    mapBaseBounded(p + e.xyy).x - mapBaseBounded(p - e.xyy).x,
    mapBaseBounded(p + e.yxy).x - mapBaseBounded(p - e.yxy).x,
    mapBaseBounded(p + e.yyx).x - mapBaseBounded(p - e.yyx).x));
}

// -------------------------------------------------------------- snow fx -----
float gustEnv(float t){
  float g = exp(-pow((t - 2.0) / 1.4, 2.0)) + exp(-pow((t - 6.5) / 1.6, 2.0));
  return clamp(g, 0.0, 1.2);
}
vec2 snowStreaks(vec2 uv, float t, float gust){
  float s = 0.0, br = 0.0;
  vec2 dir = SWIND;
  vec2 perp = vec2(-dir.y, dir.x);
  const int NL = 3;
  for (int i = 0; i < NL; i++){
    float fi = float(i) / float(NL - 1);
    float scale = mix(80.0, 18.0, fi);
    float speed = mix(0.5, 2.4, fi) * (1.0 + gust * 0.7);
    float elong = mix(1.3, 5.5, fi);
    float density = mix(0.2, 0.045, fi);
    vec2 st = uv + vec2(fi * 7.1, fi * 2.9);
    vec2 q = vec2(dot(st, dir), dot(st, perp)) * scale;
    q.x -= t * speed * scale * 0.09;
    vec2 id = floor(q);
    vec2 f = fract(q) - .5;
    vec2 hh = hash22(id + fi * 23.7 + 5.0);
    if (hh.x > density) continue;
    vec2 fa = vec2(f.x / elong, f.y);
    float dd = length(fa);
    float soft = mix(0.28, 0.06, fi);
    float flake = smoothstep(soft, 0.0, dd);
    float layerBr = mix(0.07, 0.7, fi * fi * fi) * (0.35 + 0.65 * hh.y);
    s += flake;
    br += flake * layerBr;
  }
  return vec2(clamp(s, 0.0, 1.0), br);
}
float skyTexture(vec3 dir, float t){
  vec2 pp = dir.xz / max(dir.y, 0.05);
  return fbm2(pp * 0.5 + WIND * t * 0.03);
}

// ------------------------------------------------------------------ shade ---
vec3 baseAlbedo(float m, vec3 p, float beacon){
  if (m == B_DOOR){
    float rust = smoothstep(.4, .85, fbm3lo(p * 2.5 + 6.));
    return mix(vec3(.10, .11, .115), vec3(.14, .07, .04), rust);
  }
  if (m == B_MODULE || m == B_STILT || m == B_MAST || m == B_LAMPOFF){
    float rust = smoothstep(.45, .85, fbm3lo(p * 3.0 + 2.));
    return mix(vec3(.13, .15, .13), vec3(.16, .09, .05), rust);
  }
  if (m == B_DRUM){
    float rust = smoothstep(.3, .8, fbm3lo(p * 4.0 + 9.));
    return mix(vec3(.35, .1, .04), vec3(.15, .05, .02), rust);
  }
  if (m == B_BEACON) return vec3(1.0, .08, .04) * (2.0 + beacon * 9.0);
  if (m == B_SIGN) return vec3(.28, .29, .27);
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

  vec3 camPos0 = vec3(1.1, 1.3, -1.6);
  float push = t * 1.15;
  vec3 ro = camPos0 + vec3(0., 0., push);
  ro.y = max(ro.y, terrainH(ro.xz) + 0.8);
  vec3 ta = vec3(-1.0, 1.25, 19.0);
  float shakeN = (noise2(vec2(t * 2.6, 9.)) - .5) * .012;
  vec3 rd = camRay(fc, ro, ta + vec3(shakeN, shakeN * .4, 0.), 1.5, 0.006 * sin(t * .5));

  // vehicle hull sits well clear of the camera (a few metres) so it reads as a recognizable
  // shape at the frame edge instead of a looming, unlit mass pressed against the lens.
  vec3 vRef = ro + vec3(2.7, -0.6, 0.5);
  vec3 lightL = vRef + vec3(-.8, .92, 2.05);
  vec3 lightR = vRef + vec3(.8, .92, 2.05);
  vec3 aimDir = normalize(vec3(0.02, -0.02, 1.0));

  float tDist; bool tHit = terrainHit(ro, rd, tDist);
  float vd = 0.25; bool vHit = false; float vMat = 0.;
  for (int i = 0; i < 34; i++){
    vec3 p = ro + rd * vd - vRef;
    vec2 h = sdVehicleLite(p);
    if (h.x < .003) { vHit = true; vMat = h.y; break; }
    vd += h.x;
    if (vd > 30.0) break;
  }
  float bd = 0.3; bool bHit = false; float bMat = 0.;
  for (int i = 0; i < 56; i++){
    vec3 p = ro + rd * bd;
    vec2 h = mapBaseBounded(p);
    if (h.x < .004) { bHit = true; bMat = h.y; break; }
    bd += h.x;
    if (bd > 65.0) break;
  }

  float dT = tHit ? tDist : 1e5;
  float dV = vHit ? vd : 1e5;
  float dB = bHit ? bd : 1e5;
  int which = 0;
  float dist = dT;
  if (dV < dist) { dist = dV; which = 1; }
  if (dB < dist) { dist = dB; which = 2; }
  bool anyHit = dist < 1e4;

  vec3 upDir = normalize(vec3(0.03, 1.0, 0.02));
  float skyTex = skyTexture(rd, t);
  vec3 skyBase = mix(vec3(.006, .008, .012), vec3(.013, .016, .022), smoothstep(.3, .8, skyTex));
  vec3 skyCol = skyBase * mix(0.7, 1.15, max(0., rd.y));
  skyCol += stars(rd) * vec3(.75, .8, .95) * smoothstep(-.05, .3, rd.y) * smoothstep(.7, .3, skyTex);
  skyCol += aurora(rd, t) * (0.5 + 0.28 * skyTex);

  float beaconPhase = fract(t / 1.6);
  float beacon = smoothstep(.88, .93, beaconPhase) * smoothstep(1.0, .95, beaconPhase);
  float gust = gustEnv(t);

  vec3 col;
  if (anyHit){
    vec3 p = ro + rd * dist;
    vec3 n = which == 0 ? terrainNrm(p) : (which == 1 ? vehLiteNrm(p - vRef) : baseNrm(p));
    float mat = which == 0 ? M_SNOW : (which == 1 ? vMat : bMat);
    vec3 albedo = (mat == M_SNOW) ? mix(vec3(.42, .5, .68), vec3(.88, .91, .99), smoothstep(-.15, .4, n.y)) * (0.68 + 0.55 * fbm3lo(p * 6.0))
                  : (which == 1 ? vehLiteAlbedo(p - vRef) : baseAlbedo(mat, p, beacon));

    // subtle sky-bounce ambient — NOT keyed to the full straight-up aurora sample, which stays
    // bright even when the view-direction aurora near the horizon has faded to zero.
    vec3 amb = (aurora(upDir, t) * 0.45 + vec3(.022, .028, .05)) * (0.55 + 0.45 * max(n.y, 0.0));
    vec3 beaconPos = MAST_BASE + vec3(0., MAST_H, 0.);
    float bDist = length(beaconPos - p);
    vec3 beaconLight = vec3(1.0, .1, .05) * beacon * 4.0 / (1.0 + bDist * bDist * .02);
    float fres = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    vec3 rim = vec3(.09, .12, .17) * fres * (mat == M_SNOW ? 0.25 : 1.4);
    vec3 col3 = albedo * (amb + beaconLight) + rim;

    if (mat != B_SIGN) {
      for (int li = 0; li < 2; li++){
        vec3 lp = li == 0 ? lightL : lightR;
        vec3 L = lp - p; float ld = length(L); L /= ld;
        // NOTE: spotLight() already bakes distance falloff into its return value (cone/(1+d^2*.15)) —
        // do not also multiply the coned terms by a separate atten, or light dies by d^4 at range.
        // scatterAtten is its own, gentler falloff used only for the unconed fill term below.
        float scatterAtten = 1.0 / (1.0 + ld * ld * .12);
        float cone = spotLight(p, lp, aimDir, .8, .94);
        float dif = max(dot(n, L), 0.0);
        float spec = pow(max(dot(reflect(-L, n), -rd), 0.0), 20.0);
        vec3 lc = vec3(1.0, .82, .55) * cone * dif * 17.0;
        float scatter = scatterAtten * (mat == M_SNOW ? 0.5 : 0.85);
        col3 += albedo * (lc + vec3(1.0, .8, .55) * scatter) + spec * cone * 4.5;
      }
    } else {
      // screen-right corresponds to world -X for this camera handedness, so flip the x mapping
      // here or the stencilled text reads backwards on screen.
      vec2 su = vec2(((BUNKER_C.x - 1.5 + 1.6) - p.x) / 3.2, (p.y - (BUNKER_C.y + 0.5 - 1.1)) / 2.2);
      vec4 tex = texture(iTex0, clamp(su, 0.0, 1.0));
      vec3 wallLit = albedo * amb;
      for (int li = 0; li < 2; li++){
        vec3 lp = li == 0 ? lightL : lightR;
        vec3 L = lp - p; float ld = length(L); L /= ld;
        float cone = spotLight(p, lp, aimDir, .8, .94);
        float dif = max(dot(n, L), 0.0);
        wallLit += albedo * vec3(1.0, .82, .55) * cone * dif * 13.0;
      }
      col3 = mix(wallLit, tex.rgb * (amb.g * 3.0 + 0.3), tex.a * 0.85);
    }
    if (mat == V_LAMP) col3 = vec3(1.0, .86, .55) * 6.0;
    if (mat == B_BEACON) col3 = albedo;
    col = col3;
  } else {
    col = skyCol;
  }

  // distant/near headlights: two distinct points + light-bar smear (mirrors s02_ice)
  {
    vec3 toL = lightL - ro, toR = lightR - ro;
    float dL = length(toL), dR = length(toR);
    float aL = dot(rd, toL / dL), aR = dot(rd, toR / dR);
    float ptL = smoothstep(0.9992, 1.0, aL);
    float ptR = smoothstep(0.9992, 1.0, aR);
    float haloL = smoothstep(0.9985, 0.9992, aL) * 0.22;
    float haloR = smoothstep(0.9985, 0.9992, aR) * 0.22;
    col += vec3(1.0, .8, .5) * ((ptL + ptR) * 2.4 + haloL + haloR);
  }

  // volumetric headlight shafts — tightly gated, only near the actual beam direction
  vec3 beamCenter = mix(lightL, lightR, .5) + vec3(0., 0., 8.);
  vec3 toBeam = beamCenter - ro; float distBeam = length(toBeam);
  if (distBeam < 40.0 && dot(rd, toBeam / max(distBeam, .001)) > 0.85){
    vec3 shaft = vec3(0.);
    float maxD = min(dist, 26.0);
    const int NS = 2;
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
        shaft += vec3(1.0, .8, .5) * cone * ph * dens * stepL * 0.05;
      }
    }
    col += shaft;
  }
  if (beacon > 0.01){
    vec3 bp = MAST_BASE + vec3(0., MAST_H, 0.);
    float ang = dot(rd, normalize(bp - ro));
    col += vec3(1.0, .08, .04) * beacon * smoothstep(.995, 1.0, ang) * 1.5;
  }

  // ground drift: streaming low band, gated to real hits so the sky never gets a fog wash
  if (anyHit){
    vec3 samp = ro + rd * min(dist, 22.0);
    float heightW = smoothstep(2.2, -0.15, samp.y);
    vec2 w = vec2(dot(samp.xz, WIND), dot(samp.xz, vec2(-WIND.y, WIND.x)));
    vec2 streamUV = vec2(w.x * 0.3 - t * WSPD * 3.0, w.y * 1.6);
    float n = fbm2(streamUV);
    float drift = heightW * (0.26 + 0.5 * n) * (0.5 + gust * 0.8);
    float distW = 1.0 - exp(-min(dist, 22.0) * 0.04);
    col = mix(col, vec3(.045, .055, .07), clamp(drift * distW, 0., 0.4));
  }

  float fogAmt = 1.0 - exp(-dist * 0.06 * (0.6 + gust * 0.5));
  vec3 fogCol = mix(vec3(.008, .011, .017), vec3(.018, .022, .03), skyTexture(normalize(vec3(rd.x, 0.05, rd.z)), t) * 0.5 + 0.25);
  col = mix(col, fogCol, clamp(fogAmt, 0., 0.94));

  float towardLight = smoothstep(.4, .95, max(dot(normalize(beamCenter - ro), rd), 0.0));
  vec2 streaks = snowStreaks(uv2, t, gust);
  col += streaks.y * mix(vec3(.16, .18, .24), vec3(1.0, .85, .6), towardLight * 0.85) * 0.55;

  return col;
}
