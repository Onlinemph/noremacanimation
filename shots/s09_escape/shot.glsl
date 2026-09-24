// s09_escape — the hangar and the way out.
//  0-5   high wide: dark hangar, sodium work lights; the Kharkovchanka's headlights blaze on,
//        exhaust smoke; the staff pour in through a side door as silhouettes.
//  5-11  low angle: it lurches forward, rams the sliding doors (8.0), they buckle and tear;
//        snow blasts in; from the rear platform a grenade is thrown back toward the fuel drums (9.5).
// 11-18  exterior: it rolls out onto the snow; 12.6 the hangar explodes (fireball, smoke, debris);
//        tail lights recede into the blizzard.
// Performance notes: SwiftShader cost is dominated by inlined code size, so the SDF is only
// referenced from three loops (march, normal, AO) and sdMonster from one loop inside it.

#define ZERO min(iFrame, 0)

#define H_FLOOR  20.
#define H_WALL   21.
#define H_CEIL   22.
#define H_TRUSS  23.
#define H_DOOR   24.
#define H_DRUM   25.
#define H_STAND  26.
#define H_LAMP   27.
#define H_TRACK  28.
#define H_BODY   29.
#define H_ROOF   30.
#define H_GLASS  31.
#define H_HEAD   32.
#define H_TAIL   33.
#define H_DARK   34.
#define H_SNOW   35.
#define H_BLDG   36.
#define H_CRATE  37.
#define H_FIG    38.
#define H_INNER  39.
#define H_GREN   40.

const float T_RAM = 8.0, T_EXT = 11.0, T_EXPL = 12.6, T_THROW = 9.45;
const vec3 SODIUM = vec3(1., .46, .12);

// ---------------------------------------------------------------- vehicle path
// returns xz position and heading yaw (heading = (sin yaw, cos yaw))
vec3 vehicle(float t){
  float z = 18., x = 0., yaw = 0.;
  if (t < 5.) { z = 18. + .02 * sin(t * 40.) * step(1., t); }
  else if (t < T_RAM) { float u = t - 5.; z = 18. + .5 * 3.94 * u * u; }
  else if (t < T_EXT) { float u = t - T_RAM; z = 35.75 + 5.2 * u - .45 * u * u + .12 * sin(u * 30.) * exp(-u * 6.); }
  else {
    float u = t - T_EXT;
    float s = 6.5 * u + .2 * u * u;
    float z0 = 35.75 + 5.2 * 3. - .45 * 9.;
    const float R = 22., PM = 1.2, S0 = 4.;
    if (s < S0) { z = z0 + s; }
    else {
      float ph = min((s - S0) / R, PM);
      x = R - R * cos(ph); z = z0 + S0 + R * sin(ph); yaw = ph;
      float rest = max(s - S0 - R * PM, 0.);
      x += rest * sin(PM); z += rest * cos(PM);
    }
  }
  return vec3(x, z, yaw);
}
float vehPitch(float t){
  // lurch at start and the jolt of the ram
  float p = -.05 * smoothstep(5., 5.3, t) * (1. - smoothstep(5.3, 6.2, t));
  p += .09 * exp(-max(t - T_RAM, 0.) * 5.) * step(T_RAM, t) * sin((t - T_RAM) * 25.);
  return p;
}

// ---------------------------------------------------------------- globals
vec3 gRo, gTa; float gFocal;
vec3 gVP; float gVYaw; float gVPitch;       // vehicle
vec3 gHL0, gHL1, gHDir;                     // headlights
float gHeadOn;
bool gExt;
vec3 gLamp[4]; vec3 gLampDir[4];

vec3 toVeh(vec3 p){
  vec3 q = p - gVP;
  q.xz *= rot2(-gVYaw);         // world -> local (heading -> +z)
  q.yz *= rot2(-gVPitch);
  return q;
}
vec3 vehToWorld(vec3 q){
  q.yz *= rot2(gVPitch);
  q.xz *= rot2(gVYaw);
  return q + gVP;
}

// ---------------------------------------------------------------- Kharkovchanka (local, +z forward)
// 8.5 m long, 4.3 m wide, ~4.5 m tall; bus-like cabin on two wide tracks.
vec2 sdTractor(vec3 p){
  float b = sdBox(p - vec3(0., 2.4, 0.), vec3(2.4, 2.6, 4.7));
  if (b > .6) return vec2(b, 0.);
  vec2 r = vec2(1e5, 0.);
  // tracks: pill-profile blocks with grousers, road wheels, fenders
  vec3 tq = vec3(abs(p.x) - 1.62, p.y - .66, p.z);
  float tr = sdRoundBox(tq, vec3(.52, .58, 3.95), .5);
  float gz = p.z + (gExt ? iTime * 7. : 0.);
  tr += .025 * smoothstep(.2, .8, abs(fract(gz * 3.) - .5) * 2.) * step(.3, abs(tq.y) + step(3.4, abs(p.z)));
  r = opU(r, vec2(tr, H_TRACK));
  float fender = sdBox(tq - vec3(0., .72, 0.), vec3(.6, .05, 4.05));
  // cabin
  vec3 cq = p - vec3(0., 2.78, -.15);
  float cab0 = sdRoundBox(cq, vec3(2.08, 1.42, 4.1), .22);
  // front: slightly raked windscreen
  cab0 = smax(cab0, dot(p - vec3(0., 3.2, 3.95), normalize(vec3(0., .32, 1.))), .15);
  // window recesses along the sides and in front
  vec3 wq = vec3(abs(p.x) - 2.1, p.y - 3.52, mod(p.z + .55, 1.1) - .55);
  float win = sdBox(wq, vec3(.08, .3, .4));
  win = max(win, abs(p.z + .3) - 3.3);
  float fwin = sdBox(vec3(abs(p.x) - .95, p.y - 3.55, p.z - 3.95), vec3(.78, .34, .3));
  float rec = min(win, fwin);
  float cab = max(cab0, -rec);
  r = opU(r, vec2(min(cab, fender), H_BODY));
  // glass set a little inside the recesses
  r = opU(r, vec2(max(rec, cab0 + .06), H_GLASS));
  // white roof cap + rack + exhaust stack + roof spots
  float roof = sdRoundBox(p - vec3(0., 4.28, -.3), vec3(1.95, .1, 3.7), .08);
  vec3 rq = vec3(p.x, p.y - 4.55, mod(p.z + .4, .8) - .4);
  float rack = sdBox(rq, vec3(1.7, .04, .03));
  rack = max(rack, abs(p.z + .6) - 3.);
  rack = min(rack, sdBox(vec3(abs(p.x) - 1.7, p.y - 4.55, p.z + .6), vec3(.04, .06, 3.)));
  r = opU(r, vec2(roof, H_ROOF));
  r = opU(r, vec2(min(rack, sdCylY(p - vec3(1.55, 4.9, -3.4), .09, .6)), H_DARK));
  // headlights: round lamps in housings on the nose, two spots on the roof
  vec3 hq = vec3(abs(p.x) - 1.35, p.y - 1.95, p.z - 4.05);
  float hh = sdCylZ(hq, .21, .12);
  r = opU(r, vec2(hh, H_DARK));
  r = opU(r, vec2(sdSphere(hq - vec3(0., 0., .02), .17), H_HEAD));
  vec3 sq = vec3(abs(p.x) - .7, p.y - 4.5, p.z - 3.2);
  r = opU(r, vec2(sdCylZ(sq, .13, .1), H_HEAD));
  // bumper + tow hooks
  r = opU(r, vec2(sdBox(p - vec3(0., 1.35, 4.18), vec3(2.05, .12, .1)), H_DARK));
  // rear platform with railing, tail lights
  r = opU(r, vec2(sdBox(p - vec3(0., 1.55, -4.55), vec3(1.7, .05, .42)), H_DARK));
  vec3 lq = vec3(abs(p.x) - 1.65, p.y - 2.05, p.z + 4.9);
  float rail = sdBox(lq, vec3(.025, .5, .025));
  rail = min(rail, sdBox(p - vec3(0., 2.55, -4.93), vec3(1.68, .025, .025)));
  r = opU(r, vec2(rail, H_DARK));
  r = opU(r, vec2(sdSphere(vec3(abs(p.x) - 1.9, p.y - 1.85, p.z + 4.25), .12), H_TAIL));
  // man on the rear platform (visible 5-11 s): throws a grenade back at T_THROW
  if (!gExt){
    vec3 fp = p - vec3(-.5, 1.6, -4.5);
    float th = smoothstep(T_THROW - .45, T_THROW, iTime) - smoothstep(T_THROW + .1, T_THROW + .8, iTime);
    float body = sdCapsule(fp, vec3(0., .85, 0.), vec3(0., 1.45, -.1 * th), .17);
    body = min(body, sdCapsule(fp, vec3(-.1, .05, 0.), vec3(-.08, .85, 0.), .09));
    body = min(body, sdCapsule(fp, vec3(.1, .05, 0.), vec3(.08, .85, 0.), .09));
    body = min(body, sdSphere(fp - vec3(0., 1.66, -.12 * th), .12));
    vec3 hand = mix(vec3(.25, 1.9, .35), vec3(.3, 1.8, -.6), th);        // wind up then throw back
    body = min(body, sdCapsule(fp, vec3(.2, 1.4, 0.), hand, .06));
    body = min(body, sdCapsule(fp, vec3(-.2, 1.4, 0.), vec3(-.45, 1.1, .2), .06));
    body = min(body, sdCapsule(fp, vec3(-.45, 1.1, .2), vec3(-.55, .95, .15), .05)); // holds the rail
    r = opU(r, vec2(body, H_FIG));
  }
  return r;
}

