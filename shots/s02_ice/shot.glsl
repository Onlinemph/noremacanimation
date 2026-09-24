// s02_ice — polar plateau blizzard, aurora, an approaching Sno-Cat.
// Materials (local ids, avoid clashing with M_* from common):
#define V_BODY   20.0
#define V_TRACK  21.0
#define V_LAMP   22.0
#define V_GLASS  23.0
#define V_CHROME 24.0

const vec2 WIND = vec2(0.92, 0.39);          // wind direction (xz), roughly normalized
const float WSPD = 1.6;

// ---------------------------------------------------------------- terrain ---
// Cheap-ish height field: rolling plateau + wind-aligned sastrugi ridges.
float terrainH(vec2 p){
  float base = (noise2(p * 0.012) * 2.0 - 1.0) * 0.5;
  vec2 w = vec2(dot(p, WIND), dot(p, vec2(-WIND.y, WIND.x)));
  // sastrugi: long ridges running along the wind, spaced several metres apart across it
  float n1 = noise2(vec2(w.x * 0.025, w.y * 0.16) + base * 0.8);
  float ridge = pow(1.0 - abs(2.0 * n1 - 1.0), 2.4) * 0.34;
  float n2 = noise2(vec2(w.x * 0.05, w.y * 0.34) + base * 1.3 + 11.0);
  ridge += pow(1.0 - abs(2.0 * n2 - 1.0), 3.0) * 0.14;
  float fine = (noise2(p * 1.1 + base) - 0.5) * 0.02;
  return base * 0.25 + ridge + fine;
}

// Bounded linear march + binary refine for the height field (true SDF marching
// is unstable for heightfields at grazing angles, so we do this explicitly).
const float TERR_RANGE = 26.0;
const float TERR_STEP = 0.65;
bool terrainHit(vec3 ro, vec3 rd, out float dist){
  // camera keeps ~0.55m clearance over local terrain; terrain height is bounded, so a ray
  // pointing clearly upward can never cross it within TERR_RANGE — skip the march entirely.
  if (rd.y > 0.02) { dist = TERR_RANGE; return false; }
  float prevY = ro.y - terrainH(ro.xz);
  float prevD = 0.0;
  for (int i = 1; i <= 40; i++){
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

// ---------------------------------------------------------------- vehicle ---
// Local frame: nose at +z, up +y, origin at ground contact. Roughly 4.6m long.
// Trimmed to the primitives that actually read at speed/distance: hull+cab merged into one
// pass (mirrored track on both sides via abs(x)), no separate windshield/exhaust — keeps the
// per-step primitive count down since this is evaluated at full detail for every near pixel.
vec2 sdSnoCat(vec3 p){
  vec2 r = vec2(1e5, V_BODY);
  float hull = sdRoundBox(p - vec3(0., .78, .0), vec3(1.05, .5, 2.05), .18);
  vec3 cq = p - vec3(0., 1.62, .35);
  float cab = sdRoundBox(cq, vec3(.9, .46, 1.1), .12);
  r = opU(r, vec2(smin(hull, cab, .12), V_BODY));
  r = opU(r, vec2(sdRoundBox(p - vec3(0., .95, 1.75), vec3(.85, .28, .35), .1), V_BODY));
  vec3 tp = vec3(abs(p.x) - 1.18, p.y - .42, p.z);
  r = opU(r, vec2(sdRoundBox(tp, vec3(.26, .42, 2.15), .2), V_TRACK));
  r = opU(r, vec2(sdRoundBox(p - vec3(0., 2.02, .55), vec3(.55, .06, .08), .03), V_CHROME));
  vec3 lp = vec3(abs(p.x) - .62, p.y - .92, p.z - 2.02);
  r = opU(r, vec2(sdSphere(lp, .1), V_LAMP));
  return r;
}

// world-space vehicle placement: travels toward camera along -Z at fixed lane offset, passing left.
vec3 vehiclePos(float t){
  float vz = 96.0 - 9.6 * t;
  return vec3(-4.3, 0., vz);
}
const float VHEAD = PI; // facing -Z (nose toward camera)

// vp: precomputed world position of the vehicle's ground-contact point for this frame
// (computed once in render(), sunk to local terrain height — avoids re-evaluating
// terrainH inside the march loop).
vec2 mapVehicle(vec3 p, vec3 vp){
  vec3 q = p - vp;
  q.xz *= rot2(VHEAD);
  float bound = sdBox(q - vec3(0., .9, 0.), vec3(1.3, 1.2, 2.3));
  if (bound > .35) return vec2(bound + .3, V_BODY);
  return sdSnoCat(q);
}
bool vehicleHit(vec3 ro, vec3 rd, vec3 vp, out float dist, out float mat){
  float d = 0.3;
  for (int i = 0; i < 64; i++){
    vec3 p = ro + rd * d;
    vec2 h = mapVehicle(p, vp);
    if (h.x < .003) { dist = d; mat = h.y; return true; }
    d += h.x;
    if (d > 140.0) break;
  }
  dist = 1e5; mat = 0.; return false;
}
vec3 vehicleNrm(vec3 p, vec3 vp){
  vec2 e = vec2(.01, 0.);
  return normalize(vec3(
    mapVehicle(p + e.xyy, vp).x - mapVehicle(p - e.xyy, vp).x,
    mapVehicle(p + e.yxy, vp).x - mapVehicle(p - e.yxy, vp).x,
    mapVehicle(p + e.yyx, vp).x - mapVehicle(p - e.yyx, vp).x));
}
vec3 terrainNrm(vec3 p){
  vec2 e = vec2(.03, 0.);
  float hL = terrainH(p.xz - e.xy), hR = terrainH(p.xz + e.xy);
  float hD = terrainH(p.xz - e.yx), hU = terrainH(p.xz + e.yx);
  return normalize(vec3(hL - hR, 2.0 * e.x, hD - hU));
}

// -------------------------------------------------------------- snow fx -----
float gustEnv(float t){
  float g = exp(-pow((t - 2.2) / 0.9, 2.0)) + exp(-pow((t - 6.0) / 1.0, 2.0)) + exp(-pow((t - 9.7) / 0.8, 2.0));
  return clamp(g, 0.0, 1.6);
}
// screen-space snowflake streaks: sparse, small, layered, elongated slightly along wind
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
    if (hh.x > 0.14) continue;                       // sparse: ~14% of cells carry a flake
    vec2 fa = vec2(f.x / elong, f.y);
    float dd = length(fa);
    float flake = smoothstep(0.22, 0.02, dd);
    s += flake * (0.5 + 0.5 * hh.y) * (1.0 - fi * 0.2);
  }
  return clamp(s * (0.5 + gust * 0.6), 0.0, 1.0);
}

