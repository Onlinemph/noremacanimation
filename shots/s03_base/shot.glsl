// s03_base (10 s) — reveal of Object 9. Over the Sno-Cat's shoulder (3/4 rear, engine idling), the
// camera pushes in slowly. Its headlight cones reach across the drifts to a concrete bunker portal
// cut into a snow drift: a heavy steel blast door in a recessed frame, faded red star and stencilled
// ОБЪЕКТ 9. Long corrugated modules on stilts half-buried on the left, a dead sodium lamp post, fuel
// drums, and on the right a tall guyed lattice mast whose red beacon blinks, washing the snow red.
// Only light: headlights, the beacon, starlight/aurora.
//
// uP[0] = gust (0..1), uP[1] = beacon intensity (0..1, from shot.js so cues sync)
//
// NOTE: the Sno-Cat block between the SNOCAT markers is copied verbatim from s02_ice/shot.glsl.

// ============================================================ sky ===
const vec3 SKYAMB = vec3(.009, .013, .022);
vec3 skyCol(vec3 rd, float t, float gust){
  float y = max(rd.y, 0.);
  vec3 c = mix(vec3(.003, .004, .008), vec3(.001, .0012, .0028), smoothstep(0., .45, y));
  vec2 sp = rd.xz / (y + .08);
  float veil = fbm2(vec2(sp.x * .5 + t * .5, sp.y * .5 + t * .1) + 3.);
  float clear = smoothstep(.66, .3, veil) * (1. - .5 * gust);
  c += stars(rd) * vec3(.75, .85, 1.) * .8 * clear * smoothstep(.04, .2, y);
  // aurora curtain across the upper sky, veiled by high spindrift
  if (y > .01){
    vec2 ap = rd.xz / (y + .25);
    float w = ap.x * .45 + 1.3 * noise2(ap * .25 + vec2(t * .03, 0.)) + t * .02;
    float band = exp(-pow(ap.y - 1.9 - .6 * sin(w * 1.3), 2.) * 2.2);
    float rays = .45 + .55 * pow(noise2(vec2(w * 14., t * .35)), 1.5) + .25 * pow(noise2(vec2(w * 40., t * .5)), 3.);
    float hgt = smoothstep(.03, .2, y) * smoothstep(.8, .3, y);
    vec3 ac = mix(vec3(.05, .6, .3), vec3(.4, .12, .55), smoothstep(.18, .5, y));
    c += ac * band * rays * rays * hgt * .07 * (.4 + .6 * clear);
  }
  c += vec3(.011, .015, .025) * exp(-y * 10.) * (1. + .5 * gust) * (.75 + .5 * veil);
  return c;
}

// ============================================================ beacon ===
const vec3 MAST = vec3(8.5, 0., 82.);
const float MAST_H = 23.;
const vec3 BCOL = vec3(1., .045, .015);
vec3 gB0, gB1; float gBI;
vec3 beaconAt(vec3 p, vec3 n){
  vec3 d0 = gB0 - p, d1 = gB1 - p;
  float q0 = dot(d0, d0), q1 = dot(d1, d1);
  float l0 = dot(n, n) > .5 ? max(dot(n, d0 * inversesqrt(q0)), 0.) : .3;
  float l1 = dot(n, n) > .5 ? max(dot(n, d1 * inversesqrt(q1)), 0.) : .3;
  return BCOL * gBI * (750. * l0 / (q0 + 4.) + 260. * l1 / (q1 + 4.));
}
#define CAT_STEPS 56
vec3 extraLight(vec3 p, vec3 n){ return beaconAt(p, n) * .5; }
vec3 skyEnv(vec3 r){ float y = max(r.y, 0.); return vec3(.002, .003, .006) + vec3(.012, .016, .026) * exp(-y * 10.) + vec3(.01, .06, .03) * smoothstep(.1, .4, y) * smoothstep(.8, .4, y) * .6; }

// >>> SNOCAT BEGIN (shared verbatim with s03_base)
// ============================================================ vehicle state ===
vec3 gV;          // vehicle ground-center origin (world)
vec2 gF2;         // heading (world xz), local +Z maps to this
float gPitch, gRoll, gRock;
mat2 gMP, gMR;

// world vector -> local vector (no translation)
vec3 toLoc(vec3 d){
  vec3 q = vec3(dot(d.xz, vec2(gF2.y, -gF2.x)), d.y, dot(d.xz, gF2));
  q.yz = gMP * q.yz;
  q.xy = gMR * q.xy;
  return q;
}
// local vector -> world vector
vec3 toWld(vec3 q){
  q.xy = q.xy * gMR;
  q.yz = q.yz * gMP;
  return vec3(q.x * gF2.y + q.z * gF2.x, q.y, -q.x * gF2.x + q.z * gF2.y);
}
vec3 locToWorldP(vec3 q){ return gV + toWld(q); }

// ============================================================ Sno-Cat model ===
// Tucker Sno-Cat, local frame: +Z forward, +Y up, +X = vehicle's left, origin at ground center.
// ~5.3 m long, 2.8 m wide over the pontoons, 2.95 m tall to the light bar.
#define MB_PAINT 1.
#define MB_ROOF 2.
#define MB_TRACK 3.
#define MB_STEEL 4.
#define MB_GLASS 5.
#define MB_HEAD 6.
#define MB_ROOFLAMP 7.
#define MB_TAIL 8.
#define MB_BLACK 9.

const vec3 CAT_BC = vec3(0., 1.5, 0.);      // bounding box center (local)
const vec3 CAT_BH = vec3(1.46, 1.56, 2.78); // bounding box half extents