// ---------------------------------------------------------------- the staff
// cheap far LOD: hunched runner, feet at y=0 facing +z
vec2 sdRunnerLOD(vec3 p, float ph){
  vec3 hip = vec3(0., .92, 0.);
  vec3 ch = vec3(.05 * sin(ph), 1.38, .34);
  float d = sdTaper(p, hip, ch, .13, .17);
  d = min(d, sdSphere(p - vec3(.08 * sin(ph * .5), 1.5, .56), .11));
  for (int s = 0; s < 2; s++){
    float sg = s == 0 ? -1. : 1.;
    float a = ph + (s == 0 ? 0. : PI);
    vec3 foot = vec3(sg * .14, .08 + max(0., cos(a)) * .28, sin(a) * .5);
    vec3 knee = mix(hip, foot, .5) + vec3(0., .05, .18);
    d = min(d, sdCapsule(p, hip + vec3(sg * .1, 0., 0.), knee, .07));
    d = min(d, sdCapsule(p, knee, foot, .055));
    vec3 sh = ch + vec3(sg * .2, -.02, 0.);
    vec3 hand = sh + vec3(sg * .12, -.25 + .2 * sin(a + PI), .45 + .2 * sin(a + PI));
    d = min(d, sdCapsule(p, sh, hand, .045));
  }
  return vec2(d, M_CLOTH + .5 * step(.5, fract(ph * .1)));
}

const int NM = 7;
// per monster: xyz position, yaw ; w < -50 means not present
vec4 monState(int k, float t){
  float fk = float(k);
  float ts = 1.3 + .42 * fk + .15 * sin(fk * 3.);
  if (t < ts) return vec4(0., 0., 0., -99.);
  vec3 door = vec3(15.5, 0., 27.2 + .9 * sin(fk * 2.1));
  float lag = .35 + .5 * fk / float(NM);
  vec3 vv = vehicle(max(t - lag, 0.));
  vec3 off = vec3(-1.2 + 3.6 * hash11(fk + .3), 0., -5.4 - 1.6 * hash11(fk + 7.));
  if (t < 6.) off = vec3(2.8 + .7 * hash11(fk), 0., -3. + 6.5 * hash11(fk + 2.));   // swarm the flank while it idles
  vec3 target = vec3(vv.x, 0., vv.y) + off;
  vec3 dv = target - door;
  float dist = length(dv);
  float f = min(1., (t - ts) * 5.2 / max(dist, .01));
  vec3 pos = door + dv * f;
  vec3 dir = f < 1. ? dv / max(dist, .01) : vec3(sin(vv.z), 0., cos(vv.z));
  if (!gExt) pos.z = min(pos.z, 39.);
  return vec4(pos, atan(dir.x, dir.z));
}

// ---------------------------------------------------------------- hangar doors
float doorAngle(int s){
  float t = iTime;
  if (t < T_RAM) return 0.;
  vec3 v = vehicle(t);
  float zf = v.y + 4.25 - .3;
  float a = asin(clamp((zf - 39.8) / 8.4, 0., 1.));
  float fs = s == 0 ? 1. : 1.12;
  a = min(a * fs, 1.4) + .12 * sin((t - T_RAM) * 9. + float(s)) * exp(-(t - T_RAM) * 2.);
  return max(a, 0.);
}
vec2 sdDoors(vec3 p){
  float bb = sdBox(p - vec3(0., 6., 44.), vec3(9., 7., 5.));
  if (bb > .5) return vec2(bb, 0.);
  float d = 1e5;
  float tr = iTime - T_RAM;
  for (int s = 0; s < 2; s++){
    float sg = s == 0 ? -1. : 1.;
    vec3 q = p - vec3(0., 10., 40.);
    float th = doorAngle(s);
    q.yz *= rot2(-th);
    // twist: outer edge lags
    q.xy *= rot2(sg * .08 * smoothstep(0., .5, tr));
    // dent from the impact, centred low on the seam
    float dent = 1.3 * smoothstep(0., .18, tr) * exp(-(q.x * q.x) / 7. - (q.y + 7.6) * (q.y + 7.6) / 9.);
    q.z -= dent;
    q.z -= .05 * sin(q.x * 5.2);                           // corrugation
    float panel = sdBox(q - vec3(sg * 4.02, -5., -.15), vec3(3.98, 5., .1));
    // torn bottom edge after the ram
    panel = max(panel, -(q.y + 10.) - .0 + .5 * step(0., tr) * noise2(vec2(q.x * 2., 1.)));
    d = min(d, panel * .8);
  }
  return vec2(d, H_DOOR);
}

