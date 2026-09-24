// s02_ice (12 s) — polar night blizzard on the plateau. A Tucker Sno-Cat emerges from the
// blowing snow, headlight cones first, and passes close by the low camera (~9.8 s); the camera
// pans to follow it and lets it go, tail lights receding into the spindrift.
//
// Approach (cheap 2.5D like the approved s10 exterior): analytic ground plane with sastrugi
// normals, analytic sky, the Sno-Cat raymarched only inside its bounding box, a few dithered
// volumetric samples for the headlight cones, and world-anchored layers of wind-driven snow streaks.
//
// uP[0] = gust (0..1), from shot.js so the post shake matches.

// ============================================================ sky ===
const vec3 SKYAMB = vec3(.010, .014, .024);
vec3 skyCol(vec3 rd, float t, float gust){
  float y = max(rd.y, 0.);
  vec3 c = mix(vec3(.004, .005, .009), vec3(.001, .0015, .003), smoothstep(0., .4, y));
  // spindrift veil drifting across the sky
  vec2 sp = rd.xz / (y + .08);
  float veil = fbm2(vec2(sp.x * .5 + t * .9, sp.y * .5 + t * .15) + 3.);
  float clear = smoothstep(.62, .3, veil) * (1. - .6 * gust);
  c += stars(rd) * vec3(.7, .8, 1.) * .5 * clear * smoothstep(.05, .2, y);
  // faint aurora curtain, partly veiled
  if (y > .01){
    vec2 ap = rd.xz / (y + .25);
    float w = ap.x * .45 + 1.3 * noise2(ap * .25 + vec2(t * .03, 0.)) + t * .02;
    float band = exp(-pow(ap.y - 1.6 - .5 * sin(w * 1.3), 2.) * 1.2);
    float rays = .55 + .45 * noise2(vec2(w * 9., t * .35));
    float hgt = smoothstep(.02, .18, y) * smoothstep(.75, .25, y);
    vec3 ac = mix(vec3(.05, .55, .28), vec3(.35, .12, .5), smoothstep(.15, .45, y));
    c += ac * band * rays * hgt * .07 * (.35 + .65 * clear);
  }
  // horizon lost in blowing snow
  c += vec3(.014, .019, .03) * exp(-y * 9.) * (1. + .6 * gust) * (.75 + .5 * veil);
  return c;
}

vec3 extraLight(vec3 p, vec3 n){ return vec3(0.); }

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
  for (int i = 0; i < 72; i++){
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
  vec3 env = skyCol(R, t, gust) * 4. + poolE * pow(max(dot(R, dp / dd), 0.), rough) * .6;
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
    col = inside * (1. - gf) + (skyCol(R, t, gust) * 3. + poolE * .15 * pow(max(dot(R, dp / dd), 0.), 8.)) * gf;
    col += vec3(.02, .025, .03) * smoothstep(.55, .75, noise3(pl * 18.)) * .3;   // frost on the glass
  }
  return col;
}
// <<< SNOCAT END

// ============================================================ vehicle path ===
vec3 vehPos(float t){ return vec3(-8.0 - .25 * sin(t * .4), 0., 50. - 5.1 * t); }

void vehicleState(float t){
  gV = vehPos(t);
  float hdg = PI + .03 * sin(t * .5);
  gF2 = vec2(sin(hdg), cos(hdg));
  gPitch = .022 * sin(t * 2.1) + .01 * sin(t * 5.3 + 1.);
  gRoll = .014 * sin(t * 1.7 + 1.);
  gRock = .05 * sin(t * 2.6);
  gMP = rot2(gPitch); gMR = rot2(gRoll);
}