vec2 snoCat(vec3 p){
  vec2 res = vec2(1e5, 0.);
  // ---- four pontoon track assemblies, mirrored into one quadrant
  vec3 q = vec3(abs(p.x), p.y, abs(p.z));
  float rk = gRock * (p.x > 0. ? 1. : -1.) * (p.z > 0. ? 1. : -.7);
  vec3 pc = q - vec3(1.08, .46, 1.58);
  pc.yz = rot2(rk) * pc.yz;
  // upturned toe on the outer (front/rear) end of each pontoon
  float toe = smoothstep(.2, .95, pc.z) * .07;
  pc.y -= toe;
  float fz = abs(pc.z) - .54;
  float prof = length(vec2(max(fz, 0.), pc.y)) - .44;          // stadium side profile
  // grousers: steel cleats around the track perimeter
  float s = fz < 0. ? pc.z : atan(pc.y, fz) * .44 + .7;
  float gr = smoothstep(.22, .0, abs(fract(s * 7.2) - .5));
  float ring = max(max(prof, -prof - .1), abs(pc.x) - .33);
  ring -= .016 * gr * smoothstep(-.05, 0., prof);
  float plate = max(prof + .035, abs(pc.x) - .27);             // inset side plate
  float hub = sdCylX(pc, .15, .305);
  res = opU(res, vec2(ring, MB_TRACK));
  res = opU(res, vec2(min(plate, hub), MB_STEEL));
  // spindle/strut from pontoon to chassis + leaf spring pack
  float strut = sdCylX(q - vec3(.66, .5, 1.58), .07, .3);
  strut = min(strut, sdBox(q - vec3(.66, .62, 1.58), vec3(.08, .05, .42)));
  // chassis frame rails
  strut = min(strut, sdBox(p - vec3(0., .72, 0.), vec3(.55, .12, 2.42)));
  res = opU(res, vec2(strut, MB_BLACK));

  // ---- body: hull with sloped hood, full-length cab + cargo box
  float hull = sdRoundBox(p - vec3(0., 1.24, .03), vec3(1.0, .38, 2.56), .05);
  hull = max(hull, dot(p - vec3(0., 1.62, 1.35), vec3(0., .995, .0995)));      // hood slopes to the nose
  float cab = sdRoundBox(p - vec3(0., 2.16, -.6), vec3(.97, .56, 1.94), .07);
  cab = max(cab, dot(p - vec3(0., 1.62, 1.36), vec3(0., .27, .963)));          // raked windshield
  float body = min(hull, cab);
  // recessed side windows (cab and cargo box)
  vec3 wq = vec3(abs(p.x) - .97, p.y - 2.2, p.z);
  float win = min(sdBox(wq - vec3(0., .02, .7), vec3(.035, .32, .52)), sdBox(wq - vec3(0., .04, -1.35), vec3(.035, .2, .72)));
  float bodyW = max(body, -win);
  // rubbing strip along the hull
  res = opU(res, vec2(sdBox(vec3(abs(p.x) - 1.01, p.y - 1.12, p.z), vec3(.03, .04, 2.5)), MB_BLACK));
  // fender lips over the pontoons
  float fend = sdBox(q - vec3(1.03, .98, 1.58), vec3(.2, .03, .78));
  res = opU(res, vec2(bodyW, -win > body ? MB_GLASS : MB_PAINT));
  res = opU(res, vec2(fend, MB_PAINT));
  // white roof cap
  res = opU(res, vec2(sdRoundBox(p - vec3(0., 2.75, -.6), vec3(1.01, .05, 1.99), .04), MB_ROOF));
  vec3 lq = vec3(abs(p.x), p.y, p.z);
  if (p.y > 2.6){
  // light bar on two posts, four lamps
  float lb = sdBox(p - vec3(0., 2.9, 1.06), vec3(.95, .05, .06));
  lb = min(lb, sdBox(vec3(abs(p.x) - .8, p.y - 2.84, p.z - 1.06), vec3(.03, .06, .03)));
  float rl = min(sdCylZ(lq - vec3(.28, 2.91, 1.14), .085, .06), sdCylZ(lq - vec3(.7, 2.91, 1.14), .085, .06));
  res = opU(res, vec2(lb, MB_BLACK));
  res = opU(res, vec2(rl, MB_ROOFLAMP));
  // roof rack over the cargo box: side rails on posts, a couple of lashed crates
  vec3 rr = vec3(abs(p.x) - .9, p.y - 2.98, p.z + 1.35);
  float rack = sdBox(rr, vec3(.022, .022, 1.05));
  rack = min(rack, sdBox(vec3(rr.x, rr.y + .09, mod(rr.z + .35, .7) - .35), vec3(.02, .09, .02)));
  rack = max(rack, abs(rr.z) - 1.06);
  rack = min(rack, sdRoundBox(p - vec3(.3, 2.95, -1.7), vec3(.35, .14, .45), .02));
  rack = min(rack, sdRoundBox(p - vec3(-.35, 2.93, -.9), vec3(.3, .12, .3), .02));
  res = opU(res, vec2(rack, MB_BLACK));
  }
  // headlights in the nose + bumper + grille bar
  float bump = 1e5;
  if (p.z > 2.3){
    float hl = sdCylZ(lq - vec3(.7, 1.36, 2.6), .13, .05);
    res = opU(res, vec2(hl, MB_HEAD));
    bump = sdBox(p - vec3(0., .98, 2.64), vec3(1.06, .07, .07));
  }
  // exhaust stack beside the windshield
  bump = min(bump, sdCylY(p - vec3(-.88, 2.2, 1.45), .045, .55));
  if (p.z < -2.3){
  // rear ladder to the roof
  vec3 rq = p - vec3(.55, 1.95, -2.65);
  float lad = sdBox(vec3(abs(rq.x) - .2, rq.y, rq.z), vec3(.018, .75, .018));
  lad = min(lad, sdBox(vec3(rq.x, mod(rq.y + .15, .3) - .15, rq.z), vec3(.2, .012, .012)));
  lad = max(lad, abs(rq.y) - .76);
  bump = min(bump, lad);
  // tail lights
  float tl = sdBox(lq - vec3(.82, 1.3, -2.55), vec3(.09, .07, .04));
  res = opU(res, vec2(tl, MB_TAIL));
  }
  res = opU(res, vec2(bump, MB_BLACK));
  return res;
}

vec3 catNormal(vec3 p){
  const vec2 k = vec2(1, -1);
  const float h = .004;
  return normalize(k.xyy * snoCat(p + k.xyy * h).x + k.yyx * snoCat(p + k.yyx * h).x +
                   k.yxy * snoCat(p + k.yxy * h).x + k.xxx * snoCat(p + k.xxx * h).x);
}

vec2 boxHit(vec3 ro, vec3 rd, vec3 c, vec3 h){
  vec3 m = 1. / rd;
  vec3 n = m * (ro - c);
  vec3 k = abs(m) * h;
  vec3 t1 = -n - k, t2 = -n + k;
  return vec2(max(max(t1.x, t1.y), t1.z), min(min(t2.x, t2.y), t2.z));
}
float sphHit(vec3 ro, vec3 rd, vec3 c, float r){
  vec3 oc = ro - c; float b = dot(oc, rd); float h = b * b - dot(oc, oc) + r * r;
  return h < 0. ? -1. : -b - sqrt(h);
}

// march the vehicle in local space. returns t (world units == local units) or -1
float marchCat(vec3 rol, vec3 rdl, float tmax, out float mat){
  mat = 0.;
  vec2 bb = boxHit(rol, rdl, CAT_BC, CAT_BH);
  if (bb.x > bb.y || bb.y < 0. || bb.x > tmax) return -1.;
  float t = max(bb.x, 0.);
  float tend = min(bb.y, tmax);
  for (int i = 0; i < CAT_STEPS; i++){
    vec2 h = snoCat(rol + rdl * t);
    if (h.x < .0015 * t + .001){ mat = h.y; return t; }
    t += h.x * .9;
    if (t > tend) break;
  }
  return -1.;
}

// ============================================================ lights ===
const vec3 HLCOL = vec3(1., .88, .68);       // halogen headlights
const vec3 RLCOL = vec3(1., .93, .8);        // roof bar lamps
const vec3 TLCOL = vec3(1., .06, .03);       // tail lights
vec3 gHL0, gHL1, gRL, gTL0, gTL1, gHD, gRD, gFW;