// ---------------------------------------------------------------- interior map
vec2 mapInt(vec3 p){
  vec2 r = vec2(1e5, 0.);
  // roof trusses every 5 m
  if (p.y > 9.6){
    vec3 q = p; q.z = mod(p.z, 5.) - 2.5;
    float tb = sdBox(q - vec3(0., 10.3, 0.), vec3(15., .13, .1));
    tb = min(tb, sdBox(q - vec3(0., 11.8, 0.), vec3(15., .13, .1)));
    vec2 dq = vec2(mod(p.x, 1.6) - .8, p.y - 11.05);
    dq.x = abs(dq.x);
    float diag = max(abs(dot(dq - vec2(.4, 0.), normalize(vec2(1.5, .8)))) - .05, abs(dq.y) - .75);
    tb = min(tb, max(diag, abs(q.z) - .06));
    // lengthwise purlins
    vec3 pq = p; pq.x = mod(p.x, 5.) - 2.5;
    tb = min(tb, sdBox(pq - vec3(0., 11.9, 20.), vec3(.08, .08, 20.)));
    r = opU(r, vec2(tb, H_TRUSS));
  } else r.x = min(r.x, 9.7 - p.y);

  // sodium work lights on tripods
  for (int i = ZERO; i < 4; i++){
    vec3 L = gLamp[i];
    vec3 base = vec3(L.x, 0., L.z);
    float bb = sdCapsule(p, base, L + vec3(0., .3, 0.), .9);
    if (bb > .4) { r.x = min(r.x, bb); continue; }
    vec3 q = p - base;
    float st = sdCapsule(q, vec3(0., 1.1, 0.), vec3(0., L.y - .15, 0.), .035);
    for (int k = 0; k < 3; k++){
      float a = float(k) * TAU / 3. + .5;
      st = min(st, sdCapsule(q, vec3(0., 1.1, 0.), vec3(cos(a) * .75, 0., sin(a) * .75), .025));
    }
    r = opU(r, vec2(st, H_STAND));
    // lamp head aimed along gLampDir
    vec3 hq = p - L;
    vec3 fw = gLampDir[i];
    vec3 rt = normalize(cross(fw, vec3(0., 1., 0.)));
    vec3 up = cross(rt, fw);
    vec3 lq = vec3(dot(hq, rt), dot(hq, up), dot(hq, fw));
    float head = sdRoundBox(lq, vec3(.28, .2, .14), .03);
    float face = sdBox(lq - vec3(0., 0., .15), vec3(.24, .16, .02));
    r = opU(r, vec2(head, H_STAND));
    r = opU(r, vec2(face, H_LAMP));
  }

  // fuel drums by the back wall (3x4 block, a few stacked on top)
  {
    vec3 c = vec3(-10.5, 0., 6.5);
    float bb = sdBox(p - c - vec3(0., .9, 0.), vec3(1.4, 1., 1.8));
    if (bb > .3) r.x = min(r.x, bb);
    else {
      vec3 q = p - c;
      vec2 id = clamp(floor(q.xz / .64 + .5), vec2(-1., -2.), vec2(1., 1.));
      vec3 lq = q - vec3(id.x * .64, 0., id.y * .64);
      float dr = sdCylY(lq - vec3(0., .45, 0.), .29, .45);
      dr -= .008 * smoothstep(.02, .0, abs(abs(lq.y - .45) - .15));
      float top = sdCylY(q - vec3(-.32, 1.36, -.32), .29, .45);
      top = min(top, sdCylY(q - vec3(.32, 1.36, .32), .29, .45));
      r = opU(r, vec2(min(dr, top), H_DRUM));
    }
  }
  // crates along the left wall
  {
    vec3 q = p - vec3(-13.4, 0., 20.);
    q.z = mod(q.z + 3., 6.) - 3.;
    float cr = sdBox(q - vec3(0., .6, 0.), vec3(.9, .6, 1.1));
    cr = min(cr, sdBox(q - vec3(.1, 1.55, -.3), vec3(.7, .35, .7)));
    cr = max(cr, abs(p.z - 20.) - 12.);
    r = opU(r, vec2(cr, H_CRATE));
  }
  // doors
  r = opU(r, sdDoors(p));
  // tractor
  vec3 vq = toVeh(p);
  r = opU(r, sdTractor(vq));
  // the grenade in flight
  if (iTime > T_THROW && iTime < T_THROW + 1.4){
    float u = iTime - T_THROW;
    vec3 g0 = vehToWorld(vec3(-.2, 3.4, -5.));
    vec3 g = g0 + vec3(-2.6, 3.5, -6.) * u + vec3(0., -4.9, 0.) * u * u;
    g.y = max(g.y, .08);
    r = opU(r, vec2(sdSphere(p - g, .07), H_GREN));
  }
  // the staff: one sdMonster call site inside one loop
  for (int k = ZERO; k < NM; k++){
    vec4 ms = monState(k, iTime);
    if (ms.w < -50.) continue;
    vec3 q = p - ms.xyz;
    q.xz *= rot2(-ms.w);
    float bb = sdCapsule(q, vec3(0., .3, 0.), vec3(0., 1.6, .3), .75);
    if (bb > .25) { r.x = min(r.x, bb); continue; }
    float ph = iTime * 7.5 + float(k) * 1.7;
    vec2 m;
    if (length(ms.xyz - gRo) > 13.) m = sdRunnerLOD(q, ph);
    else m = sdMonster(q, iTime + float(k) * .37 + .0173, fract(float(k) * .31 + .07), 1.);
    r = opU(r, m);
  }
  return r;
}

// ---------------------------------------------------------------- exterior map
vec3 fireC(){ float b = max(iTime - T_EXPL, 0.); return vec3(-3., 7. + 3.5 * b, 30.); }
float fireR(){ float b = max(iTime - T_EXPL, 0.); return 11. * (1. - exp(-b * 2.6)) + .1; }

