// s02_ice — polar plateau blizzard, aurora, an approaching Sno-Cat.
// Materials (local ids, avoid clashing with M_* from common):
#define V_BODY   20.0
#define V_TRACK  21.0
#define V_LAMP   22.0
#define V_GLASS  23.0
#define V_CHROME 24.0

const vec2 WIND = vec2(0.92, 0.39);          // wind direction (xz), roughly normalized
const float WSPD = 1.6;
// screen-space wind direction: blizzard blows mostly SIDEWAYS across frame, slight downward bias
const vec2 SWIND = normalize(vec2(1.0, -0.22));

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
  // Beyond the detailed march range the exact ridge shape no longer matters (fog hides it) —
  // fall back to an analytic flat-plane intersection so "ground" keeps going to the horizon
  // instead of hard-cutting to sky right where the detailed search gives up.
  if (rd.y < -0.0008){
    float planeD = -ro.y / rd.y;
    if (planeD > TERR_RANGE) { dist = min(planeD, 150.0); return true; }
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
  // light bar spanning the roof, plus two round headlight housings set apart near the corners
  r = opU(r, vec2(sdRoundBox(p - vec3(0., 2.04, .58), vec3(.62, .07, .09), .03), V_CHROME));
  vec3 lp = vec3(abs(p.x) - .8, p.y - .92, p.z - 2.02);
  r = opU(r, vec2(sdSphere(lp, .12), V_LAMP));
  return r;
}
// vehicle-local coordinates of a world point (used for shading features tied to the body).
vec3 vehLocal(vec3 p, vec3 vp){ vec3 q = p - vp; q.xz *= rot2(PI); return q; }

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
// Screen-space wind-blown snow: several depth layers with parallax (far = small/dim/slow,
// near = large/bright/fast with a long motion streak along SWIND). Returns (coverage, brightness).
// Most flakes are faint; only the nearest layer gets any real brightness.
vec2 snowStreaks(vec2 uv, float t, float gust){
  float s = 0.0, br = 0.0;
  vec2 dir = SWIND;
  vec2 perp = vec2(-dir.y, dir.x);
  const int NL = 4;
  for (int i = 0; i < NL; i++){
    float fi = float(i) / float(NL - 1);           // 0 = farthest, 1 = nearest
    float scale = mix(85.0, 16.0, fi);              // far: tiny dense cells; near: big sparse cells
    float speed = mix(0.5, 2.6, fi) * (1.0 + gust * 0.7);
    float elong = mix(1.3, 6.0, fi);                // near flakes smear into long streaks
    float density = mix(0.22, 0.045, fi);           // near layer is sparser (bigger, fewer flakes)
    vec2 st = uv + vec2(fi * 7.1, fi * 2.9);
    vec2 q = vec2(dot(st, dir), dot(st, perp)) * scale;
    q.x -= t * speed * scale * 0.09;                // motion mostly along-wind (screen x-ish)
    vec2 id = floor(q);
    vec2 f = fract(q) - .5;
    vec2 hh = hash22(id + fi * 23.7 + 5.0);
    if (hh.x > density) continue;
    vec2 fa = vec2(f.x / elong, f.y);
    float dd = length(fa);
    float soft = mix(0.28, 0.06, fi);               // far flakes are soft/blurred, near ones crisper
    float flake = smoothstep(soft, 0.0, dd);
    float layerBr = mix(0.07, 0.75, fi * fi * fi) * (0.35 + 0.65 * hh.y);
    s += flake;
    br += flake * layerBr;
  }
  return vec2(clamp(s, 0.0, 1.0), br);
}
// low-frequency spindrift texture over the sky dome so it isn't a flat card
float skyTexture(vec3 dir, float t){
  vec2 pp = dir.xz / max(dir.y, 0.05);
  return fbm2(pp * 0.5 + WIND * t * 0.03);
}