void setupLights(){
  gHL0 = locToWorldP(vec3(.7, 1.36, 2.66));
  gHL1 = locToWorldP(vec3(-.7, 1.36, 2.66));
  gRL = locToWorldP(vec3(0., 2.91, 1.22));
  gTL0 = locToWorldP(vec3(.82, 1.3, -2.6));
  gTL1 = locToWorldP(vec3(-.82, 1.3, -2.6));
  gHD = normalize(toWld(vec3(0., -.07, 1.)));
  gRD = normalize(toWld(vec3(0., -.13, 1.)));
  gFW = toWld(vec3(0., 0., 1.));
}
float spotI(vec3 x, vec3 lp, vec3 ld, float co, float ci, out vec3 L){
  vec3 d = lp - x; float dd = dot(d, d); L = d * inversesqrt(dd);
  float c = dot(-L, ld);
  // hot core + beam + wide reflector spill
  return (smoothstep(co, ci, c) * (.35 + .65 * smoothstep(ci, 1., c)) + .03 * smoothstep(-.1, .75, c)) / (dd + 1.5);
}
// irradiance at x from all the vehicle's lamps. n = surface normal, or 0 for volume
// (then the forward-scattering phase toward the camera is used, view dir rd).
vec3 lampsAt(vec3 x, vec3 n, vec3 rd){
  vec3 L; vec3 acc = vec3(0.);
  float vol = step(dot(n, n), .5);
  float i;
  i = spotI(x, gHL0, gHD, .74, .965, L);
  acc += HLCOL * 160. * i * mix(max(dot(n, L), 0.), hgPhase(dot(L, rd), .2) * 1.2, vol);
  i = spotI(x, gHL1, gHD, .74, .965, L);
  acc += HLCOL * 160. * i * mix(max(dot(n, L), 0.), hgPhase(dot(L, rd), .2) * 1.2, vol);
  i = spotI(x, gRL, gRD, .65, .93, L);
  acc += RLCOL * 190. * i * mix(max(dot(n, L), 0.), hgPhase(dot(L, rd), .2) * 1.2, vol);
  // light-bar reflector spill: wide, lights the snow around the front half of the vehicle
  vec3 dw = gRL - x; float d2w = dot(dw, dw); vec3 Lw = dw * inversesqrt(d2w);
  acc += RLCOL * 14. * smoothstep(-.45, .3, dot(-Lw, gFW)) / (d2w + 2.) * mix(max(dot(n, Lw), 0.), .08, vol);
  // tail lights: weak, wide
  vec3 tc = (gTL0 + gTL1) * .5;
  vec3 dt = tc - x; float d2 = dot(dt, dt); vec3 Lt = dt * inversesqrt(d2);
  float back = smoothstep(-.2, .5, dot(-Lt, -gFW));
  acc += TLCOL * 1.6 * back / (d2 + 1.) * mix(max(dot(n, Lt), 0.), .25, vol);
  return acc;
}

// shade a vehicle hit (no fog). rol/rdl: ray in vehicle-local space, tv: hit distance
vec3 shadeCat(vec3 ro, vec3 rd, vec3 rol, vec3 rdl, float tv, float mat, float t, float gust){
  vec3 col;
  vec3 pl = rol + rdl * tv;
  vec3 nl = catNormal(pl);
  vec3 pw = ro + rd * tv;
  vec3 nw = toWld(nl);
  // albedo and grime
  float grime = fbm3lo(pl * 3.);
  float low = smoothstep(1.3, .6, pl.y);
  vec3 alb = vec3(.5);
  float spec = .3, rough = 32.;
  vec3 emis = vec3(0.);
  if (mat == MB_PAINT){
    alb = vec3(.42, .06, .025) * (.75 + .4 * grime);
    alb = mix(alb, vec3(.14, .1, .08), low * .6 + .25 * smoothstep(.55, .75, grime));
    // hood/fender snow and rime
    float sn = smoothstep(.55, .9, nl.y) * smoothstep(.35, .6, noise3(pl * 4.));
    alb = mix(alb, vec3(.75, .8, .88), sn);
    // grille slats in the nose
    if (nl.z > .7 && pl.y < 1.55 && pl.y > 1.08 && abs(pl.x) < .45) alb *= .25 + .75 * step(.5, fract(pl.y * 14.));
    // stencilled unit number on the doors
    spec = .5; rough = 48.;
  } else if (mat == MB_ROOF){
    alb = vec3(.7, .72, .74) * (.8 + .25 * grime); spec = .35;
  } else if (mat == MB_TRACK){
    vec3 qq = vec3(abs(pl.x), pl.y, abs(pl.z)) - vec3(1.08, .46, 1.58);
    float fzz = abs(qq.z) - .54;
    float ss = fzz < 0. ? qq.z : atan(qq.y, fzz) * .44 + .7;
    float gr = smoothstep(.22, .0, abs(fract(ss * 7.2) - .5));
    // dark rubber belt, bare steel cleat crests, snow packed between cleats low down
    float cleat = step(.2, gr);
    float caked = smoothstep(.62, .8, noise3(vec3(pl.x * 2., pl.y * 5., pl.z * 5.))) * (1. - cleat) * (.4 + .6 * low);
    alb = mix(vec3(.03, .03, .033), vec3(.13, .13, .14), cleat);
    alb = mix(alb, vec3(.55, .6, .68), caked * .7); spec = .5 + .5 * cleat; rough = 24.;
  } else if (mat == MB_STEEL){
    alb = vec3(.09, .085, .08) * (.7 + .6 * grime);
    alb = mix(alb, vec3(.6, .65, .72), smoothstep(.5, .7, noise3(pl * 5.)) * .7); spec = .3;
  } else if (mat == MB_BLACK){
    alb = vec3(.035); spec = .5;
  } else if (mat == MB_HEAD){
    alb = vec3(.1); if (nl.z > .6) emis = HLCOL * 9. * (1. - .5 * smoothstep(.07, .13, length(vec2(abs(pl.x) - .7, pl.y - 1.36))));
  } else if (mat == MB_ROOFLAMP){
    alb = vec3(.1); if (nl.z > .6) emis = RLCOL * 7.;
  } else if (mat == MB_TAIL){
    alb = vec3(.15, .02, .02); if (nl.z < -.6) emis = TLCOL * 6.;
  }
  // windows: glass everywhere on the upper cab faces that face out (windshield/back included)
  bool glass = mat == MB_GLASS;
  if (mat == MB_PAINT){
    if (nl.z > .8 && pl.y > 1.8 && pl.y < 2.58 && abs(pl.x) < .9 && abs(pl.x) > .04) glass = true;            // windshield (split)
    if (nl.z < -.8 && pl.y > 1.95 && pl.y < 2.5 && abs(abs(pl.x) - .45) < .26 && pl.x > -.9 && !(pl.x > .25 && pl.x < .85)) glass = true; // rear window (door has ladder side)
  }
  vec3 V = -rd;
  // --- lighting: sky ambient, bounce from its own lit snow pool, fog glow, spec glints
  float ao = clamp(.35 + .65 * smoothstep(.3, 1.4, pl.y) + .3 * max(nl.y, 0.), 0., 1.);
  vec3 E = SKYAMB * 2.6 * (.6 + .5 * nw.y) * ao;
  vec3 pool = locToWorldP(vec3(0., 0., 7.));
  vec3 dp = pool - pw; float dd = length(dp);
  vec3 poolE = HLCOL * 1.9 / (1. + dd * dd * .03);
  E += poolE * max(dot(nw, dp / dd) * .8 + .2, 0.) * ao;
  E += HLCOL * .03 * (.3 + .7 * max(dot(nw, gFW), 0.));                    // glow of the lit spindrift
  // bounce from the lamp-lit snow right around this point
  vec3 gp = pw + nw * 1.2; gp.y = 0.;
  E += lampsAt(gp, vec3(0., 1., 0.), rd) * .7 * .5 * (.55 - .45 * nw.y) * ao;                     // glow of lit spindrift
  vec3 tc = (gTL0 + gTL1) * .5 - gFW * .6; vec3 dtl = tc - pw;            // tail light spill on the rear
  E += TLCOL * .3 * max(dot(nw, normalize(dtl)), 0.) / (1. + dot(dtl, dtl) * 8.);
  E += extraLight(pw, nw);
  col = alb * E + emis;
  // rim: the lit spindrift just behind the silhouette wraps around the edges
  float rimF = pow(1. - max(dot(nw, V), 0.), 3.);
  col += min(lampsAt(pw + rd * .6 + nw * .5, vec3(0.), rd), vec3(2.)) * rimF * .16 * (.3 + .7 * alb.r + spec);
  // panel seams: doors, hood, cargo box
  if (mat == MB_PAINT && abs(nl.x) > .7){
    float seam = smoothstep(.012, .0, abs(pl.z - 1.22)) + smoothstep(.012, .0, abs(pl.z - .12)) * step(1.05, pl.y) + smoothstep(.012, .0, abs(pl.y - 1.66)) + smoothstep(.012, .0, abs(pl.z + 2.1)) * step(1.7, pl.y);
    col *= 1. - .7 * clamp(seam, 0., 1.);
    // door handle glint
    col += vec3(.3) * smoothstep(.03, .0, length(vec2(pl.z - .25, pl.y - 1.78))) * (E.r + .02) * 2.;
  }
  vec3 R = reflect(rd, nw);
  float fres = .04 + .96 * pow(1. - max(dot(nw, V), 0.), 5.);
  vec3 env = skyEnv(R) * 4. + poolE * pow(max(dot(R, dp / dd), 0.), rough) * .6;
  col += env * fres * spec * ao;
  if (glass){
    // dark glass reflecting the sky, and the dome-lit cab behind it with the crew in silhouette
    vec3 inside = vec3(0.);
    vec3 ip = pl; vec3 id = rdl;
    vec3 dome = vec3(0., 2.55, .3);
    float hitS = 1e5;
    for (int k = 0; k < 2; k++){
      float sx = k == 0 ? .44 : -.44;
      float th = sphHit(ip, id, vec3(sx, 2.23, .72), .13);
      if (th > 0.) hitS = min(hitS, th);
      float tb = sphHit(ip, id, vec3(sx, 1.88, .78), .26);
      if (tb > 0.) hitS = min(hitS, tb);
    }
    vec3 glow = vec3(1., .62, .3) * .08;
    float edge = 1.;
    if (hitS < 1e4){
      vec3 hp = ip + id * hitS;
      inside = vec3(.004, .003, .002) + glow * .25 * smoothstep(.3, 0., length(hp - dome) - .5);
    } else {
      vec3 far = ip + id * 1.2;
      inside = glow * (1.2 / (1. + dot(far - dome, far - dome) * 1.5)) + vec3(.01, .006, .003);
    }
    float gf = .05 + .95 * pow(1. - max(dot(nw, V), 0.), 5.);
    col = inside * (1. - gf) + (skyEnv(R) * 3. + poolE * .15 * pow(max(dot(R, dp / dd), 0.), 8.)) * gf;
    col += vec3(.02, .025, .03) * smoothstep(.55, .75, noise3(pl * 18.)) * .3;   // frost on the glass
  }
  return col;
}
// <<< SNOCAT END

