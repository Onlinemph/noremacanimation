// s06_armory — the armory. KS-23 under a swinging bulb, then weapon/character cards.
// Custom material ids (on top of shared M_* from common.glsl):
#define MI_FLOOR   20.0
#define MI_CEIL    21.0
#define MI_WALL    50.0
#define MI_LOCKERB 51.0
#define MI_CRATE   52.0
#define MI_BRASS   40.0
#define MI_HULL    41.0
#define MI_BULB    42.0
#define MI_CORD    43.0
#define MI_POSTER  44.0

// ---- room bounds (meters) ----
const float ROOM_L = -1.30, ROOM_R = 1.35, ROOM_BACK = 2.55, ROOM_CEIL = 2.3;
const vec3  TABLE_C = vec3(0.05, 0.0, 0.95);
const float TABLE_TOP = 0.80;

vec3 bulbPos(){
  float sw = sin(iTime * 0.85 + 1.1) * 0.22;         // slow pendulum swing
  vec3 anchor = vec3(0.05, ROOM_CEIL, 0.75);
  float len = 0.55;
  return anchor + vec3(sin(sw), -cos(sw), sin(sw)*0.15) * len;
}

// crate box: returns (dist, mat) with a lid seam
vec2 sdCrate(vec3 p, vec3 c, vec3 he){
  vec3 q = p - c;
  float box = sdRoundBox(q, he, 0.01);
  float lid = abs(q.y - he.y * 0.72) - 0.006; // lid seam line groove (thin, ignored as bump only)
  return vec2(box, MI_CRATE);
}

vec2 sdLocker(vec3 p, vec3 c, vec3 he, bool bloody){
  float box = sdRoundBox(p - c, he, 0.015);
  // vent louvers cut lightly near top (visual only via small notches, cheap: skip geometry, keep box)
  return vec2(box, bloody ? MI_LOCKERB : M_STEEL);
}

vec2 map(vec3 p){
  vec2 r = vec2(1e5, 0.0);

  // floor / ceiling
  r = opU(r, vec2(p.y - 0.0, MI_FLOOR));
  r = opU(r, vec2(ROOM_CEIL - p.y, MI_CEIL));
  // back wall
  r = opU(r, vec2(ROOM_BACK - p.z, MI_WALL));
  // side walls
  r = opU(r, vec2(p.x - ROOM_L, M_STEEL));   // left wall painted steel-ish concrete (locker bank backs onto it)
  r = opU(r, vec2(ROOM_R - p.x, M_CONCRETE));

  // ---- table ----
  vec3 tc = TABLE_C;
  vec2 top = vec2(sdRoundBox(p - (tc + vec3(0., TABLE_TOP - 0.04, 0.)), vec3(0.55, 0.04, 0.34), 0.01), M_WOOD);
  r = opU(r, top);
  for (int i = 0; i < 4; i++){
    float sx = i < 2 ? -1. : 1.;
    float sz = mod(float(i), 2.) < .5 ? -1. : 1.;
    vec3 lc = tc + vec3(sx * 0.48, (TABLE_TOP - 0.08) * 0.5, sz * 0.28);
    r = opU(r, vec2(sdCylY(p - lc, 0.028, (TABLE_TOP - 0.08) * 0.5), M_WOOD));
  }

  // ---- KS-23 on the table ----
  vec3 gp = p - (tc + vec3(0.02, TABLE_TOP + 0.05, -0.02));
  gp = rotY(gp, PI * 0.5 + 0.12);
  gp = rotZ(gp, 0.035);
  r = opU(r, sdKS23(gp, clamp(uP[0], 0., 1.)));

  // ---- 23mm shells standing on the table ----
  for (int i = 0; i < 5; i++){
    float fi = float(i);
    vec3 sc = tc + vec3(0.34 + fi * 0.075, TABLE_TOP, 0.15 - fi * 0.02);
    vec3 sp = p - sc;
    float h = 0.075;
    float body = sdCylY(sp - vec3(0., h * 0.5, 0.), 0.0125, h * 0.5);
    r = opU(r, vec2(body, sp.y < h * 0.62 ? MI_HULL : MI_BRASS));
  }

  // ---- lockers, left wall ----
  for (int i = 0; i < 3; i++){
    float fi = float(i);
    vec3 lc = vec3(ROOM_L + 0.07, 1.0, -0.55 + fi * 0.85);
    r = opU(r, sdLocker(p, lc, vec3(0.06, 0.95, 0.36), i == 1));
  }

  // ---- weapon rack + crates, right wall ----
  vec3 rackC = vec3(ROOM_R - 0.05, 1.35, 0.15);
  r = opU(r, vec2(sdRoundBox(p - rackC, vec3(0.03, 0.85, 0.55), 0.01), M_WOOD));
  // pegs + two leaning spare long-guns (silhouette only)
  for (int i = 0; i < 2; i++){
    float fi = float(i);
    vec3 base = vec3(ROOM_R - 0.10, 0.05, -0.15 + fi * 0.5);
    vec3 tip  = base + vec3(-0.22, 1.75, 0.05 - fi*0.1);
    r = opU(r, vec2(sdTaper(p, base, tip, 0.025, 0.018), M_GUNMETAL));
  }
  // crates stacked on floor
  r = opU(r, sdCrate(p, vec3(ROOM_R - 0.35, 0.19, 1.55), vec3(0.30, 0.19, 0.24)));
  r = opU(r, sdCrate(p, vec3(ROOM_R - 0.33, 0.19+0.40, 1.75), vec3(0.24, 0.16, 0.20)));
  r = opU(r, sdCrate(p, vec3(ROOM_R - 0.36, 0.19, 2.05), vec3(0.28, 0.19, 0.22)));

  // ---- bulb + cord ----
  vec3 anchor = vec3(0.05, ROOM_CEIL, 0.75);
  vec3 bp = bulbPos();
  r = opU(r, vec2(sdCapsule(p, anchor, bp - vec3(0.,0.05,0.), 0.004), MI_CORD));
  r = opU(r, vec2(sdSphere(p - bp, 0.035), MI_BULB));

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
  float res = 1.0, t = 0.06;
  for (int i = 0; i < 18; i++){
    float h = map(ro + rd * t).x;
    res = min(res, 8.0 * h / t);
    t += clamp(h, 0.03, 0.25);
    if (res < 0.03 || t > maxT) break;
  }
  return clamp(max(res, 0.16), 0.0, 1.0); // never fully black: bulb bounce/fill
}