vec2 mapExt(vec3 p){
  vec2 r = vec2(1e5, 0.);
  // hangar: hollow shell with an arched roof, door opening, snow drifts against it
  {
    float outer = max(sdBox(p - vec3(0., 7., 20.), vec3(15.4, 7., 20.4)), length(p.xy - vec2(0., -10.)) - 23.2);
    float inner = max(sdBox(p - vec3(0., 7., 20.), vec3(15., 7., 20.)), length(p.xy - vec2(0., -10.)) - 22.8);
    float bl = max(outer, -inner);
    bl = max(bl, -sdBox(p - vec3(0., 5., 40.4), vec3(8., 5., 1.)));      // torn door opening
    if (iTime > T_EXPL) bl = max(bl, -(length(p - fireC() + vec3(0., 2., 0.)) - fireR() * .75));  // roof blown out
    r = opU(r, vec2(bl, H_BLDG));
    // snow drifts banked against the walls
    float drift = sdEllipsoid(p - vec3(-16., 0., 20.), vec3(3., 2.2, 22.));
    drift = min(drift, sdEllipsoid(p - vec3(16., 0., 18.), vec3(3.2, 2.6, 22.)));
    drift = min(drift, sdEllipsoid(p - vec3(-13., 0., 41.), vec3(6., 2.8, 3.)));
    drift = min(drift, sdEllipsoid(p - vec3(13., 0., 41.), vec3(6., 3.2, 3.)));
    r = opU(r, vec2(drift, H_SNOW));
    // light mast with a sodium lamp
    r = opU(r, vec2(sdCapsule(p, vec3(19., 0., 44.), vec3(19., 8.2, 44.), .1), H_STAND));
    r = opU(r, vec2(sdBox(p - vec3(18.6, 8.2, 44.), vec3(.45, .15, .25)), H_LAMP));
  }
  // the staff in the lit doorway until the blast
  if (iTime < T_EXPL + .1){
    for (int k = ZERO; k < 3; k++){
      float fk = float(k);
      vec3 mp = vec3(-3.5 + fk * 3.2, 0., 37. + fk * 1.3 + (iTime - T_EXT) * (1.2 + fk * .3));
      vec3 q = p - mp;
      q.xz *= rot2(.3 * (fk - 1.));
      float bb = sdCapsule(q, vec3(0., .3, 0.), vec3(0., 1.6, .3), .7);
      if (bb > .2) { r.x = min(r.x, bb); continue; }
      r = opU(r, sdRunnerLOD(q, iTime * 7. + fk * 2.));
    }
  }
  // tractor
  r = opU(r, sdTractor(toVeh(p)));
  return r;
}

vec2 map(vec3 p){ return gExt ? mapExt(p) : mapInt(p); }

vec3 nrm(vec3 p, float e){
  vec3 n = vec3(0.);
  for (int i = ZERO; i < 4; i++){
    vec3 k = .5773 * (2. * vec3(float(((i + 3) >> 1) & 1), float((i >> 1) & 1), float(i & 1)) - 1.);
    n += k * map(p + k * e).x;
  }
  return normalize(n);
}
float calcAO(vec3 p, vec3 n){
  float o = 0., s = 1.;
  for (int i = ZERO; i < 2; i++){
    float h = .1 + .35 * float(i);
    o += (h - map(p + n * h).x) * s; s *= .55;
  }
  return clamp(1. - 1.6 * o, 0., 1.);
}

// analytic shadow of the tractor (oriented box) for a light
float tractorShadow(vec3 p, vec3 L, float maxT){
  vec3 ro = toVeh(p), rd = normalize(toVeh(p + L) - ro);
  vec3 bmin = vec3(-2.15, .1, -4.2), bmax = vec3(2.15, 4.3, 4.2);
  vec3 ta = (bmin - ro) / rd, tb = (bmax - ro) / rd;
  vec3 tn = min(ta, tb), tf = max(ta, tb);
  float t0 = max(max(tn.x, tn.y), tn.z), t1 = min(min(tf.x, tf.y), tf.z);
  return (t1 > max(t0, 0.) && t0 < maxT) ? .08 : 1.;
}

float scatterPoint(vec3 ro, vec3 rd, vec3 c, float tmax, float k){
  vec3 oc = c - ro;
  float b = dot(oc, rd);
  float h2 = max(dot(oc, oc) - b * b, 0.);
  float a = sqrt(1. / k + h2);
  return (atan((tmax - b) / a) - atan(-b / a)) / (k * a);
}

// ---------------------------------------------------------------- setup
void setup(){
  float t = iTime;
  gExt = t >= T_EXT;
  vec3 v = vehicle(t);
  gVP = vec3(v.x, 0., v.y);
  gVYaw = v.z;
  gVPitch = vehPitch(t);
  // idle shudder
  gVP.y += .015 * sin(t * 37.) * step(1., t) * step(t, 5.);
  gHeadOn = smoothstep(.85, .95, t) * (.6 + .4 * step(.3, noise2(vec2(t * 30., 1.)))) ;
  gHeadOn = t > 1.3 ? 1. : gHeadOn;
  gHL0 = vehToWorld(vec3(-1.35, 1.95, 4.2));
  gHL1 = vehToWorld(vec3(1.35, 1.95, 4.2));
  gHDir = normalize(vehToWorld(vec3(0., 1.7, 14.)) - vehToWorld(vec3(0., 1.95, 4.2)));

  gLamp[0] = vec3(11.5, 3.4, 26.5);  gLampDir[0] = normalize(vec3(-.6, -.55, -.1));   // by the side door
  gLamp[1] = vec3(-8., 3.4, 11.);    gLampDir[1] = normalize(vec3(-.3, -.6, -.4));    // over the drums
  gLamp[2] = vec3(6., 3.4, 11.5);    gLampDir[2] = normalize(vec3(-.4, -.6, .5));
  gLamp[3] = vec3(-6.5, 3.4, 35.5);  gLampDir[3] = normalize(vec3(.5, -.6, .1));      // by the main doors

  if (t < 5.){
    // high wide from the back corner, slow drift
    float k = t / 5.;
    gRo = vec3(-13.2 + .8 * k, 10.6 - .3 * k, 2.2 + .6 * k);
    gTa = vec3(3.5, 1.2, 24.5 + 1. * k);
    gFocal = 1.25;
  } else if (!gExt){
    // low angle beside the tractor's path, panning with it toward the doors
    float k = smoothstep(5., 11., t);
    gRo = vec3(-8.6, .55, 30.2);
    float vz = vehicle(t).y;
    gTa = vec3(0., 2.9 + .8 * smoothstep(8., 9.5, t), clamp(vz + 1.5, 20., 41.));
    // swing back to catch the throw
    gTa = mix(gTa, vec3(-3.5, 3.2, 31.), smoothstep(9.1, 9.9, t) * .75);
    gFocal = 1.05;
  } else {
    // exterior: outside in the blizzard, looking back at the hangar
    float k = smoothstep(T_EXT, 18., t);
    gRo = vec3(-26. + 1.5 * k, 2.3, 62. + 2. * k);
    vec3 vp = gVP + vec3(0., 2., 0.);
    vec3 a = vec3(2., 5., 44.);
    gTa = mix(a, mix(vec3(-1., 6., 36.), vp, .62), smoothstep(T_EXT + .3, 15.5, t));
    gFocal = 1.12;
  }
  // handheld noise
  vec3 hh = vec3(noise2(vec2(t * .8, 1.)), noise2(vec2(t * .7, 5.)), noise2(vec2(t * .9, 9.))) - .5;
  gTa += hh * (gExt ? .5 : .3);
}

// ---------------------------------------------------------------- materials
vec3 texStencil(vec2 uv){ return texture(iTex0, uv).rgb; }

vec3 bodyPaint(vec3 q, vec3 n){
  // orange-red enamel, grime, frost and scratches
  vec3 c = vec3(.5, .09, .035);
  float g = fbm3lo(q * 1.3);
  c = mix(c, vec3(.2, .05, .03), smoothstep(.45, .8, g) * .6);
  c = mix(c, vec3(.06, .045, .04), smoothstep(1.6, .8, q.y) * .5);          // road grime low down
  c = mix(c, vec3(.55, .58, .6), smoothstep(.62, .78, fbm3lo(q * 3. + 5.)) * .5 * max(n.y, .2));  // frost
  // white stripe band below the windows
  c = mix(c, vec3(.62, .6, .55), step(abs(q.y - 2.95), .07) * step(abs(q.x), 2.2));
  return c;
}