// ============================================================ vehicle ===
void vehicleState(float t){
  gV = vec3(0.);
  gF2 = vec2(0., 1.);
  // idling diesel shiver
  gPitch = .003 * sin(t * 31.) + .002 * sin(t * 17.3);
  gRoll = .002 * sin(t * 23.);
  gRock = 0.;
  gMP = rot2(gPitch); gMR = rot2(gRoll);
}

// ============================================================ camera ===
vec3 gRo, gFw, gRt, gUp; float gFocal;
void setupCam(float t){
  float k = smoothstep(-1., 11., t);
  gRo = mix(vec3(6.4, 2.0, -13.5), vec3(5.4, 1.85, -10.0), k);
  vec3 ta = mix(vec3(-.2, 3.0, 26.), vec3(.6, 2.9, 26.), k);
  ta += vec3(noise2(vec2(t * .5, 1.)) - .5, noise2(vec2(t * .43, 7.)) - .5, 0.) * .35;   // handheld
  gFw = normalize(ta - gRo);
  gRt = normalize(cross(gFw, vec3(0., 1., 0.)));   // screen right = world -X when looking down +Z
  gUp = cross(gRt, gFw);
  gFocal = mix(1.75, 2.05, k);
}
vec3 camDir(vec2 uv){ return normalize(uv.x * gRt + uv.y * gUp + gFocal * gFw); }
vec3 proj(vec3 wp){ vec3 r = wp - gRo; float z = dot(r, gFw); return vec3(vec2(dot(r, gRt), dot(r, gUp)) / max(z, .001) * gFocal, z); }

// ============================================================ Object 9 ===
const float PX = 1.0, PZ = 26.0;           // portal center x, front face z
#define MS_SNOW 20.
#define MS_CONC 21.
#define MS_DOOR 22.
#define MS_DSTEEL 23.
#define MS_DRUM 24.
#define MS_MOD 25.
#define MS_POLE 26.
#define MS_LAMP 27.

const vec3 MODA = vec3(15., 3.55, 33.);    // module A center, half length 8.5, yaw MODA_A
const vec3 MODB = vec3(25., 3.7, 58.);     // module B center, half length 9, yaw MODB_A
const float MODA_A = 1.25, MODB_A = 1.45;
vec3 modLocal(vec3 p, vec3 c, float a){ vec3 q = p - c; q.xz = rot2(a) * q.xz; return q; }
const vec3 POST = vec3(-6.2, 0., 22.6);

float groundH(vec2 xz){
  float h = 0.;
  // the big drift the bunker is cut into
  vec2 d = xz - vec2(PX, PZ + 6.5);
  float dx = abs(xz.x - PX);
  if (abs(d.x) < 30. && abs(d.y) < 24.){
    float mound = 10.5 * exp(-d.x * d.x / 110. - d.y * d.y / 80.);
    float cut = smoothstep(PZ + .9, PZ + 4.5, xz.y);   // keep the approach and the door recess clear
    mound *= mix(1., cut, smoothstep(6.9, 4.5, dx));
    h += mound;
    // drifts piled against the portal face beside the door, and across the threshold
    if (abs(xz.y - PZ) < 5. && dx < 8.){
      h += 1.5 * exp(-(pow(dx - 3.3, 2.) / 1.3 + pow(xz.y - PZ + .8, 2.) / 1.6));
      h += .32 * exp(-(pow(xz.x - PX, 2.) / 2.5 + pow(xz.y - PZ + .4, 2.) / .45));
    }
  }
  if (xz.x < 6.) return h;
  // long drifts along the modules, half burying the stilts
  vec3 qa = modLocal(vec3(xz.x, 0., xz.y), MODA, MODA_A), qb = modLocal(vec3(xz.x, 0., xz.y), MODB, MODB_A);
  float za = smoothstep(9.8, 7., abs(qa.z)), zb = smoothstep(10.3, 7.5, abs(qb.z));
  h += 1.4 * exp(-pow(qa.x - .8, 2.) / 5.) * za + 1.1 * exp(-pow(qa.x + 2.7, 2.) / 1.6) * za;
  h += 1.7 * exp(-pow(qb.x - .4, 2.) / 6.) * zb;
  return h;
}