vec3 wallAlbedo(vec3 p){
  float n = fbm3lo(p * 3.5);
  vec3 base = mix(vec3(.60,.58,.52), vec3(.42,.41,.37), n);          // dirty cream plaster
  base *= 0.8 + 0.4 * fbm3lo(p * 12.0);                              // grime speckle
  vec2 uv = vec2(1.0 - (p.x - ROOM_L) / (ROOM_R - ROOM_L), p.y / ROOM_CEIL);
  vec4 tex = texture(iTex0, uv);
  base = mix(base, tex.rgb, tex.a);
  return base;
}
vec3 floorAlbedo(vec3 p){
  float n = fbm3lo(p * 4.0);
  float crack = smoothstep(.5,.52, fbm3lo(p*20.));
  vec3 base = mix(vec3(.10,.10,.11), vec3(.16,.155,.14), n);
  base = mix(base, vec3(.03), crack*0.6);
  float frost = smoothstep(.55,.75, fbm3lo(p*7.+vec3(0,10,0)));
  base = mix(base, vec3(.5,.55,.6), frost*0.15);
  return base;
}
vec3 steelAlbedo(vec3 p, bool bloody){
  vec3 base = vec3(.16,.20,.17) * (0.75 + 0.4*fbm3lo(p*8.));
  float seam = smoothstep(.02,.0, abs(mod(p.y+0.05,0.30)-0.15));
  base *= 1.0 - seam*0.25;
  if (bloody){
    vec2 uv = vec2((p.z + 1.0), p.y * 1.1);
    float hand = bloodSplat(uv - vec2(0.55,0.9), 4.2);
    base = mix(base, vec3(.18,.02,.02), hand*0.85);
  }
  base *= 0.85 + 0.3*noise3(p*40.);
  return base;
}
vec3 crateAlbedo(vec3 p, vec3 n){
  vec3 an = abs(n) + 1e-4;
  vec4 texXY = texture(iTex1, fract(p.xy*0.9));
  vec4 texXZ = texture(iTex1, fract(p.xz*0.9));
  vec4 texZY = texture(iTex1, fract(p.zy*0.9));
  vec4 tex = (texXY*an.z + texXZ*an.y + texZY*an.x) / (an.x+an.y+an.z);
  vec3 wood = mix(vec3(.30,.19,.10), vec3(.42,.28,.15), fbm3lo(p*10.));
  return mix(wood, tex.rgb, tex.a*0.9);
}