struct Surf { vec3 alb; float spk; float gloss; vec3 emi; };

Surf material(float m, vec3 p, vec3 n){
  Surf s; s.alb = vec3(.1); s.spk = .1; s.gloss = 20.; s.emi = vec3(0.);
  if (m == H_FLOOR){
    float g = fbm3lo(p * .35);
    s.alb = mix(vec3(.2, .19, .17), vec3(.1, .1, .1), g);
    s.alb *= .8 + .35 * noise3(p * 3.);
    float slab = smoothstep(.02, .0, min(abs(fract(p.x / 4.) - .5), abs(fract(p.z / 4.) - .5)) - .49);
    s.alb *= 1. - .4 * slab;
    float oil = smoothstep(.55, .7, fbm3lo(p * .6 + 3.));
    s.alb = mix(s.alb, vec3(.03, .03, .03), oil * .8);
    float ice = smoothstep(.5, .7, fbm3lo(p * .4 + 11.));
    s.spk = .25 + 1.5 * oil + ice; s.gloss = mix(20., 120., max(oil, ice));
    // tread marks of the tractor
    float tm = smoothstep(.45, .3, abs(abs(p.x) - 1.62)) * step(p.z, 40.) * step(10., p.z);
    s.alb *= 1. - .35 * tm * (.5 + .5 * sin(p.z * 18.));
  } else if (m == H_WALL){
    float cor = .5 + .5 * sin((abs(p.x) > 14.9 ? p.z : p.x) * 9.);
    s.alb = mix(vec3(.13, .15, .14), vec3(.08, .09, .085), fbm3lo(p * .5)) * (.8 + .3 * cor);
    s.alb = mix(s.alb, vec3(.14, .13, .12), step(p.y, 1.2));
    s.alb *= .7 + .5 * noise3(p * vec3(.3, 2., .3));      // streaks of rust and damp
    s.spk = .25 * cor; s.gloss = 30.;
    if (p.z > 39.9){
      // stencils above the doors: АНГАР 9 / ОПАСНО
      vec2 uv = vec2((10. - p.x) / 20., (p.y - 10.) / 2.);
      if (uv.x > 0. && uv.x < 1. && uv.y > 0. && uv.y < 1.){
        vec4 tx = texture(iTex0, uv * vec2(1., .5) + vec2(0., .5));
        s.alb = mix(s.alb, tx.rgb, tx.a);
      }
    }
  } else if (m == H_CEIL){
    s.alb = vec3(.05);
  } else if (m == H_TRUSS || m == H_STAND || m == H_DARK){
    s.alb = vec3(.07, .07, .075) * (.7 + .5 * noise3(p * 4.)); s.spk = .5; s.gloss = 40.;
  } else if (m == H_LAMP){
    s.alb = vec3(.1); s.emi = SODIUM * 9.;
  } else if (m == H_DOOR){
    s.alb = mix(vec3(.16, .17, .15), vec3(.09, .1, .09), fbm3lo(p * .6));
    s.alb *= .75 + .4 * (.5 + .5 * sin(p.x * 10.4));
    s.spk = .5; s.gloss = 35.;
    vec2 uv = vec2(fract((8. - p.x) / 16.), (p.y - 3.) / 4.);
    if (uv.y > 0. && uv.y < 1. && abs(p.x) < 7.5 && iTime < T_RAM){
      vec4 tx = texture(iTex0, uv * vec2(1., .5));
      s.alb = mix(s.alb, tx.rgb, tx.a);
    }
  } else if (m == H_DRUM){
    vec2 id = floor((p.xz - vec2(-10.5, 6.5)) / .64 + .5);
    float h = hash21(id + floor(p.y / .92));
    s.alb = h < .5 ? vec3(.35, .06, .04) : (h < .8 ? vec3(.12, .16, .08) : vec3(.08, .1, .18));
    s.alb = mix(s.alb, vec3(.18, .09, .04), smoothstep(.55, .75, fbm3lo(p * 6.)));
    s.spk = .6; s.gloss = 40.;
  } else if (m == H_CRATE){
    s.alb = mix(vec3(.16, .17, .1), vec3(.09, .1, .06), fbm3lo(p * 2.)); s.spk = .05;
  } else if (m == H_TRACK){
    s.alb = vec3(.035, .035, .038) * (.7 + .6 * noise3(p * 6.)); s.spk = .4; s.gloss = 30.;
    // road wheels showing on the outer face
    vec3 q = toVeh(p);
    vec2 w = vec2(mod(q.z + .5, 1.) - .5, q.y - .55);
    if (abs(q.x) > 2.05) s.alb += vec3(.05) * smoothstep(.34, .3, length(w)) * smoothstep(.1, .14, length(w));
  } else if (m == H_BODY){
    vec3 q = toVeh(p);
    s.alb = bodyPaint(q, n); s.spk = .7; s.gloss = 60.;
  } else if (m == H_ROOF){
    s.alb = vec3(.62, .62, .6) * (.8 + .3 * fbm3lo(p * 3.)); s.spk = .4; s.gloss = 40.;
  } else if (m == H_GLASS){
    vec3 q = toVeh(p);
    s.alb = vec3(.01); s.spk = 2.; s.gloss = 200.;
    s.emi = vec3(.35, .22, .1) * .12 * (.5 + noise3(q * 2.));             // dim cab light inside
  } else if (m == H_HEAD){
    s.alb = vec3(.2); s.emi = vec3(1., .92, .75) * 16. * gHeadOn + vec3(.02);
  } else if (m == H_TAIL){
    s.alb = vec3(.1); s.emi = vec3(1., .06, .03) * 7.;
  } else if (m == H_FIG){
    s.alb = vec3(.05, .055, .05); s.spk = .1;
  } else if (m == H_GREN){
    s.alb = vec3(.1, .12, .08); s.spk = 3.; s.gloss = 80.;
  } else if (m == H_SNOW || m == H_BLDG){
    float fr = m == H_SNOW ? 1. : smoothstep(.3, .9, n.y) * .8 + .15 * smoothstep(.5, .7, fbm3lo(p * .8));
    vec3 steel = vec3(.1, .11, .11) * (.7 + .4 * (.5 + .5 * sin(p.x * 6. + p.z * 6.)));
    s.alb = mix(steel, vec3(.7, .75, .82), fr);
    s.spk = .3; s.gloss = 25.;
  } else if (m == H_INNER){
    s.alb = vec3(.1);
  } else if (m <= 4.5){
    s.alb = monsterAlbedo(m, p) * .8; s.spk = monsterSpec(m); s.gloss = 40.;
  }
  return s;
}