// ------------------------------------------------------------------ shade ---
vec3 vehicleAlbedo(float m, vec3 p){
  if (m == V_TRACK)  return vec3(.045, .043, .04) * (0.7 + 0.4 * noise3(p * 40.));
  if (m == V_GLASS)  return vec3(.02, .03, .035);
  if (m == V_CHROME) return vec3(.25, .25, .27);
  float grime = smoothstep(.35, .8, fbm3lo(p * 3.5 + 4.));
  float frost = smoothstep(.5, .9, fbm3lo(p * 6.0 - 2.));
  vec3 red = mix(vec3(.62, .09, .05), vec3(.22, .03, .02), grime);
  return mix(red, vec3(.55, .58, .6), frost * .5);
}

vec3 render(vec2 fc){
  float t = iTime;
  vec2 uv2 = screenUV(fc);

  // camera: low, near sastrugi, slow pan to track the vehicle as it passes
  vec3 camPos0 = vec3(0.15, 0.95, -1.4);
  vec3 vp = vehiclePos(t);
  vp.y = terrainH(vp.xz) + 0.03; // sink the vehicle onto the local snow surface
  float bob = sin(t * 1.7) * .008;
  vec3 ro = camPos0 + vec3(0., bob, 0.);
  ro.y = max(ro.y, terrainH(ro.xz) + 0.55);
  float followT = smoothstep(6.8, 11.2, t);
  vec3 farTa = vec3(-0.6, 0.15, 9.0);
  vec3 nearTa = vp + vec3(0., .8, -1.0);
  vec3 ta = mix(farTa, nearTa, followT);
  float shakeN = (noise2(vec2(t * 3.1, 5.)) - .5) * .02;
  vec3 rd = camRay(fc, ro, ta + vec3(shakeN, 0., 0.), 1.35, 0.015 * sin(t * .6));

  // headlight positions (rotate local offsets by vehicle heading)
  vec2 offL = vec2(-.62, 2.02) * mat2(cos(VHEAD), -sin(VHEAD), sin(VHEAD), cos(VHEAD));
  vec2 offR = vec2(.62, 2.02) * mat2(cos(VHEAD), -sin(VHEAD), sin(VHEAD), cos(VHEAD));
  vec3 lightL = vp + vec3(offL.x, .92, offL.y);
  vec3 lightR = vp + vec3(offR.x, .92, offR.y);
  vec2 offF = vec2(0., 2.3) * mat2(cos(VHEAD), -sin(VHEAD), sin(VHEAD), cos(VHEAD));
  vec3 aimDir = normalize(vec3(offF.x, -.05, offF.y));

  // intersect terrain and vehicle separately, take the nearer
  float tDist; bool tHit = terrainHit(ro, rd, tDist);
  float vDist, vMat; bool vHit = vehicleHit(ro, rd, vp, vDist, vMat);
  bool hitTerrain = tHit && (!vHit || tDist <= vDist);
  bool hitVehicle = vHit && (!tHit || vDist < tDist);
  float dist = hitVehicle ? vDist : (hitTerrain ? tDist : TERR_RANGE);

  vec3 upDir = normalize(vec3(0.05, 1.0, 0.02));
  vec3 skyCol = vec3(.003, .006, .014) + vec3(.006, .01, .02) * max(0., rd.y);
  skyCol += stars(rd) * vec3(.8, .85, 1.0) * smoothstep(-.05, .3, rd.y);
  skyCol += aurora(rd, t) * 1.3;
  skyCol += vec3(.02, .03, .05) * exp(-max(rd.y, 0.0) * 6.0);

  vec3 col;
  float gust = gustEnv(t);

  if (hitVehicle || hitTerrain){
    vec3 p = ro + rd * dist;
    vec3 n = hitVehicle ? vehicleNrm(p, vp) : terrainNrm(p);
    float mat = hitVehicle ? vMat : M_SNOW;
    vec3 albedo = (mat == M_SNOW) ? mix(vec3(.55, .62, .78), vec3(.85, .89, .98), smoothstep(-.1, .35, n.y)) * (0.82 + 0.3 * fbm3lo(p * 5.0))
                                    : vehicleAlbedo(mat, p);
    vec3 amb = (aurora(upDir, t) * 3.2 + vec3(.028, .034, .06)) * (0.55 + 0.45 * max(n.y, 0.0)) * (mat == M_SNOW ? 1.0 : .5);
    vec3 col3 = albedo * amb;

    for (int li = 0; li < 2; li++){
      vec3 lp = li == 0 ? lightL : lightR;
      vec3 L = lp - p; float ld = length(L); L /= ld;
      float atten = 1.0 / (1.0 + ld * ld * .035);
      float cone = spotLight(p, lp, aimDir, .78, .93);
      float dif = max(dot(n, L), 0.0);
      float spec = pow(max(dot(reflect(-L, n), -rd), 0.0), 24.0);
      vec3 lc = vec3(1.0, .82, .55) * cone * dif * atten * 3.2;
      // soft omnidirectional scatter: blowing snow throws headlight glow past the beam edge
      float scatter = dif * atten * 0.4;
      col3 += albedo * (lc + vec3(1.0, .8, .55) * scatter) + spec * cone * atten * 1.4;
    }
    if (mat == V_LAMP) col3 = vec3(1.0, .86, .55) * 6.0;
    col = col3;
  } else {
    col = skyCol;
    // distant vehicle headlight glow before geometry resolves (small, soft disk)
    float aL = dot(rd, normalize(lightL - ro));
    float aR = dot(rd, normalize(lightR - ro));
    float glL = smoothstep(0.9985, 0.99995, aL);
    float glR = smoothstep(0.9985, 0.99995, aR);
    float haloL = smoothstep(0.996, 0.9995, aL) * 0.3;
    float haloR = smoothstep(0.996, 0.9995, aR) * 0.3;
    float distFactor = clamp(1.0 - length(vp - ro) / 140.0, .1, 1.0);
    col += vec3(1.0, .82, .55) * min((glL + glR) * 2.2 + haloL + haloR, 2.4) * (0.4 + distFactor * 0.8);
  }

  // volumetric headlight shafts through the blizzard (few-sample fake).
  // Gate by a cheap angle/distance test first: this loop is the single most expensive
  // part of the shader, and only matters for pixels actually looking toward the beams.
  vec3 toVeh = vp - ro; float distVeh = length(toVeh);
  bool nearBeam = distVeh < 50.0 && dot(rd, toVeh / max(distVeh, 0.001)) > 0.5;
  if (nearBeam) {
    vec3 shaft = vec3(0.);
    float maxD = min(dist, 34.0);
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
        dens *= (1.0 + gust * 1.2);
        shaft += vec3(1.0, .8, .5) * cone * ph * dens * stepL * 0.09;
      }
    }
    col += shaft;
  }

  // ground drift: height-weighted animated fog, denser near surface, gustier
  {
    vec3 samp = ro + rd * min(dist, 22.0);
    float heightW = exp(-max(samp.y, 0.0) * 1.8);
    float n = fbm2(samp.xz * 0.12 + t * WIND * WSPD * 0.6);
    float drift = heightW * (0.3 + 0.55 * n) * (0.55 + gust * 0.8);
    float distW = 1.0 - exp(-min(dist, 22.0) * 0.045);
    col = mix(col, vec3(.045, .055, .07), clamp(drift * distW, 0., 0.7));
  }

  // general atmospheric fog (distance)
  float fogAmt = 1.0 - exp(-dist * 0.012 * (0.6 + gust * 0.5));
  vec3 fogCol = vec3(.01, .014, .026);
  col = mix(col, fogCol, clamp(fogAmt, 0., 0.9));

  // screen-space snow streaks, brighter when roughly toward the headlights
  float towardLight = smoothstep(.4, .95, max(dot(normalize(vp - ro), rd), 0.0));
  float streaks = snowStreaks(uv2, t, gust);
  col += streaks * mix(vec3(.22, .24, .3), vec3(1.0, .85, .6), towardLight * 0.8) * 0.4;

  return col;
}