// ============================================================ camera ===
vec3 gRo, gFw, gRt, gUp; float gFocal;
void setupCam(float t){
  gRo = vec3(0., .72 + .015 * sin(t * 1.3), 0.);
  float tl = t - .35;                              // the operator lags the vehicle a little
  tl = tl < 10.2 ? tl : 10.2 + .45 * (1. - exp(-(tl - 10.2) * 2.2));
  vec3 target = vehPos(tl) + vec3(0., 1.35, 0.);
  // start framed a little off the vehicle so the lights sit on the right third
  target.x += .9 * (1. - smoothstep(2., 8., t));
  vec3 f = normalize(target - gRo);
  // handheld drift
  float hx = (noise2(vec2(t * .7, 1.)) - .5) * .014, hy = (noise2(vec2(t * .6, 5.)) - .5) * .01;
  vec2 hz = normalize(f.xz); f = normalize(f + vec3(hz.y, 0., -hz.x) * hx + vec3(0., hy, 0.));
  gFw = f;
  gRt = normalize(cross(gFw, vec3(0., 1., 0.)));   // screen right (right-handed world)
  gUp = cross(gRt, gFw);
  gFocal = mix(2.5, 1.05, smoothstep(.5, 9.6, t));
}
vec3 camDir(vec2 uv){ return normalize(uv.x * gRt + uv.y * gUp + gFocal * gFw); }
vec3 proj(vec3 wp){ vec3 r = wp - gRo; float z = dot(r, gFw); return vec3(vec2(dot(r, gRt), dot(r, gUp)) / max(z, .001) * gFocal, z); }

// ============================================================ render ===
float fbm3o(vec2 p){ float a = .5, s = 0.; for (int i = 0; i < 3; i++){ s += a * noise2(p); p = p * 2.07 + 11.3; a *= .5; } return s; }