// ---------------------------------------------------------------- interior lighting
vec3 lightInt(vec3 p, vec3 n, vec3 rd, Surf s, bool isVeh){
  vec3 col = vec3(0.);
  vec3 V = -rd;
  for (int i = 0; i < 4; i++){
    vec3 L = gLamp[i] - p; float d = length(L); L /= d;
    float cone = smoothstep(-.1, .55, dot(-L, gLampDir[i]));
    float at = 26. * cone / (1. + d * d * 1.1);
    if (at < .002) continue;
    float sh = isVeh ? 1. : tractorShadow(p, L * d, d);
    float ndl = max(dot(n, L), 0.);
    vec3 H = normalize(L + V);
    float sp = pow(max(dot(n, H), 0.), s.gloss) * s.spk * (s.gloss * .03 + .4);
    col += SODIUM * at * sh * (s.alb * ndl + sp);
  }
  // headlights
  if (gHeadOn > 0.){
    for (int j = 0; j < 2; j++){
      vec3 hp = j == 0 ? gHL0 : gHL1;
      vec3 L = hp - p; float d = length(L); L /= d;
      float cone = smoothstep(.78, .95, dot(-L, gHDir));
      float at = 90. * cone * gHeadOn / (1. + d * d * .6);
      if (dot(p - hp, gHDir) < .1) at = 0.;
      vec3 H = normalize(L + V);
      col += vec3(1., .93, .8) * at * (s.alb * max(dot(n, L), 0.) + pow(max(dot(n, H), 0.), s.gloss) * s.spk * (s.gloss * .03 + .4));
    }
  }
  // red emergency light in the corridor beyond the side door
  {
    vec3 L = vec3(17., 2.2, 28.) - p; float d = length(L); L /= d;
    col += vec3(1., .08, .04) * 2.5 / (1. + d * d * .5) * s.alb * max(dot(n, L), 0.);
  }
  // exterior: cold night light spilling through the torn doors
  float open = smoothstep(T_RAM, T_RAM + .6, iTime);
  if (open > 0.){
    vec3 L = vec3(clamp(p.x, -7., 7.), 5., 41.) - p; float d = length(L); L /= d;
    col += vec3(.25, .35, .55) * open * .6 / (1. + d * d * .05) * s.alb * max(dot(n, L), 0.);
  }
  col += s.alb * vec3(.004, .005, .007);
  return col + s.emi;
}

// ---------------------------------------------------------------- exterior lighting
float fireFlick(){ return .85 + .3 * noise2(vec2(iTime * 9., 3.)); }
float fireHeat(){
  float b = iTime - T_EXPL;
  if (b < 0.) return 0.;
  return (6. * exp(-b * 3.) + 1.2 * exp(-b * .25)) * smoothstep(0., .06, b);
}
vec3 lightExt(vec3 p, vec3 n, vec3 rd, Surf s){
  vec3 col = vec3(0.);
  vec3 V = -rd;
  // explosion / fire
  float heat = fireHeat();
  if (heat > 0.){
    vec3 fc = fireC() - vec3(0., 3., 0.);
    vec3 L = fc - p; float d = length(L); L /= d;
    float at = 2600. * heat * fireFlick() / (d * d + 60.);
    vec3 H = normalize(L + V);
    col += vec3(1., .45, .14) * at * (s.alb * max(dot(n, L), 0.) + pow(max(dot(n, H), 0.), s.gloss) * s.spk * .4);
  }
  // interior glow through the doorway before the blast
  {
    vec3 L = vec3(0., 4., 37.5) - p; float d = length(L); L /= d;
    float facing = smoothstep(-.2, .4, (p.z - 38.) / max(d, .1));
    float at = 40. * facing / (1. + d * d * .35) * (1. - smoothstep(T_EXPL, T_EXPL + .3, iTime));
    col += SODIUM * at * s.alb * max(dot(n, L), 0.);
  }
  // mast lamp
  {
    vec3 L = vec3(18.6, 8.0, 44.) - p; float d = length(L); L /= d;
    float at = 60. * smoothstep(.1, .6, L.y) / (1. + d * d * .6);
    col += SODIUM * at * (s.alb * max(dot(n, L), 0.) + pow(max(dot(n, normalize(L + V)), 0.), s.gloss) * s.spk * .3);
  }
  // headlights (forward) and tail lights (small red pools)
  for (int j = 0; j < 2; j++){
    vec3 hp = j == 0 ? gHL0 : gHL1;
    vec3 L = hp - p; float d = length(L); L /= d;
    float cone = smoothstep(.8, .95, dot(-L, gHDir));
    col += vec3(1., .93, .8) * 90. * cone / (1. + d * d * .6) * s.alb * max(dot(n, L), 0.);
    vec3 tp = vehToWorld(vec3(j == 0 ? -1.9 : 1.9, 1.85, -4.4));
    vec3 Lt = tp - p; float dt = length(Lt); Lt /= dt;
    col += vec3(1., .05, .03) * 1.2 / (1. + dt * dt * 1.5) * s.alb * max(dot(n, Lt), 0.);
  }
  // cold sky
  col += s.alb * vec3(.012, .016, .026) * (.5 + .5 * n.y);
  return col + s.emi;
}

// ---------------------------------------------------------------- volumetrics
vec3 fireball(vec3 ro, vec3 rd, float tmax, float dither, out float trans){
  trans = 1.;
  float b = iTime - T_EXPL;
  if (b < 0.) return vec3(0.);
  vec3 C = fireC();
  float R = fireR();
  // one bounding sphere around fireball + smoke column
  vec3 Cb = C + vec3(0., R * .8, 0.);
  float Rb = R * 2.1 + 2.;
  vec3 oc = ro - Cb;
  float bb = dot(oc, rd), cc = dot(oc, oc) - Rb * Rb;
  float disc = bb * bb - cc;
  if (disc < 0.) return vec3(0.);
  float sq = sqrt(disc);
  float t0 = max(-bb - sq, 0.), t1 = min(-bb + sq, tmax);
  if (t1 <= t0) return vec3(0.);
  vec3 col = vec3(0.);
  const int NS = 18;
  float dt = (t1 - t0) / float(NS);
  float heat = fireHeat();
  for (int i = ZERO; i < NS; i++){
    float ts = t0 + (float(i) + dither) * dt;
    vec3 p = ro + rd * ts;
    vec3 q = (p - C) / R;
    float n = fbm3lo(q * 2.2 + vec3(0., -b * .6, b * .2));
    // fire core (sphere) and smoke column above it
    float rf = length(q * vec3(1., 1.15, 1.));
    float fireD = smoothstep(.15, .0, rf - 1. + (n - .5) * 1.1);
    vec3 sq2 = q - vec3(.25 * q.y * q.y * .2, 1.25, 0.);
    float rs = length(sq2 * vec3(.75, .6, .75));
    float smokeD = smoothstep(.2, 0., rs - 1. + (n - .5) * 1.3) * smoothstep(.2, .9, q.y + .2);
    float dens = fireD * 1.4 + smokeD * 1.1;
    if (dens < .01) continue;
    // temperature: hottest in the core early, cooling outward and with time
    float temp = clamp((1. - rf) * 1.6 + (n - .5) * 1.2, 0., 1.) * fireD * clamp(heat / 3., .12, 1.);
    vec3 fcol = mix(vec3(.9, .12, .02), vec3(2., .9, .25), smoothstep(.1, .5, temp));
    fcol = mix(fcol, vec3(4., 3., 1.8), smoothstep(.55, .95, temp));
    vec3 em = fcol * temp * temp * 22. * (.5 + heat * .25);
    // smoke lit from below by the fire
    vec3 smokeC = vec3(.012, .01, .009) + vec3(.6, .22, .06) * .14 * exp(-max(q.y - .6, 0.) * 2.) * heat;
    float a = 1. - exp(-dens * dt / R * 5.);
    col += trans * (em * dt / R * 4. + smokeC * a);
    trans *= 1. - a;
    if (trans < .03) break;
  }
  return col;
}