vec3 shade(vec2 h, vec3 p, vec3 n, vec3 rd){
  float m = h.y;
  vec3 albedo = vec3(.4);
  float rough = 0.6, emissive = 0.0;
  vec3 emitCol = vec3(0.);

  if (m == MI_FLOOR) albedo = floorAlbedo(p);
  else if (m == MI_CEIL) albedo = mix(vec3(.08),vec3(.12), fbm3lo(p*3.)) ;
  else if (m == MI_WALL) albedo = wallAlbedo(p);
  else if (m == M_STEEL) albedo = steelAlbedo(p, false);
  else if (m == MI_LOCKERB) albedo = steelAlbedo(p, true);
  else if (m == M_CONCRETE) albedo = vec3(.22,.21,.20) * (0.7+0.5*fbm3lo(p*4.));
  else if (m == M_WOOD) albedo = mix(vec3(.20,.12,.06), vec3(.32,.20,.10), fbm3lo(p*9.));
  else if (m == MI_CRATE) albedo = crateAlbedo(p, n);
  else if (m == MI_BRASS) { albedo = vec3(.55,.42,.18); rough = 0.25; }
  else if (m == MI_HULL)  { albedo = vec3(.42,.06,.04); rough = 0.45; }
  else if (m == M_GUNMETAL) { albedo = gunAlbedo(m, p); rough = 0.3; }
  else if (m == M_GORE) albedo = goreColor(p);
  else if (m == MI_CORD) { albedo = vec3(.02); rough = 0.8; }
  else if (m == MI_BULB) { emissive = 1.0; emitCol = vec3(1.0,.78,.45)*6.0; albedo = vec3(1.,.9,.7); }
  else albedo = gunAlbedo(m, p); // wood / gunmetal from sdKS23

  if (emissive > 0.0) return emitCol;

  vec3 bp = bulbPos();
  vec3 L = bp - p; float ld = length(L); L /= ld;
  float ndl = max(dot(n, L), 0.0);
  float atten = 1.0 / (1.0 + ld*ld*1.6);
  float sh = shadow(p + n*0.02, L, ld);
  vec3 lightCol = vec3(1.0, .84, .62) * 2.6;

  // cold ambient / flashlight-ish fill from camera side, keeps shadows readable
  vec3 fill = vec3(.09,.11,.15) * (0.7 + 0.5*max(dot(n, vec3(0.,0.3,-1.)),0.0));

  vec3 h2 = normalize(L - rd);
  float spec = pow(max(dot(n,h2),0.0), mix(80.0,16.0,rough)) * (1.0-rough);

  vec3 col = albedo * (ndl * atten * sh * lightCol + fill) + spec * lightCol * sh * 0.4;
  return col;
}

vec3 render(vec2 fc){
  vec3 ro, ta;
  float focal;
  float t = iTime;
  if (t < 6.0){
    float k = clamp(t/6.0, 0., 1.);
    float ke = smoothstep(0., 1., k);
    vec3 ro0 = vec3(-0.30, 1.18, -1.75), ta0 = vec3(0.10, 0.95, 1.05);
    float ang1 = mix(0.05, 0.40, k);
    float rad1 = 0.78;
    vec3 ro1 = TABLE_C + vec3(sin(ang1)*rad1, TABLE_TOP + 0.36, -cos(ang1)*rad1);
    vec3 ta1 = vec3(TABLE_C.x, TABLE_TOP + 0.02, TABLE_C.z);
    ro = mix(ro0, ro1, ke);
    ta = mix(ta0, ta1, ke);
    focal = mix(0.95, 2.35, ke);
  } else {
    ro = vec3(0.10, 1.30, -1.25);
    ta = vec3(0.05, 0.95, 0.85);
    focal = 1.55;
  }
  vec3 rd = camRay(fc, ro, ta, focal, 0.0);

  float d = 0.0; vec2 h;
  bool hitAny = false;
  for (int i = 0; i < 130; i++){
    vec3 p = ro + rd*d;
    h = map(p);
    if (h.x < 0.0015 * max(d,1.0)) { hitAny = true; break; }
    d += h.x * 0.85;
    if (d > 9.0) break;
  }

  vec3 col;
  if (!hitAny){
    col = vec3(.01,.012,.014);
  } else {
    vec3 p = ro + rd*d;
    vec3 n = nrm(p);
    col = shade(h, p, n, rd);
    // AO-ish darkening in tight corners via cheap step count proxy
    float ao = clamp(1.0 - float(130)/300.0, 0., 1.);
    col *= 1.0;
    // distance fog toward the back of the room
    float fog = 1.0 - exp(-d*d*0.02);
    col = mix(col, vec3(.02,.02,.025), fog*0.5);
  }

  // cheap volumetric light shaft from the bulb (few dithered samples along the view ray)
  vec3 bp = bulbPos();
  float dither = fract(sin(dot(fc, vec2(12.9898,78.233)))*43758.5453);
  vec3 vol = vec3(0.);
  const int VS = 10;
  for (int i = 0; i < VS; i++){
    float ft = (float(i) + dither) / float(VS);
    float sd = ft * min(d, 3.2);
    vec3 sp = ro + rd*sd;
    vec3 L = bp - sp; float ld = length(L);
    float sc = 1.0/(1.0+ld*ld*2.2);
    vol += sc;
  }
  vol *= vec3(1.0,.75,.42) * 0.010;
  col += vol;

  return col;
}