// ------------------------------------------------------------------ shade ---
// pl = vehicle-LOCAL coordinates of the hit point (see vehLocal) — used so grime/tread/window
// features stay locked to the body instead of sliding as the vehicle drives through world space.
vec3 vehicleAlbedo(float m, vec3 p, vec3 pl){
  if (m == V_TRACK){
    float tread = smoothstep(.42, .48, abs(fract(pl.z * 2.6) - .5));
    return vec3(.05, .048, .045) * (0.55 + 0.35 * tread) * (0.7 + 0.4 * noise3(p * 40.));
  }
  if (m == V_GLASS)  return vec3(.02, .03, .035);
  if (m == V_CHROME) return vec3(.22, .22, .24);
  float grime = smoothstep(.35, .8, fbm3lo(p * 3.5 + 4.));
  float frost = smoothstep(.5, .9, fbm3lo(p * 6.0 - 2.));
  vec3 red = mix(vec3(.62, .09, .05), vec3(.22, .03, .02), grime);
  return mix(red, vec3(.55, .58, .6), frost * .5);
}
// faint warm cab-window glow (frosted glass, backlit by nothing but sells "cab" silhouette)
float vehWindowGlow(vec3 pl){
  vec3 cq = pl - vec3(0., 1.62, .35);
  float onFace = smoothstep(.14, .02, abs(cq.z - 1.1)) * smoothstep(.42, .2, abs(cq.x)) * smoothstep(.4, .1, abs(cq.y - .05));
  return onFace;
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

  // headlight positions (rotate local offsets by vehicle heading) — set wide, matching the light bar
  vec2 offL = vec2(-.8, 2.02) * mat2(cos(VHEAD), -sin(VHEAD), sin(VHEAD), cos(VHEAD));
  vec2 offR = vec2(.8, 2.02) * mat2(cos(VHEAD), -sin(VHEAD), sin(VHEAD), cos(VHEAD));
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

  // sky: dark blue-grey (not saturated navy), broken up by a slow-drifting spindrift texture,
  // aurora kept faint so it reads as a curtain glimpsed through haze rather than a poster.
  vec3 upDir = normalize(vec3(0.05, 1.0, 0.02));
  float skyTex = skyTexture(rd, t);
  vec3 skyBase = mix(vec3(.006, .008, .012), vec3(.014, .017, .024), smoothstep(.3, .8, skyTex));
  vec3 skyCol = skyBase * mix(0.7, 1.15, max(0., rd.y));
  skyCol += stars(rd) * vec3(.75, .8, .95) * smoothstep(-.05, .3, rd.y) * smoothstep(.7, .3, skyTex);
  skyCol += aurora(rd, t) * (0.55 + 0.3 * skyTex);

  vec3 col;
  float gust = gustEnv(t);

  if (hitVehicle || hitTerrain){
    vec3 p = ro + rd * dist;
    vec3 n = hitVehicle ? vehicleNrm(p, vp) : terrainNrm(p);
    float mat = hitVehicle ? vMat : M_SNOW;
    vec3 pl = hitVehicle ? vehLocal(p, vp) : vec3(0.);
    vec3 albedo = (mat == M_SNOW) ? mix(vec3(.42, .5, .68), vec3(.88, .91, .99), smoothstep(-.15, .4, n.y)) * (0.68 + 0.55 * fbm3lo(p * 6.0))
                                    : vehicleAlbedo(mat, p, pl);
    float sparkle = (mat == M_SNOW) ? pow(hash31(floor(p * 40.0)), 22.0) * 6.0 : 0.0;
    // sky-bounce ambient: kept subtle and NOT keyed to the full straight-up aurora sample
    // (which stays bright even when the view-direction aurora near the horizon has faded
    // to zero) — otherwise the ground reads brighter than the sky right at the skyline.
    vec3 amb = (aurora(upDir, t) * 0.45 + vec3(.016, .02, .036)) * (0.55 + 0.45 * max(n.y, 0.0)) * (mat == M_SNOW ? 1.0 : .6);
    // cold rim/fresnel light from the open sky — keeps silhouettes from going pure flat black
    float fres = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    vec3 rim = vec3(.1, .13, .19) * fres * (mat == M_SNOW ? 0.3 : 1.8);
    vec3 col3 = albedo * amb + rim;

    for (int li = 0; li < 2; li++){
      vec3 lp = li == 0 ? lightL : lightR;
      vec3 L = lp - p; float ld = length(L); L /= ld;
      float atten = 1.0 / (1.0 + ld * ld * .03);
      float cone = spotLight(p, lp, aimDir, .78, .93);
      float dif = max(dot(n, L), 0.0);
      float spec = pow(max(dot(reflect(-L, n), -rd), 0.0), 24.0);
      vec3 lc = vec3(1.0, .82, .55) * cone * dif * atten * 3.6;
      // soft omnidirectional scatter: blowing snow throws headlight glow past the beam edge,
      // and lets the vehicle's OWN lights read on its own body even outside the strict cone.
      // Falls off much faster than the coned beam so it stays local to the vehicle instead of
      // washing the whole far ground plane it's driving across.
      float scatterAtten = 1.0 / (1.0 + ld * ld * .25);
      float scatter = scatterAtten * (mat == M_SNOW ? 0.55 : 0.9);
      col3 += albedo * (lc + vec3(1.0, .8, .55) * scatter) + spec * cone * atten * 1.4;
      col3 += sparkle * cone * atten * vec3(1.0, .92, .8);
    }
    if (mat == V_LAMP) col3 = vec3(1.0, .86, .55) * 6.0;
    if (hitVehicle) col3 += vec3(1.0, .55, .22) * vehWindowGlow(pl) * 0.22;
    col = col3;
  } else {
    col = skyCol;
  }

  // distant/approaching headlights: two DISTINCT points (not one merged disc) plus a soft
  // shared halo and a light-bar smear between them, visible well before the geometry resolves.
  {
    vec3 toL = lightL - ro, toR = lightR - ro;
    float dL = length(toL), dR = length(toR);
    float aL = dot(rd, toL / dL), aR = dot(rd, toR / dR);
    float angScale = clamp(mix(0.99998, 0.9990, clamp(dL / 60.0, 0., 1.)), 0.9990, 0.99998);
    float ptL = smoothstep(angScale, 1.0, aL);
    float ptR = smoothstep(angScale, 1.0, aR);
    float haloL = smoothstep(angScale - 0.0009, angScale, aL) * 0.22;
    float haloR = smoothstep(angScale - 0.0009, angScale, aR) * 0.22;
    vec3 barDir = normalize(lightR - lightL);
    vec3 toBar = ro + rd * dot(lightL - ro, rd) - lightL;
    float alongBar = clamp(dot(toBar, barDir) / length(lightR - lightL), 0.0, 1.0);
    vec3 nearestBar = lightL + barDir * alongBar * length(lightR - lightL);
    float barAng = dot(rd, normalize(nearestBar - ro));
    float bar = smoothstep(0.9985, 0.9999, barAng) * 0.35;
    float distFactor = clamp(1.0 - dL / 130.0, .12, 1.0);
    col += vec3(1.0, .8, .5) * ((ptL + ptR) * 2.6 + haloL + haloR + bar) * (0.35 + distFactor * 0.75);
  }

  // volumetric headlight shafts through the blizzard (few-sample fake).
  // Gate by a cheap angle/distance test first: this loop is the single most expensive
  // part of the shader, and only matters for pixels actually looking toward the beams.
  vec3 toVeh = vp - ro; float distVeh = length(toVeh);
  bool nearBeam = distVeh < 90.0 && dot(rd, toVeh / max(distVeh, 0.001)) > 0.8;
  if (nearBeam) {
    vec3 shaft = vec3(0.);
    float maxD = min(dist, 30.0);
    const int NS = 6;
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
        shaft += vec3(1.0, .8, .5) * cone * ph * dens * stepL * 0.05;
      }
    }
    col += shaft;
  }

  // ground drift: streaming low band of blowing snow, textured & animated along the wind so it
  // reads as motion across the surface rather than a flat fog blend. Only meaningful where we
  // actually hit ground/vehicle near the surface — gating on that keeps the sky from getting an
  // arbitrary fog wash that would otherwise cut a hard line right at the horizon.
  if (hitTerrain || hitVehicle){
    vec3 samp = ro + rd * min(dist, 22.0);
    float heightW = smoothstep(2.2, -0.15, samp.y);
    vec2 w = vec2(dot(samp.xz, WIND), dot(samp.xz, vec2(-WIND.y, WIND.x)));
    vec2 streamUV = vec2(w.x * 0.3 - t * WSPD * 3.0, w.y * 1.6);  // compressed along-wind = streaky
    float n = fbm2(streamUV);
    float drift = heightW * (0.28 + 0.55 * n) * (0.55 + gust * 0.8);
    float distW = 1.0 - exp(-min(dist, 22.0) * 0.04);
    col = mix(col, vec3(.05, .06, .08), clamp(drift * distW, 0., 0.4));
  }

  // general atmospheric fog — same dark blue-grey as the sky base, so the horizon dissolves
  // into the blizzard instead of cutting hard against it.
  float fogAmt = 1.0 - exp(-dist * 0.07 * (0.6 + gust * 0.5));
  vec3 fogCol = mix(vec3(.008, .011, .017), vec3(.02, .024, .032), skyTexture(normalize(vec3(rd.x, 0.05, rd.z)), t) * 0.5 + 0.25);
  col = mix(col, fogCol, clamp(fogAmt, 0., 0.94));

  // snow spray kicked up around the tracks as the Sno-Cat passes close
  {
    float passWindow = smoothstep(7.0, 8.6, t) * smoothstep(11.8, 10.2, t);
    if (passWindow > 0.001){
      vec3 toV = vp - ro;
      float ang = dot(rd, normalize(toV));
      float sprayMask = smoothstep(0.965, 0.995, ang) * passWindow;
      float n = fbm2(uv2 * 6.0 + t * vec2(3.0, 0.5));
      col += vec3(.5, .5, .55) * sprayMask * n * 0.5;
    }
  }

  // screen-space wind-blown snow: layered, streaked, brighter when roughly toward the headlights
  float towardLight = smoothstep(.4, .95, max(dot(normalize(vp - ro), rd), 0.0));
  vec2 streaks = snowStreaks(uv2, t, gust);
  col += streaks.y * mix(vec3(.16, .18, .24), vec3(1.0, .85, .6), towardLight * 0.85) * 0.6;

  return col;
}