// debris & embers
vec3 debris(vec3 ro, vec3 rd, float tmax){
  float b = iTime - T_EXPL;
  if (b < 0. || b > 5.) return vec3(0.);
  vec3 col = vec3(0.);
  vec3 C = fireC() - vec3(0., 1., 0.);
  for (int k = ZERO; k < 36; k++){
    float fk = float(k);
    vec3 h = hash33(vec3(fk, 3.1, 7.7));
    vec3 v = normalize(vec3(h.x - .5, .4 + h.y, h.z - .45)) * (12. + 22. * h.z);
    float tb = b;
    vec3 p = C + v * tb + vec3(0., -9.8, 0.) * tb * tb * .5;
    if (p.y < 0.) continue;
    vec3 op = p - ro;
    float tp = dot(op, rd);
    if (tp < 0. || tp > tmax) continue;
    float d = length(op - rd * tp);
    bool ember = k < 24;
    float sz = (ember ? .08 : .25 + .3 * h.x) * (1. + tp * .004);
    float m = smoothstep(sz, sz * .3, d);
    if (ember) col += vec3(3., 1.1, .3) * m * exp(-b * .6);
    else col += vec3(-.2) * m;          // dark chunks cut into the glow
  }
  return col;
}

// blizzard: layered screen-space flakes streaking with the wind
vec3 flakes(vec2 fc, float dens, vec3 tint){
  vec2 uv = fc / iResolution.y;
  vec3 col = vec3(0.);
  for (int l = ZERO; l < 3; l++){
    float fl = float(l);
    float sc = 18. + fl * 16.;
    vec2 q = uv * sc + vec2(iTime * (9. - fl * 2.), iTime * (2.5 - fl * .5)) * (1.4 - fl * .3);
    vec2 id = floor(q);
    vec2 f = fract(q) - .5;
    vec2 o = hash22(id + fl * 17.) - .5;
    vec2 dd = f - o * .7;
    dd.x *= .35;                               // horizontal motion streak
    float r = .06 + .05 * hash21(id + 3.);
    col += tint * smoothstep(r, 0., length(dd)) * step(.35, hash21(id + fl * 31.)) * (1. - fl * .25);
  }
  return col * dens;
}