float portalSDF(vec3 p, out float m){
  vec3 q = p - vec3(PX, 0., PZ);
  m = MS_CONC;
  float blk = sdBox(q - vec3(0., 3., 3.2), vec3(4.6, 3., 3.2));
  float lin = sdBox(q - vec3(0., 5.55, -.25), vec3(4.95, .45, .45));
  // splayed wing walls with sloping tops
  vec2 dir = vec2(.48, -.877);
  vec2 rel = vec2(abs(q.x), q.z) - (vec2(4.35, .1) + dir * 2.4);
  float along = dot(rel, dir), across = dot(rel, vec2(-dir.y, dir.x));
  float wing = sdBox(vec3(across, q.y - 2.4, along), vec3(.3, 2.4, 2.4));
  wing = max(wing, (q.y - (4.8 - (along + 2.4) * .8)) * .78);
  float conc = min(min(blk, lin), wing);
  // snow cornice draped over the roof and lintel
  float cap = sdEllipsoid(q - vec3(0., 6.0, 1.2), vec3(5.4, .6, 2.2));
  cap = smin(cap, sdEllipsoid(q - vec3(0., 5.95, -.45), vec3(5.2, .22, .5)), .3);
  cap += .06 * (noise2(q.xz * 1.3) - .5);
  // stepped door recess
  float rec1 = sdBox(q - vec3(0., 1.8, 0.), vec3(1.85, 2.05, .2));
  float rec2 = sdBox(q - vec3(0., 1.66, .5), vec3(1.44, 1.68, .75));
  conc = max(conc, -min(rec1, rec2));
  // concrete chipping on the edges
  if (conc < .1) conc += .03 * (noise3(p * 3.1) - .5);
  float d = conc;
  // steel jamb lining the inner opening
  float jamb = max(sdBox(q - vec3(0., 1.66, .42), vec3(1.52, 1.76, .24)), -sdBox(q - vec3(0., 1.66, .4), vec3(1.42, 1.66, .4)));
  // blast door slab (face at z = .56)
  float door = sdRoundBox(q - vec3(0., 1.64, .8), vec3(1.37, 1.6, .24), .03);
  // raised rim and two reinforcing ribs
  vec3 dq = q - vec3(0., 1.64, .53);
  float rim = max(sdBox(dq, vec3(1.3, 1.53, .04)), -sdBox(dq, vec3(1.13, 1.36, .1)));
  rim = min(rim, sdBox(vec3(dq.x, abs(dq.y) - .7, dq.z), vec3(1.15, .05, .035)));
  door = min(door, rim);
  float dm = MS_DOOR;
  // handwheel, hub and three spokes
  vec3 wq = q - vec3(-.05, 1.72, .42);
  float wheel = length(vec2(length(wq.xy) - .38, wq.z)) - .035;
  wheel = min(wheel, sdCylZ(wq - vec3(0., 0., .04), .08, .09));
  vec2 sp = wq.xy;
  for (int i = 0; i < 3; i++){
    wheel = min(wheel, sdBox(vec3(sp, wq.z), vec3(.38, .018, .018)));
    sp = rot2(1.0472) * sp;
  }
  // dogs (locking lugs) on the latch side and top, hinges on the other side
  vec3 lq = q - vec3(-1.4, 1.64, .47);
  lq.y = lq.y - clamp(floor(lq.y / 1.05 + .5), -1., 1.) * 1.05;
  float dogs = sdBox(lq, vec3(.2, .075, .07));
  dogs = min(dogs, sdCylZ(lq - vec3(-.05, 0., -.05), .05, .06));
  vec3 tq = q - vec3(0., 3.27, .47);
  tq.x = abs(tq.x) - .6;
  dogs = min(dogs, sdBox(tq, vec3(.075, .18, .07)));
  vec3 hq = q - vec3(1.47, 1.64, .45);
  hq.y = abs(hq.y) - 1.05;
  float hinge = sdCylY(hq, .1, .24);
  float steel = min(min(wheel, dogs), min(hinge, jamb));
  if (cap < d){ d = cap; m = MS_SNOW; }
  if (door < d){ d = door; m = MS_DOOR; }
  if (steel < d){ d = steel; m = MS_DSTEEL; }
  return d;
}

float moduleSDF(vec3 p, vec3 c, float hl, float a, out float m){
  vec3 q = modLocal(p, c, a);
  float body = sdRoundBox(q, vec3(1.75, 1.45, hl), .35);
  // corrugated skin: ribs around the section
  if (body < .12) body -= .035 * smoothstep(.2, .9, cos(q.z * 17.95));
  m = MS_MOD;
  // stilts every 3 m, both sides
  vec3 s = q; s.x = abs(s.x) - 1.2;
  s.z -= clamp(floor(s.z / 3. + .5), -floor(hl / 3.), floor(hl / 3.)) * 3.;
  float st = sdCylY(s - vec3(0., -2.5, 0.), .11, 1.1);
  // cross bracing between stilt pairs
  vec3 bq = vec3(q.x, s.y + 2.5, s.z);
  st = min(st, sdBox(vec3(bq.x, bq.y, bq.z), vec3(1.2, .05, .05)));
  if (st < body){ m = MS_POLE; return st; }
  return body;
}

float postSDF(vec3 p){
  vec3 q = p - POST;
  q.xy = rot2(-.06) * q.xy;                             // leaning
  float pole = sdTaper(q, vec3(0.), vec3(0., 7., 0.), .12, .065);
  pole = min(pole, sdCapsule(q, vec3(0., 6.9, 0.), vec3(1.1, 7.25, 0.), .05));
  pole = min(pole, sdCylY(q - vec3(0., .5, 0.), .2, .5));  // base plinth
  return pole;
}
float lampHeadSDF(vec3 p){
  vec3 q = p - POST; q.xy = rot2(-.06) * q.xy;
  return sdEllipsoid(q - vec3(1.4, 7.18, 0.), vec3(.48, .16, .27));
}

// fuel drums: (x, z, tilt, lying)
float drumSDF(vec3 p){
  float d = 1e5;
  for (int i = 0; i < 5; i++){
    vec3 c; float a = 0.; float lying = 0.;
    if (i == 0){ c = vec3(4.5, .3, 23.3); a = .08; }
    else if (i == 1){ c = vec3(5.25, .12, 23.9); a = -.05; }
    else if (i == 2){ c = vec3(3.8, .22, 22.1); lying = 1.; a = .7; }
    else if (i == 3){ c = vec3(-4.3, .25, 22.9); a = .22; }
    else { c = vec3(-3.7, .05, 23.8); a = -.1; }
    vec3 q = p - c;
    if (dot(q, q) > 1.5) continue;
    if (lying > .5){ q.xz = rot2(a) * q.xz; q = q.yxz; }
    else q.xy = rot2(a) * q.xy;
    float dr = sdCylY(q - vec3(0., .44, 0.), .29, .44);
    dr -= .012 * smoothstep(.03, .0, abs(abs(q.y - .44) - .15));   // rolling hoops
    d = min(d, dr);
  }
  return d;
}