vec3 render(vec2 fc){
  float t = iTime;
  float gust = uP[0];
  vec2 uv = screenUV(fc);
  vehicleState(t);
  setupLights();
  setupCam(t);
  vec3 rd = camDir(uv);
  vec3 ro = gRo;
  float dither = hash31(vec3(fc, float(iFrame % 97) + .5));

  float sig = .022 + .03 * gust;       // extinction of the blizzard
  vec3 fogC = vec3(.012, .016, .026) * (1. + .5 * gust);

  // ---------------- vehicle
  vec3 rol = toLoc(ro - gV), rdl = toLoc(rd);
  float mat;
  float tGround = rd.y < 0. ? -ro.y / rd.y : 1e4;
  float tv = marchCat(rol, rdl, min(tGround, 200.), mat);
  float tHit = tv > 0. ? tv : tGround;

  vec3 col;
  if (tv > 0.){
    col = shadeCat(ro, rd, rol, rdl, tv, mat, t, gust);
    // blowing snow in front of it
    float T = exp(-sig * tv);
    col = col * T + fogC * (1. - T);
  } else if (rd.y < 0.){
    // ---------------- plateau snow
    vec3 p = ro + rd * tGround;
    float tg = tGround;
    vec2 sp = (rot2(.45) * p.xz) * vec2(.3, .8);
    float h0 = fbm3o(sp * .5);
    vec2 e = vec2(.08, 0.);
    float hx = fbm3o((sp + e.xy) * .5), hz = fbm3o((sp + e.yx) * .5);
    float bump = .9 * smoothstep(40., 3., tg);
    vec3 n = normalize(vec3(-(hx - h0) * 7. * bump, 1., -(hz - h0) * 7. * bump));
    // fresh track ruts behind the vehicle
    vec3 pl = toLoc(p - gV);
    float behind = step(pl.z, -2.2) * exp(max(-pl.z - 2.2, 0.) * -.03);
    float rut = smoothstep(.36, .18, abs(abs(pl.x) - 1.08)) * behind;
    float rutEdge = smoothstep(.1, .0, abs(abs(abs(pl.x) - 1.08) - .36)) * behind;
    n = normalize(n + vec3(0., 0., 0.) + toWld(vec3(sign(pl.x) * sign(abs(pl.x) - 1.08) * .5 * rutEdge, 0., 0.)));
    vec3 alb = vec3(.78, .83, .9) * (.9 + .15 * h0);
    // contact shadow under the vehicle
    float foot = sdBox2(pl.xz, vec2(1.35, 2.6));
    float occ = mix(.25, 1., smoothstep(-.3, 1.2, foot));
    vec3 E = SKYAMB * (1.2 + .5 * smoothstep(.35, .7, h0)) * occ;
    E += lampsAt(p, n, rd) * (1. - .5 * rut);
    col = alb * E * (1. - .35 * rut);
    // glitter in the beams
    float g = hash21(floor(p.xz * 40.));
    if (g > .996) col += lampsAt(p + vec3(0., .05, 0.), vec3(0., 1., 0.), rd) * .5 * hash11(g * 17. + floor(t * 12.)) * smoothstep(25., 3., tg);
    // low drifting snow snaking along the ground
    vec2 dq = rot2(.2) * p.xz;
    float drift = fbm3o(vec2(dq.x * .15 - t * 2.2, dq.y * .9 + .4 * sin(dq.x * .2 + t)));
    drift = smoothstep(.4, .85, drift) * (.5 + .7 * gust) * smoothstep(1.5, 5., tg);
    vec3 dl = SKYAMB * 1.5 + lampsAt(p + vec3(0., .25, 0.), vec3(0.), rd) * .5;
    col = mix(col, dl, drift * .35);
    float T = exp(-sig * tg);
    col = col * T + mix(fogC, skyCol(vec3(rd.x, .001, rd.z), t, gust), .6) * (1. - T);
  } else {
    col = skyCol(rd, t, gust);
  }

  // ---------------- headlight cones through the blowing snow
  // equi-angular sampling around the lamp cluster keeps 10 samples nearly noise free
  {
    vec3 cc = locToWorldP(vec3(0., 1.4, 12.));
    float r = 16.;
    vec3 oc = ro - cc; float b = dot(oc, rd); float h = b * b - dot(oc, oc) + r * r;
    if (h > 0.){
      h = sqrt(h);
      float t0 = max(-b - h, 0.), t1 = min(-b + h, tHit);
      if (t1 > t0){
        vec3 lc = locToWorldP(vec3(0., 1.8, 2.8));
        float D = dot(lc - ro, rd);
        float Dl = max(length(ro + rd * D - lc), .05);
        float ta = atan((t0 - D) / Dl), tb = atan((t1 - D) / Dl);
        const int NS = 16;
        vec3 acc = vec3(0.);
        for (int i = 0; i < NS; i++){
          float u = (float(i) + dither) / float(NS);
          float th = mix(ta, tb, u);
          float ts = D + Dl * tan(th);
          float w = (tb - ta) * (Dl * Dl + (ts - D) * (ts - D)) / Dl;   // 1/pdf
          vec3 x = ro + rd * ts;
          float nn = noise3(vec3(x.x * .22 + t * 2.6, x.y * .6, x.z * .22 + t * .4));
          float dens = .35 + 1.5 * nn * nn;
          dens *= 1. + 1.2 * exp(-x.y * 1.2);            // denser drift close to the ground
          acc += lampsAt(x, vec3(0.), rd) * dens * exp(-sig * ts) * w;
        }
        col += acc / float(NS) * (.013 + .016 * gust);
      }
    }
  }

  // ---------------- wind-driven snow: world-anchored layers at increasing depth
  {
    float rh = length(rd.xz);
    float az = atan(rd.x, rd.z);
    float wind = 12. + 7. * gust;
    for (int i = 0; i < 7; i++){
      float fi = float(i);
      float d = .8 * pow(1.7, fi);
      float tl = d / rh;
      if (tl > tHit) break;
      vec3 P = ro + rd * tl;
      float cs = .075 * pow(d, .6);
      float L = wind * (1. / 48.) * .9;                // half streak length (shutter + wind shear)
      vec2 cell = vec2(2.4 * L + 3. * cs, cs);
      float fall = 1.3 + .3 * fi;
      vec2 c = vec2(az * d - t * wind, P.y + t * fall + fi * 3.7);
      c = vec2(c.x, c.y + c.x * fall / wind);               // shear so streaks align with velocity
      c.y += .15 * sin(c.x * .6 + fi * 2.);           // eddies
      vec2 g = c / cell; vec2 id = floor(g); vec2 f = fract(g) - .5;
      float hh = hash21(id + fi * 37.1);
      float dens = (.24 + .35 * gust) * (1. + 1.4 * exp(-P.y * 1.5));
      if (hh < dens){
        vec2 o = (hash22(id + fi * 11.3) - .5) * vec2(cell.x - 2. * L, cell.y * .6);
        vec2 dd = f * cell - o;
        float px = tl / (gFocal * iResolution.y);      // one pixel in meters at this depth
        float rr = .004 + .03 * smoothstep(1.6, .4, d);  // defocus near the lens
        float Lk = L * (.45 + .8 * hash11(hh * 91.7));
        float sd = length(vec2(max(abs(dd.x) - Lk, 0.), dd.y));
        float a = smoothstep(rr + 1.5 * px, rr * .3, sd) * (rr + px) / (rr + px + Lk * .5);
        a *= 1. - .7 * pow(clamp(abs(dd.x) / (Lk + rr), 0., 1.), 2.);
        vec3 lit = vec3(.02, .024, .03) + lampsAt(P, vec3(0.), rd) * .6;
        col += lit * a * (.9 + 1.6 * hh) * (d < 1.2 ? .45 : 1.) * (1. - .85 * smoothstep(3., 12., d));
      }
    }
  }

  // ---------------- lamp glare (sprites for lamps too small to resolve + blooming halos)
  {
    vec3 V = ro;
    for (int k = 0; k < 8; k++){
      vec3 lp; vec3 ld; vec3 lc; float I;
      if (k < 2){ lp = k == 0 ? gHL0 : gHL1; ld = gHD; lc = HLCOL; I = 1.; }
      else if (k < 6){ float xo = k == 2 ? .7 : (k == 3 ? .28 : (k == 4 ? -.28 : -.7)); lp = locToWorldP(vec3(xo, 2.91, 1.21)); ld = gRD; lc = RLCOL; I = .6; }
      else { lp = k == 6 ? gTL0 : gTL1; ld = -gFW; lc = TLCOL; I = .35; }
      vec3 sp = proj(lp);
      if (sp.z < .3) continue;
      vec3 toC = normalize(V - lp);
      float face = dot(ld, toC);
      float beam = smoothstep(.55, .98, face);
      if (k >= 6) beam = smoothstep(.2, .9, face);
      if (beam <= 0.) continue;
      float occl = (tv > 0. && tv < sp.z - .25) ? .15 : 1.;
      vec2 dv = uv - sp.xy;
      float r = length(dv);
      float T = exp(-sig * sp.z * .7);
      float px = 1. / iResolution.y;
      float core = exp(-r * r / (px * px * 2.2)) * 3.5 * smoothstep(12., 40., sp.z);
      float halo = .045 / (1. + pow(r * 38., 2.)) + .012 * exp(-r * 7.);
      float streak = exp(-abs(dv.y) * 900.) * exp(-abs(dv.x) * 9.) * .25;
      float spikes = exp(-abs(dv.x + dv.y) * 1400.) * exp(-r * 18.) * .2 + exp(-abs(dv.x - dv.y) * 1400.) * exp(-r * 18.) * .2;
      col += lc * I * beam * T * (core * occl + (halo + streak + spikes) * (.5 + .5 * occl)) * (k < 6 ? (1. + 10. / (1. + sp.z * .6)) : 1.);
    }
  }
  return col;
}