// ---------------------------------------------------------------- render
vec3 render(vec2 fc){
  setup();
  vec3 ro = gRo;
  vec3 rd = camRay(fc, ro, gTa, gFocal, gExt ? .0 : .015 * sin(iTime * .7));
  float dither = hash21(fc + fract(iTime * 7.13) * 100.);
  float t = iTime;
  vec3 col = vec3(0.);

  if (!gExt){
    // ---------------- interior: analytic hangar box + SDF contents
    vec3 bmin = vec3(-15., 0., 0.), bmax = vec3(15., 12., 40.);
    vec3 tb = (mix(bmin, bmax, step(0., rd)) - ro) / rd;
    float tRoom = min(min(tb.x, tb.y), tb.z);
    vec3 nRoom; float mRoom = H_WALL;
    if (tRoom == tb.y){ nRoom = vec3(0., -sign(rd.y), 0.); mRoom = rd.y < 0. ? H_FLOOR : H_CEIL; }
    else if (tRoom == tb.x) nRoom = vec3(-sign(rd.x), 0., 0.);
    else nRoom = vec3(0., 0., -sign(rd.z));
    vec3 pr = ro + rd * tRoom;
    bool outside = tRoom == tb.z && rd.z > 0. && abs(pr.x) < 8. && pr.y < 10.;
    bool sideDoor = tRoom == tb.x && rd.x > 0. && abs(pr.z - 27.8) < 1.6 && pr.y < 3.4;
    float tMax = outside ? tRoom + 30. : tRoom;

    float d = .1; vec2 h = vec2(0.); bool hit = false;
    for (int i = 0; i < 110; i++){
      vec3 p = ro + rd * d;
      h = map(p);
      if (h.x < .002 * d) { hit = true; break; }
      d += h.x * .85;
      if (d > tMax) break;
    }
    vec3 p, n;
    if (hit){
      p = ro + rd * d;
      n = nrm(p, .002 * d);
    } else {
      d = tRoom; p = pr; n = nRoom; h = vec2(0., mRoom);
    }
    if (!hit && outside){
      // the night beyond the torn doors: blowing snow, dark blue
      float g = fbm3lo(vec3(fc / iResolution.y * 3. + vec2(t * 2., 0.), t * .5));
      col = vec3(.02, .03, .05) * (.6 + .8 * g);
      // headlights hit the snow haze outside
      float hb = smoothstep(.8, .97, dot(normalize(p - gHL0), gHDir));
      col += vec3(.5, .5, .45) * hb * gHeadOn * .15 * (.5 + g);
      d = tRoom + 8.;
    } else if (!hit && sideDoor){
      col = vec3(.25, .02, .01) * (.4 + .6 * smoothstep(3.4, 0., pr.y)) * (.8 + .2 * noise2(vec2(t * 13., 1.)));
    } else {
      Surf s = material(h.y, p, n);
      bool isVeh = h.y >= H_TRACK && h.y <= H_TAIL;
      col = lightInt(p, n, rd, s, isVeh);
      col *= mix(.25, 1., calcAO(p, n));
    }
    // distance falloff into darkness
    col *= exp(-max(d - 12., 0.) * .03);

    // ---- volumetric light: halos around the sodium lamps, headlight beams, exhaust smoke
    float tv = min(d, 60.);
    vec3 vol = vec3(0.);
    for (int i = 0; i < 4; i++){
      vol += SODIUM * scatterPoint(ro, rd, gLamp[i] + gLampDir[i] * .5, tv, 1.2) * .06;
    }
    if (gHeadOn > 0.){
      vec3 beam = vec3(0.);
      for (int i = ZERO; i < 8; i++){
        float ts = (float(i) + dither) / 8. * min(tv, 45.);
        vec3 sp = ro + rd * ts;
        for (int j = 0; j < 2; j++){
          vec3 hp = j == 0 ? gHL0 : gHL1;
          vec3 L = sp - hp; float ld = length(L);
          float cn = smoothstep(.85, .97, dot(L / ld, gHDir)) * step(0., dot(L, gHDir));
          beam += vec3(1., .93, .8) * cn / (1. + ld * ld * .03) * (.5 + noise3(sp * .5 + vec3(0., t * .3, 0.)));
        }
      }
      vol += beam * min(tv, 45.) / 8. * .012 * gHeadOn;
    }
    // exhaust: puffs from the stack, heavy when it lights up and when it lurches
    {
      vec3 st = vehToWorld(vec3(1.55, 5.5, -3.4));
      float amt = .4 + 1.6 * exp(-max(t - 1., 0.) * 1.5) * step(.9, t) + 1.2 * exp(-max(t - 5., 0.) * 1.2) * step(5., t);
      vec3 sc = st + vec3(0., 2.2, -1.);
      vec3 oc = ro - sc;
      float bb = dot(oc, rd), cc = dot(oc, oc) - 9.;
      float disc = bb * bb - cc;
      if (disc > 0.){
        float sq = sqrt(disc);
        float s0 = max(-bb - sq, 0.), s1 = min(-bb + sq, d);
        float T = 1.;
        vec3 sm = vec3(0.);
        for (int i = ZERO; i < 6; i++){
          float ts = s0 + (float(i) + dither) / 6. * (s1 - s0);
          vec3 q = ro + rd * ts - sc;
          float dn = smoothstep(3., .5, length(q * vec3(1., .8, 1.))) * fbm3lo(q * .8 + vec3(0., -t * 1.5, 0.)) * amt;
          float a = 1. - exp(-dn * (s1 - s0) / 6. * 1.2);
          vec3 lit = SODIUM * .08 + vec3(.9, .85, .7) * .15 * gHeadOn * smoothstep(3., 0., length(q));
          sm += T * a * lit * .5;
          T *= 1. - a;
        }
        col = col * T + sm;
      }
    }
    col += vol;
    // snow blasting in through the torn doors
    float open = smoothstep(T_RAM, T_RAM + .4, t);
    if (open > 0.){
      vec3 sn = vec3(0.);
      for (int i = ZERO; i < 6; i++){
        float ts = (float(i) + dither) / 6. * min(d, 30.);
        vec3 sp = ro + rd * ts;
        float inDoor = smoothstep(18., 36., sp.z) * smoothstep(12., 5., abs(sp.x)) * smoothstep(11., 3., sp.y);
        float dn = noise3(sp * vec3(.8, .8, .12) + vec3(0., t * 2., t * 3.2)) * inDoor;
        float lit = .15 + 2. * gHeadOn * smoothstep(.8, .95, dot(normalize(sp - gHL1), gHDir));
        sn += vec3(.6, .7, .85) * dn * lit;
      }
      col += sn * min(d, 30.) / 6. * .03 * open;
      col += flakes(fc, open * .35, vec3(.5, .55, .65));
    }
  } else {
    // ---------------- exterior
    float tg = rd.y < 0. ? -ro.y / rd.y : 1e5;
    float d = .5; vec2 h = vec2(0.); bool hit = false;
    float tMax = min(tg, 160.);
    for (int i = 0; i < 100; i++){
      vec3 p = ro + rd * d;
      h = map(p);
      if (h.x < .003 * d) { hit = true; break; }
      d += h.x * .9;
      if (d > tMax) break;
    }
    vec3 p, n;
    vec3 fogCol = vec3(.012, .016, .026);
    if (hit){
      p = ro + rd * d;
      n = nrm(p, .003 * d);
      Surf s = material(h.y, p, n);
      // interior of the hangar seen through the opening: warm, then burning
      if (h.y == H_BLDG && p.z < 40.05 && abs(p.x) < 15. && p.y < 12.4 && dot(n, vec3(0., 0., 1.)) < .5 && length(p - vec3(0., 5., 40.)) < 30.){
        s.emi += SODIUM * .08 * (1. - smoothstep(T_EXPL, T_EXPL + .2, t)) + vec3(1.5, .5, .12) * fireHeat() * .15 * fireFlick();
      }
      col = lightExt(p, n, rd, s);
      col *= mix(.4, 1., calcAO(p, n));
    } else if (rd.y < 0.){
      d = tg;
      p = ro + rd * d;
      // snow ground with sastrugi
      float h0 = fbm3lo(vec3(p.xz * vec2(.25, .8), 0.));
      float hx = fbm3lo(vec3((p.xz + vec2(.15, 0.)) * vec2(.25, .8), 0.));
      float hz = fbm3lo(vec3((p.xz + vec2(0., .15)) * vec2(.25, .8), 0.));
      n = normalize(vec3(-(hx - h0) * 3., 1., -(hz - h0) * 3.));
      Surf s; s.alb = vec3(.72, .77, .85); s.spk = .25; s.gloss = 18.; s.emi = vec3(0.);
      // tracks behind the tractor
      vec3 vq = toVeh(p);
      float rut = smoothstep(.55, .25, abs(abs(vq.x) - 1.62)) * step(vq.z, 0.) * step(p.z, 200.);
      s.alb *= 1. - .45 * rut * smoothstep(-60., -2., vq.z);
      col = lightExt(p, n, rd, s);
      float gl = step(.996, hash21(floor(p.xz * 22.)));
      col += gl * fireHeat() * .5 * vec3(1., .6, .3) * smoothstep(80., 10., d);
    } else {
      d = 400.;
      col = mix(vec3(.01, .013, .022), vec3(.002, .003, .006), smoothstep(0., .4, rd.y));
      // storm cloud lit from below by the fire
      col += vec3(.5, .18, .05) * fireHeat() * .05 * exp(-rd.y * 4.) * smoothstep(.2, .8, fbm3lo(vec3(rd.xz / max(rd.y, .05) * 2., t * .05)));
    }
    // fog of blowing snow
    float fogA = 1. - exp(-d * .018);
    vec3 fogLit = fogCol + vec3(1., .42, .12) * fireHeat() * .045 * fireFlick();
    col = mix(col, fogLit * (.8 + .4 * noise3(vec3(fc / iResolution.y * 4., t * .7) + vec3(t * 1.5, 0., 0.))), fogA);

    // glow halos: mast lamp, doorway, headlights, tail lights through the snow
    float tv = min(d, 120.);
    vec3 vol = SODIUM * scatterPoint(ro, rd, vec3(18.6, 7.8, 44.), tv, .8) * .08;
    vol += SODIUM * scatterPoint(ro, rd, vec3(0., 4., 41.), tv, .15) * .03 * (1. - smoothstep(T_EXPL, T_EXPL + .3, t));
    vec3 tl0 = vehToWorld(vec3(-1.9, 1.85, -4.5)), tl1 = vehToWorld(vec3(1.9, 1.85, -4.5));
    vol += vec3(1., .05, .03) * (scatterPoint(ro, rd, tl0, tv, 12.) + scatterPoint(ro, rd, tl1, tv, 12.)) * .5;
    vol += vec3(1., .9, .75) * (scatterPoint(ro, rd, gHL0 + gHDir * 3., tv, 1.) + scatterPoint(ro, rd, gHL1 + gHDir * 3., tv, 1.)) * .06;
    vol += vec3(1., .45, .14) * scatterPoint(ro, rd, fireC(), tv, .02) * .012 * fireHeat() * fireFlick();
    col += vol;

    // explosion
    float tr;
    vec3 fb = fireball(ro, rd, d, dither, tr);
    col = col * tr + fb;
    col += debris(ro, rd, d);
    col += flakes(fc, .6, vec3(.35, .4, .5) + vec3(.8, .35, .1) * fireHeat() * .25);
  }
  return max(col, 0.);
}