const vec3 BB_MIN = vec3(-26., -1., 10.), BB_MAX = vec3(30., 9.5, 72.);

vec2 mapBase(vec3 p, bool ground){
  // the drift rises steeply behind the portal: march it more carefully there
  float lip = (abs(p.x - PX) < 7.5 && p.z > PZ - 1. && p.z < PZ + 8.) ? .33 : .6;
  vec2 r = vec2(ground ? (p.y - groundH(p.xz)) * lip : 1e5, MS_SNOW);
  float m;
  // every object is only evaluated when its bounding box is closer than what we already have
  float bd = sdBox(p - vec3(PX, 3.4, PZ + 1.4), vec3(7.4, 3.5, 5.8));
  if (bd < r.x){
    float d = portalSDF(p, m);
    if (d < r.x) r = vec2(d, m);
  }
  vec3 qa = modLocal(p, MODA, MODA_A);
  bd = sdBox(qa - vec3(0., -1.6, 0.), vec3(1.9, 3.1, 8.8));
  if (bd < r.x){
    float d = moduleSDF(p, MODA, 8.5, MODA_A, m);
    if (d < r.x) r = vec2(d, m);
  }
  vec3 qb = modLocal(p, MODB, MODB_A);
  bd = sdBox(qb - vec3(0., -1.6, 0.), vec3(1.9, 3.2, 9.3));
  if (bd < r.x){
    float d = moduleSDF(p, MODB, 9., MODB_A, m);
    if (d < r.x) r = vec2(d, m);
  }
  bd = sdBox(p - POST - vec3(.7, 3.7, 0.), vec3(1.4, 3.8, .45));
  if (bd < r.x){
    float d = postSDF(p);
    if (d < r.x) r = vec2(d, MS_POLE);
    d = lampHeadSDF(p);
    if (d < r.x) r = vec2(d, MS_LAMP);
  }
  bd = sdBox(p - vec3(PX, .6, 23.), vec3(6.2, .7, 1.8));
  if (bd < r.x){
    float d = drumSDF(p);
    if (d < r.x) r = vec2(d, MS_DRUM);
  }
  return r;
}
vec3 baseNormal(vec3 p, float t){
  const vec2 k = vec2(1, -1);
  float h = .004 + .0006 * t;
  return normalize(k.xyy * mapBase(p + k.xyy * h, true).x + k.yyx * mapBase(p + k.yyx * h, true).x +
                   k.yxy * mapBase(p + k.yxy * h, true).x + k.xxx * mapBase(p + k.xxx * h, true).x);
}
float marchBase(vec3 ro, vec3 rd, float tmax, out float mat){
  mat = 0.;
  vec2 bb = boxHit(ro, rd, (BB_MIN + BB_MAX) * .5, (BB_MAX - BB_MIN) * .5);
  if (bb.x > bb.y || bb.y < 0.) return -1.;
  float t = max(bb.x, 0.);
  float te = min(bb.y, tmax);
  for (int i = 0; i < 90; i++){
    if (t > te) break;
    vec3 p = ro + rd * t;
    vec2 h = mapBase(p, true);
    if (h.x < .0015 * t){ mat = h.y; return t; }
    t += h.x;
  }
  return -1.;
}
// soft shadow toward the vehicle's lamp cluster
float lampShadow(vec3 p, vec3 lp){
  vec3 d = lp - p; float L = length(d); d /= L;
  float res = 1., t = .15;
  for (int i = 0; i < 12; i++){
    vec3 x = p + d * t;
    if (x.z < BB_MIN.z) break;
    float h = mapBase(x, false).x;
    res = min(res, 10. * h / t);
    t += clamp(h, .12, 2.);
    if (res < .02 || t > L) break;
  }
  return clamp(res, 0., 1.);
}

// ============================================================ shading of the base ===
vec3 shadeBase(vec3 p, vec3 rd, float tb, float mat, float t, float gust, bool isFlat){
  vec3 n = isFlat ? vec3(0., 1., 0.) : baseNormal(p, tb);
  vec3 alb = vec3(.5); float spec = .05;
  vec3 emis = vec3(0.);
  float frost = 0.;
  if (mat == MS_SNOW){
    // wind-carved sastrugi
    vec2 sp = (rot2(.45) * p.xz) * vec2(.35, .9);
    float h0 = noise2(sp), hx = noise2(sp + vec2(.1, 0.)), hz = noise2(sp + vec2(0., .1));
    float bm = .3 * smoothstep(50., 5., tb) * smoothstep(.75, .95, n.y);
    n = normalize(n + vec3(-(hx - h0), 0., -(hz - h0)) * 10. * bm);
    alb = vec3(.78, .83, .9) * (.92 + .1 * h0);
    // under the vehicle, and its track ruts leading in from behind
    vec3 pl = toLoc(p - gV);
    float foot = sdBox2(pl.xz, vec2(1.35, 2.6));
    alb *= mix(.2, 1., smoothstep(-.3, 1.3, foot));
    float rut = smoothstep(.36, .16, abs(abs(pl.x) - 1.08)) * step(pl.z, -2.3);
    alb *= 1. - .35 * rut;
  } else if (mat == MS_CONC){
    float n1 = fbm3lo(p * vec3(1.3, .6, 1.3));
    alb = vec3(.36, .35, .33) * (.6 + .6 * n1);
    // water/rust stains running down from the lintel
    float streak = smoothstep(.55, .8, noise2(vec2(p.x * 3.1, p.y * .25))) * smoothstep(5.2, 2.5, p.y);
    alb *= 1. - .45 * streak;
    // formwork lines
    alb *= 1. - .3 * smoothstep(.02, .0, abs(fract(p.y / 1.2) - .5) - .48);
    // stencil + star on the face above the door
    if (n.z < -.7 && p.z < PZ + .05 && abs(p.x - PX) < 4.5 && p.y > 3.55 && p.y < 5.1){
      vec2 tuv = vec2((PX - p.x) / 9. + .5, (p.y - 3.55) / 1.55);
      vec4 tx = texture(iTex0, tuv);
      alb = mix(alb, tx.rgb, tx.a);
    }
    frost = smoothstep(.45, .75, fbm3lo(p * 2.3)) * .6 + .5 * smoothstep(.3, .9, n.y);
  } else if (mat == MS_DOOR){
    alb = vec3(.13, .16, .13) * (.7 + .5 * fbm3lo(p * 2.));
    float rust = smoothstep(.55, .75, noise3(vec3(p.x * 4., p.y * .8, p.z * 4.))) * smoothstep(.6, .0, fract(p.y * .9));
    alb = mix(alb, vec3(.2, .08, .03), rust * .8);
    // painted warning stripes near the bottom, worn
    float stripes = step(.5, fract((p.x + p.y) * 1.6)) * step(p.y, .55) * step(.4, noise2(p.xy * 6.));
    alb = mix(alb, vec3(.35, .28, .05), stripes * .7);
    spec = .25;
    frost = smoothstep(.5, .8, fbm3lo(p * 3.)) * .5;
  } else if (mat == MS_DSTEEL){
    alb = vec3(.07, .075, .075) * (.7 + .6 * noise3(p * 9.));
    alb = mix(alb, vec3(.18, .07, .03), smoothstep(.5, .8, noise3(p * 5.)) * .7);
    spec = .5;
    frost = .3 * smoothstep(.4, .9, n.y);
  } else if (mat == MS_MOD){
    alb = vec3(.55, .54, .5) * (.7 + .5 * fbm3lo(p * .8));
    alb = mix(alb, vec3(.16, .08, .04), smoothstep(.55, .8, noise3(vec3(p.x, p.y * 3., p.z) * .9)) * .6);
    // square portholes, dark and frosted
    vec3 q = length(p.xz - MODA.xz) < 11. ? modLocal(p, MODA, MODA_A) : modLocal(p, MODB, MODB_A);
    vec3 nq = n; nq.xz = rot2(length(p.xz - MODA.xz) < 11. ? MODA_A : MODB_A) * nq.xz;
    if (abs(nq.x) > .7 && abs(q.y - .25) < .38 && abs(mod(q.z + 1.5, 3.) - 1.5) < .38) { alb = vec3(.012, .014, .018); spec = .6; }
    frost = .6 * smoothstep(.5, .9, n.y) + .3 * smoothstep(.55, .85, noise3(p * 1.7));
    spec = max(spec, .15);
  } else if (mat == MS_DRUM){
    float id = floor(p.x * .7 + p.z * .3);
    alb = mix(vec3(.26, .05, .03), vec3(.14, .16, .09), step(.5, hash11(id)));
    alb = mix(alb, vec3(.16, .07, .03), smoothstep(.45, .75, noise3(p * 6.)));
    spec = .3;
    frost = .8 * smoothstep(.5, .9, n.y);
  } else if (mat == MS_POLE){
    alb = vec3(.1, .1, .1) * (.7 + .5 * noise3(p * 4.));
    frost = .5 * smoothstep(.55, .85, noise3(p * vec3(1., 6., 1.)));
    spec = .3;
  } else if (mat == MS_LAMP){
    alb = vec3(.08, .08, .07); spec = .8;
    if (n.y < -.3) { alb = vec3(.22, .17, .1); spec = .9; }   // dead sodium lens
  }
  alb = mix(alb, vec3(.72, .76, .82), clamp(frost, 0., 1.));

  vec3 lc = locToWorldP(vec3(0., 1.9, 2.6));
  vec3 lamp = lampsAt(p, n, rd);
  float lum = dot(lamp, vec3(.3, .5, .2));
  // only things out at the base can cast shadows from the lamps
  float sh = (lum > .002 && p.z > 19.) ? lampShadow(p + n * .02, lc) : 1.;
  float ao = isFlat ? 1. : clamp(.4 + .6 * mapBase(p + n * .6, true).x / .36, 0., 1.);
  vec3 bcn = beaconAt(p, n);
  vec3 E = SKYAMB * (.55 + .6 * n.y) * ao * 1.3;
  E += vec3(.004, .012, .007) * max(n.y, 0.) * ao;                // green aurora skylight on snow
  E += lamp * sh;
  E += bcn * (.5 + .5 * ao);
  vec3 col = alb * E + emis;
  // spec glints (steel, glassy frost) from the lamps
  vec3 L = normalize(lc - p);
  vec3 H = normalize(L - rd);
  col += lamp * sh * spec * pow(max(dot(n, H), 0.), 40.) * 2.;
  vec3 Lb = normalize(gB0 - p);
  col += bcn * spec * pow(max(dot(n, normalize(Lb - rd)), 0.), 30.);
  // glitter on snow
  if (mat == MS_SNOW){
    float g = hash21(floor(p.xz * 45.));
    if (g > .994) col += (lamp * sh + bcn * .5) * .6 * hash11(g * 13. + floor(t * 10.)) * smoothstep(40., 4., tb);
  }
  return col;
}

// ============================================================ mast (projected lines) ===
float segDist(vec2 p, vec2 a, vec2 b){ vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.); return length(pa - ba * h); }

// returns coverage of the lattice mast + guy wires at uv; depth test against scene distance tScene
float mastCover(vec2 uv, float tScene, out float hgt){
  hgt = 0.;
  vec3 mp = proj(MAST);
  if (mp.z < 1. || mp.z > tScene) return 0.;
  float sc = gFocal / mp.z;                          // screen units per meter at the mast
  float px = 1. / iResolution.y;
  float cov = 0.;
  // guy wires: from three heights to three anchors, 120 degrees apart
  for (int a = 0; a < 3; a++){
    float ang = float(a) * 2.094 + .5;
    vec3 anc = MAST + vec3(cos(ang), 0., sin(ang)) * 15.;
    vec3 ap = proj(anc);
    if (ap.z < 1.) continue;
    for (int k = 0; k < 3; k++){
      float hh = 7. + float(k) * 7.5;
      vec3 tp = proj(MAST + vec3(0., hh, 0.));
      float d = segDist(uv, tp.xy, ap.xy);
      cov = max(cov, smoothstep(px * 1.2, px * .2, d) * .55);
    }
  }
  // lattice: local mast-plane coords in meters
  vec2 q = (uv - mp.xy) / sc;
  if (q.y < -1. || q.y > MAST_H + 1.5 || abs(q.x) > 2.) return cov;
  hgt = q.y;
  float w = mix(.9, .3, q.y / MAST_H);              // half width, tapered
  float pxm = px / sc;                               // one pixel in meters at the mast
  // members are thinner than a pixel: distance to centerlines, coverage scaled by width/pixel
  float legs = abs(abs(q.x) - w);
  float ph = 1.4;
  float yy = mod(q.y, ph) / ph;
  float br = min(abs(q.x - w * (2. * yy - 1.)), abs(q.x + w * (2. * yy - 1.)));
  br = min(br, abs(mod(q.y + .5 * ph, ph) - .5 * ph));
  br = max(br, abs(q.x) - w);
  float inM = step(0., q.y) * step(q.y, MAST_H);
  float cL = smoothstep(pxm, 0., legs) * min(1., .16 / pxm + .25);
  float cB = smoothstep(pxm, 0., br) * min(1., .07 / pxm + .12);
  float c = max(cL, cB) * inM;
  // top: beacon housing and a short antenna; mid platform
  float top = min(sdBox2(q - vec2(0., MAST_H + .2), vec2(.2, .22)), sdBox2(q - vec2(0., MAST_H + 1.2), vec2(.03, 1.)));
  top = min(top, sdBox2(q - vec2(0., 12.), vec2(w + .2, .08)));
  c = max(c, smoothstep(pxm, 0., top));
  cov = max(cov, c);
  return cov;
}

// ============================================================ render ===
vec3 render(vec2 fc){
  float t = iTime;
  float gust = uP[0];
  gBI = uP[1];
  gB0 = MAST + vec3(0., MAST_H + .3, 0.);
  gB1 = MAST + vec3(0., 12.2, 0.);
  vec2 uv = screenUV(fc);
  vehicleState(t);
  setupLights();
  setupCam(t);
  vec3 ro = gRo, rd = camDir(uv);
  float dither = hash31(vec3(fc, float(iFrame % 97) + .5));
  float sig = .014 + .012 * gust;
  vec3 fogC = vec3(.011, .014, .024) * (1. + .4 * gust);

  // vehicle
  vec3 rol = toLoc(ro - gV), rdl = toLoc(rd);
  float matV;
  float tv = marchCat(rol, rdl, 60., matV);
  // base + drifts
  float matB;
  float tPlane = rd.y < 0. ? -ro.y / rd.y : 1e4;
  float tb = marchBase(ro, rd, min(tv > 0. ? tv : 400., tPlane + .01), matB);

  vec3 col;
  float tHit;
  if (tb > 0.){
    tHit = tb;
    col = shadeBase(ro + rd * tb, rd, tb, matB, t, gust, false);
  } else if (tv > 0.){
    tHit = tv;
    col = shadeCat(ro, rd, rol, rdl, tv, matV, t, gust);
  } else if (rd.y < 0.){
    // flat plateau outside the base box: same snow shading
    tHit = tPlane;
    col = shadeBase(ro + rd * tPlane, rd, tPlane, MS_SNOW, t, gust, true);
  } else {
    tHit = 1e4;
    col = skyCol(rd, t, gust);
  }
  if (tHit < 1e3){
    float T = exp(-sig * tHit);
    col = col * T + fogC * (1. - T);
  }

  // lattice mast and guy wires against the sky, lit red by the beacon when it fires
  {
    float hgt;
    float cov = mastCover(uv, tHit, hgt);
    if (cov > 0.){
      float lit = gBI * (exp(-abs(hgt - MAST_H) * .35) * 1.2 + exp(-abs(hgt - 12.) * .5) * .6);
      vec3 mc = vec3(.004, .005, .007) + BCOL * lit * .5;
      float T = exp(-sig * proj(MAST).z);
      col = mix(col, mc * T + fogC * (1. - T), cov);
    }
  }

  // headlight cones (equi-angular samples around the lamp cluster)
  {
    vec3 cc = locToWorldP(vec3(0., 1.6, 15.));
    float r = 17.;
    vec3 oc = ro - cc; float b = dot(oc, rd); float h = b * b - dot(oc, oc) + r * r;
    if (h > 0.){
      h = sqrt(h);
      float t0 = max(-b - h, 0.), t1 = min(-b + h, tHit);
      if (t1 > t0){
        vec3 lc = locToWorldP(vec3(0., 1.8, 2.8));
        float D = dot(lc - ro, rd);
        float Dl = max(length(ro + rd * D - lc), .05);
        float ta = atan((t0 - D) / Dl), tb2 = atan((t1 - D) / Dl);
        const int NS = 8;
        vec3 acc = vec3(0.);
        for (int i = 0; i < NS; i++){
          float u = (float(i) + dither) / float(NS);
          float ts = D + Dl * tan(mix(ta, tb2, u));
          float w = (tb2 - ta) * (Dl * Dl + (ts - D) * (ts - D)) / Dl;
          vec3 x = ro + rd * ts;
          float nn = noise3(vec3(x.x * .25 + t * 1.8, x.y * .6, x.z * .25 + t * .3));
          float dens = (.35 + 1.5 * nn * nn) * (1. + 1.2 * exp(-x.y * 1.2));
          acc += lampsAt(x, vec3(0.), rd) * dens * exp(-sig * ts) * w;
        }
        col += acc / float(NS) * (.032 + .025 * gust);
      }
    }
  }

  // beacon: analytic single scattering halo in the haze + sprite
  if (gBI > .001){
    for (int k = 0; k < 2; k++){
      vec3 bp = k == 0 ? gB0 : gB1;
      float I = k == 0 ? 1. : .45;
      float D = dot(bp - ro, rd);
      float Dl = max(length(ro + rd * D - bp), .3);
      float t1 = min(tHit, 400.);
      float sc = (atan((t1 - D) / Dl) - atan(-D / Dl)) / Dl;
      col += BCOL * gBI * I * sc * .25 * (.6 + .4 * gust) * exp(-sig * max(D, 0.));
      vec3 sp = proj(bp);
      if (sp.z > 1. && sp.z < tHit + 1.){
        vec2 dv = uv - sp.xy; float r = length(dv);
        float px = 1. / iResolution.y;
        col += BCOL * gBI * I * (exp(-r * r / (px * px * 3.)) * 30. + .03 / (1. + pow(r * 60., 2.)) + exp(-abs(dv.y) * 1100.) * exp(-abs(dv.x) * 25.) * .4);
      }
    }
  }

  // tail light glare (facing us), small
  for (int k = 0; k < 2; k++){
    vec3 lp = k == 0 ? gTL0 : gTL1;
    vec3 sp = proj(lp);
    if (sp.z < .5) continue;
    float face = smoothstep(.1, .8, dot(-gFW, normalize(ro - lp)));
    vec2 dv = uv - sp.xy; float r = length(dv);
    col += TLCOL * face * (.02 / (1. + pow(r * 45., 2.)) + exp(-abs(dv.y) * 900.) * exp(-abs(dv.x) * 14.) * .08);
  }

  // blowing snow: world-anchored streak layers
  {
    float rh = length(rd.xz);
    float az = atan(rd.x, rd.z);
    float wind = 8. + 6. * gust;
    for (int i = 0; i < 6; i++){
      float fi = float(i);
      float d = .9 * pow(1.75, fi);
      float tl = d / rh;
      if (tl > tHit) break;
      vec3 P = ro + rd * tl;
      float cs = .08 * pow(d, .6);
      float L = wind * (1. / 48.) * .9;
      vec2 cell = vec2(2.4 * L + 3. * cs, cs);
      float fall = 1.1 + .25 * fi;
      vec2 c = vec2(az * d - t * wind, P.y + t * fall + fi * 3.7);
      c.y += c.x * fall / wind;
      c.y += .15 * sin(c.x * .6 + fi * 2.);
      vec2 g = c / cell; vec2 id = floor(g); vec2 f = fract(g) - .5;
      float hh = hash21(id + fi * 37.1);
      float dens = (.16 + .06 * fi + .35 * gust) * (1. + 1.2 * exp(-P.y * 1.5));
      if (hh < dens){
        vec2 o = (hash22(id + fi * 11.3) - .5) * vec2(cell.x - 2. * L, cell.y * .6);
        vec2 dd = f * cell - o;
        float px = tl / (gFocal * iResolution.y);
        float rr = .004 + .03 * smoothstep(1.6, .4, d);
        float Lk = L * (.45 + .8 * hash11(hh * 91.7));
        float sdd = length(vec2(max(abs(dd.x) - Lk, 0.), dd.y));
        float a = smoothstep(rr + 1.5 * px, rr * .3, sdd) * (rr + px) / (rr + px + Lk * .5);
        a *= 1. - .7 * pow(clamp(abs(dd.x) / (Lk + rr), 0., 1.), 2.);
        vec3 lit = vec3(.018, .022, .03) + lampsAt(P, vec3(0.), rd) * 1.3 + beaconAt(P, vec3(0.)) * .5;
        col += lit * a * (.9 + 1.6 * hh) * (d < 1.2 ? .45 : 1.);
      }
    }
  }
  return col;
}
