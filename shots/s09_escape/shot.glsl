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
    const float R = 26., PM = 1.3, S0 = 5.;
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
vec3 gLamp[5]; vec3 gLampDir[5];
float gDoorA[2]; vec3 gGren = vec3(0., -99., 0.);
vec4 gCand[4]; float gCandK[4]; bool gCandLOD[4]; int gNC = 0;
int gMask = 255; int gLampC[5]; int gNL = 5;

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
  if (p.y < 1.6){
    float tr = sdRoundBox(tq, vec3(.52, .58, 3.95), .5);
    float gz = p.z + (gExt ? iTime * 7. : 0.);
    tr += .025 * smoothstep(.2, .8, abs(fract(gz * 3.) - .5) * 2.) * step(.3, abs(tq.y) + step(3.4, abs(p.z)));
    r = opU(r, vec2(tr, H_TRACK));
  } else r.x = p.y - 1.4;
  float fender = sdBox(tq - vec3(0., .72, 0.), vec3(.6, .05, 4.05));
  // cabin
  vec3 cq = p - vec3(0., 2.78, -.15);
  float cab0 = sdRoundBox(cq, vec3(2.08, 1.42, 4.1), .22);
  cab0 = smax(cab0, dot(p - vec3(0., 3.2, 3.95), normalize(vec3(0., .32, 1.))), .15);   // raked windscreen
  float cab = cab0;
  if (abs(p.y - 3.53) < .6){
    // window recesses along the sides and in front, glass set a little inside
    vec3 wq = vec3(abs(p.x) - 2.1, p.y - 3.52, mod(p.z + .55, 1.1) - .55);
    float win = sdBox(wq, vec3(.08, .3, .4));
    win = max(win, abs(p.z + .3) - 3.3);
    float fwin = sdBox(vec3(abs(p.x) - .95, p.y - 3.55, p.z - 3.95), vec3(.78, .34, .3));
    float rec = min(win, fwin);
    cab = max(cab0, -rec);
    r = opU(r, vec2(max(rec, cab0 + .06), H_GLASS));
  }
  r = opU(r, vec2(min(cab, fender), H_BODY));
  // white roof cap + rack + exhaust stack + roof spots
  if (p.y > 3.9){
    float roof = sdRoundBox(p - vec3(0., 4.28, -.3), vec3(1.95, .1, 3.7), .08);
    vec3 rq = vec3(p.x, p.y - 4.55, mod(p.z + .4, 1.6) - .8);
    float rack = sdBox(rq, vec3(1.7, .03, .03));
    rack = max(rack, abs(p.z + 1.4) - 1.6);
    rack = min(rack, sdBox(vec3(abs(p.x) - 1.7, p.y - 4.55, p.z + 1.4), vec3(.03, .05, 1.6)));
    r = opU(r, vec2(roof, H_ROOF));
    r = opU(r, vec2(min(rack, sdCylY(p - vec3(1.55, 4.9, -3.4), .09, .6)), H_DARK));
    vec3 sq = vec3(abs(p.x) - .7, p.y - 4.5, p.z - 3.2);
    r = opU(r, vec2(sdCylZ(sq, .13, .1), H_HEAD));
  } else r.x = min(r.x, 4.1 - p.y);
  // nose: round headlights in housings, bumper
  if (p.z > 3.7){
    vec3 hq = vec3(abs(p.x) - 1.35, p.y - 1.95, p.z - 4.05);
    r = opU(r, vec2(sdCylZ(hq, .21, .12), H_DARK));
    r = opU(r, vec2(sdSphere(hq - vec3(0., 0., .02), .17), H_HEAD));
    r = opU(r, vec2(sdBox(p - vec3(0., 1.35, 4.18), vec3(2.05, .12, .1)), H_DARK));
  } else r.x = min(r.x, 3.9 - p.z);
  // tail: rear platform with railing, tail lights, and the man on it
  if (p.z < -3.9){
    r = opU(r, vec2(sdBox(p - vec3(0., 1.55, -4.55), vec3(1.7, .05, .42)), H_DARK));
    vec3 lq = vec3(abs(p.x) - 1.65, p.y - 2.05, p.z + 4.9);
    float rail = sdBox(lq, vec3(.025, .5, .025));
    rail = min(rail, sdBox(p - vec3(0., 2.55, -4.93), vec3(1.68, .025, .025)));
    r = opU(r, vec2(rail, H_DARK));
    r = opU(r, vec2(sdSphere(vec3(abs(p.x) - 1.9, p.y - 1.85, p.z + 4.25), .12), H_TAIL));
    vec3 fp = p - vec3(-.5, 1.6, -4.5);
    float fb = sdBox(fp - vec3(0., 1., 0.), vec3(.8, 1.2, .8));
    if (gExt || fb > .2) r.x = min(r.x, gExt ? 1e5 : fb);
    else {
      // throws a grenade back at T_THROW
      float th = smoothstep(T_THROW - .45, T_THROW, iTime) - smoothstep(T_THROW + .1, T_THROW + .8, iTime);
      float body = sdCapsule(fp, vec3(0., .85, 0.), vec3(0., 1.45, -.1 * th), .17);
      body = min(body, sdCapsule(fp, vec3(-.1, .05, 0.), vec3(-.08, .85, 0.), .09));
      body = min(body, sdCapsule(fp, vec3(.1, .05, 0.), vec3(.08, .85, 0.), .09));
      body = min(body, sdSphere(fp - vec3(0., 1.66, -.12 * th), .12));
      vec3 hand = mix(vec3(.25, 1.9, .35), vec3(.3, 1.8, -.6), th);
      body = min(body, sdCapsule(fp, vec3(.2, 1.4, 0.), hand, .06));
      body = min(body, sdCapsule(fp, vec3(-.2, 1.4, 0.), vec3(-.45, 1.1, .2), .06));
      body = min(body, sdCapsule(fp, vec3(-.45, 1.1, .2), vec3(-.55, .95, .15), .05)); // holds the rail
      r = opU(r, vec2(body, H_FIG));
    }
  } else r.x = min(r.x, p.z + 4.1);
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
  vec3 door = vec3(-15.2, 0., 27.2 + .9 * sin(fk * 2.1));
  bool wave2 = t > 5.;
  if (wave2 && k >= 3) return vec4(0., 0., 0., -99.);
  float ts = wave2 ? 6.2 + .55 * fk + .2 * sin(fk * 3.) : 1.3 + .42 * fk + .15 * sin(fk * 3.);
  if (t < ts) return vec4(0., 0., 0., -99.);
  if (wave2) door = vec3(7.8 - .5 * fk, 0., 23. + 1.2 * fk);                     // lurkers break from behind the drums
  vec3 target;
  if (!wave2){
    vec3 vv = vehicle(t);
    target = vec3(vv.x, 0., vv.y) + vec3(-2.8 + 5.6 * hash11(fk), 0., 6. + 6. * hash11(fk + 2.));  // mass in its headlights
  } else {
    target = vec3(1.5 + 2.5 * hash11(fk + .3), 0., 36. + 2. * hash11(fk + 7.));                 // chase it to the doors
  }
  vec3 dv = target - door;
  float dist = length(dv);
  float spd = wave2 ? 3.6 + 1. * hash11(fk + 5.) : 4.2 + 2. * hash11(fk + 5.);
  float f = min(1., (t - ts) * spd / max(dist, .01));
  vec3 pos = door + dv * f;
  vec3 dir = dv / max(dist, .01);
  // weave a little
  pos.xz += vec2(-dir.z, dir.x) * .4 * sin(t * 2.3 + fk * 4.);
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
    float th = gDoorA[s];
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
  if ((gMask & 1) == 0) {}
  else if (p.y > 9.6){
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

  // sodium work lights on tripods (only those near this ray)
  for (int j = ZERO; j < gNL; j++){
    int i = gLampC[j];
    vec3 L = gLamp[i];
    vec3 base = vec3(L.x, 0., L.z);
    float bb = i == 2 ? sdCapsule(p, L, vec3(L.x, 10.3, L.z), .5) : sdCapsule(p, base, L + vec3(0., .3, 0.), .9);
    if (bb > .4) { r.x = min(r.x, bb); }
    else {
    vec3 q = p - base;
    float st;
    if (i == 2) st = sdCapsule(p, L, vec3(L.x, 10.3, L.z), .02);     // hung from the truss
    else {
      st = sdCapsule(q, vec3(0., 1.1, 0.), vec3(0., L.y - .15, 0.), .035);
      for (int k = 0; k < 3; k++){
        float a = float(k) * TAU / 3. + .5;
        st = min(st, sdCapsule(q, vec3(0., 1.1, 0.), vec3(cos(a) * .75, 0., sin(a) * .75), .025));
      }
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
  }

  // fuel drums (3x4 block, a few stacked on top)
  if ((gMask & 2) != 0) {
    vec3 c = vec3(6.8, 0., 25.5);
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
  if ((gMask & 4) != 0) {
    vec3 q = p - vec3(-13.4, 0., 20.);
    q.z = mod(q.z + 3., 6.) - 3.;
    float cr = sdBox(q - vec3(0., .6, 0.), vec3(.9, .6, 1.1));
    cr = min(cr, sdBox(q - vec3(.1, 1.55, -.3), vec3(.7, .35, .7)));
    cr = max(cr, abs(p.z - 20.) - 12.);
    r = opU(r, vec2(cr, H_CRATE));
  }
  // doors
  if ((gMask & 8) != 0) r = opU(r, sdDoors(p));
  // tractor
  if ((gMask & 16) != 0) r = opU(r, sdTractor(toVeh(p)));
  // the grenade in flight
  if (gGren.y > -50.) r = opU(r, vec2(sdSphere(p - gGren, .08), H_GREN));
  // the staff: states precomputed per pixel, only monsters near this ray are evaluated,
  // and a single sdMonster call site for the nearest candidate
  float best = 1e5; int bk = -1; float other = 1e5;
  for (int j = ZERO; j < gNC; j++){
    vec4 ms = gCand[j];
    vec3 q = p - ms.xyz;
    q.xz *= rot2(-ms.w);
    float bb = sdCapsule(q, vec3(0., .3, 0.), vec3(0., 1.6, .3), .75);
    if (bb < best) { other = min(other, best); best = bb; bk = j; } else other = min(other, bb);
  }
  if (bk >= 0){
    if (best > .25) r.x = min(r.x, best);
    else {
      vec4 ms = gCand[bk];
      vec3 q = p - ms.xyz;
      q.xz *= rot2(-ms.w);
      float fk = gCandK[bk];
      vec2 m;
      if (gCandLOD[bk]) m = sdRunnerLOD(q, iTime * 7.5 + fk * 1.7);
      else m = sdMonster(q, iTime + fk * .37 + .0173, fract(fk * .31 + .07), 1.);
      r = opU(r, m);
      r.x = min(r.x, max(other, .02));
    }
  }
  return r;
}

// ---------------------------------------------------------------- exterior map
vec3 fireC(){ float b = max(iTime - T_EXPL, 0.); return vec3(2., 16. + 3.2 * b, 29.); }
float fireR(){ float b = max(iTime - T_EXPL, 0.); return 14. * (1. - exp(-b * 2.6)) + 1.4 * b + .1; }

vec2 mapExt(vec3 p){
  vec2 r = vec2(1e5, 0.);
  // hangar: hollow shell with an arched roof, door opening, snow drifts against it
  {
    float outer = max(sdBox(p - vec3(0., 7., 20.), vec3(15.4, 7., 20.4)), length(p.xy - vec2(0., -10.)) - 23.2);
    float inner = max(sdBox(p - vec3(0., 7., 20.), vec3(15., 7., 20.)), length(p.xy - vec2(0., -10.)) - 22.8);
    float bl = max(outer, -inner);
    bl = max(bl, -sdBox(p - vec3(0., 5., 40.4), vec3(8., 5., 1.)));      // torn door opening
    if (iTime > T_EXPL) bl = max(bl, -(length((p - vec3(2., 11., 29.)) * vec3(1., .8, 1.)) - min(fireR(), 7.) * 1.1 - 2.5 * fbm3lo(p * .3)));  // roof blown out
    r = opU(r, vec2(bl, H_BLDG));
    // snow drifts banked against the walls
    float drift = sdEllipsoid(p - vec3(-16., 0., 20.), vec3(3., 2.2, 22.));
    drift = min(drift, sdEllipsoid(p - vec3(16., 0., 18.), vec3(3.2, 2.6, 22.)));
    drift = min(drift, sdEllipsoid(p - vec3(-13., -.3, 41.5), vec3(6.5, 1.6, 3.5)));
    drift = min(drift, sdEllipsoid(p - vec3(13., -.3, 41.5), vec3(6.5, 1.9, 3.5)));
    r = opU(r, vec2(drift, H_SNOW));
    // light mast with a sodium lamp
    r = opU(r, vec2(sdCapsule(p, vec3(12.4, 0., 50.), vec3(12.4, 8.2, 50.), .1), H_STAND));
    r = opU(r, vec2(sdBox(p - vec3(12., 8.2, 50.), vec3(.45, .15, .25)), H_LAMP));
  }
  // the staff in the lit doorway until the blast
  if (iTime < T_EXPL + .1){
    for (int k = ZERO; k < 3; k++){
      float fk = float(k);
      vec3 mp = vec3(-3.5 + fk * 3.2, 0., 37. + fk * 1.3 + (iTime - T_EXT) * (1.2 + fk * .3));
      vec3 q = p - mp;
      q.xz *= rot2(.3 * (fk - 1.));
      float bb = sdCapsule(q, vec3(0., .3, 0.), vec3(0., 1.6, .3), .7);
      if (bb > .2) r.x = min(r.x, bb);
      else r = opU(r, sdRunnerLOD(q, iTime * 7. + fk * 2.));
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
  // single tap: cheap contact darkening
  float h = .35;
  return clamp(1. - 1.7 * (h - map(p + n * h).x), 0., 1.);
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

float gT0 = 0., gT1 = 0.;   // march interval covering every culled bound on this ray
bool rayBox(vec3 ro, vec3 rd, vec3 bmin, vec3 bmax){
  vec3 ta = (bmin - ro) / rd, tb = (bmax - ro) / rd;
  vec3 tn = min(ta, tb), tf = max(ta, tb);
  float t0 = max(max(max(tn.x, tn.y), tn.z), 0.), t1 = min(min(tf.x, tf.y), tf.z);
  if (t1 > t0){ gT0 = min(gT0, t0); gT1 = max(gT1, t1); return true; }
  return false;
}
// per-ray culling of scene parts: only what this ray's path gets near is evaluated in map()
void cullInt(vec3 ro, vec3 rd){
  gMask = 0; gT0 = 1e5; gT1 = 0.;
  if (rayBox(ro, rd, vec3(-16., 9.4, -15.), vec3(16., 13., 41.))) gMask |= 1;
  if (rayBox(ro, rd, vec3(6.8 - 1.8, -.1, 25.5 - 2.2), vec3(6.8 + 1.8, 2.3, 25.5 + 2.2))) gMask |= 2;
  if (rayBox(ro, rd, vec3(-14.5, -.1, 7.5), vec3(-12.3, 2.1, 32.5))) gMask |= 4;
  if (rayBox(ro, rd, vec3(-9.5, -1., 38.5), vec3(9.5, 13.5, 49.5))) gMask |= 8;
  vec3 vo = toVeh(ro), vd = normalize(toVeh(ro + rd) - vo);
  if (rayBox(vo, vd, vec3(-2.6, -.3, -5.2), vec3(2.6, 5.8, 5.))) gMask |= 16;   // rotation keeps ray length
  gNL = 0;
  for (int i = 0; i < 5; i++){
    vec3 L = gLamp[i];
    if (rayBox(ro, rd, vec3(L.x - 1.1, i == 2 ? L.y - .7 : -.1, L.z - 1.1), vec3(L.x + 1.1, i == 2 ? 10.5 : L.y + .7, L.z + 1.1))){ gLampC[gNL] = i; gNL++; }
  }
  if (gGren.y > -50.) rayBox(ro, rd, gGren - .3, gGren + .3);
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
  gDoorA[0] = doorAngle(0); gDoorA[1] = doorAngle(1);
  gGren = vec3(0., -99., 0.);
  if (t > T_THROW && t < T_THROW + 1.4){
    float u = t - T_THROW;
    vec3 g0 = vec3(-.3, 3.4, vehicle(T_THROW).y - 4.6);
    gGren = g0 + vec3(5.55, 4.1, -9.1) * u + vec3(0., -4.9, 0.) * u * u;
    gGren.y = max(gGren.y, .08);
  }
  gHL0 = vehToWorld(vec3(-1.35, 1.95, 4.2));
  gHL1 = vehToWorld(vec3(1.35, 1.95, 4.2));
  gHDir = normalize(vehToWorld(vec3(0., 1.7, 14.)) - vehToWorld(vec3(0., 1.95, 4.2)));

  gLamp[0] = vec3(11.2, 4.4, 29.8);  gLampDir[0] = normalize(vec3(6.8, .5, 25.5) - vec3(11.2, 4.4, 29.8));  // drums + side door
  gLamp[1] = vec3(3.8, 4.4, 21.);    gLampDir[1] = normalize(vec3(7.2, .3, 25.) - vec3(3.8, 4.4, 21.));    // drums, from the front
  gLamp[2] = vec3(-6.5, 8.2, 18.);  gLampDir[2] = normalize(vec3(-.5, 3., 16.) - vec3(-6.5, 8.2, 18.));    // raking the tractor's flank
  gLamp[3] = vec3(-9.5, 5.2, 36.5);  gLampDir[3] = normalize(vec3(.75, -.5, .45));    // on the main doors
  gLamp[4] = vec3(-10.5, 5.2, 36.);  gLampDir[4] = normalize(vec3(-7.5, 0., 30.5) - vec3(-10.5, 5.2, 36.));  // pool inside the side door

  if (t < 5.){
    // high wide from the back corner, slow drift
    float k = t / 5.;
    gRo = vec3(-13.5 + .6 * k, 6.2 - .3 * k, 9. + 1.2 * k);
    gTa = vec3(1., 1.4, 27.);
    gFocal = 1.05;
  } else if (!gExt){
    // low angle beside its path: it charges past toward the doors; after the ram we swing back
    // to the man on the rear platform and follow the grenade into the dark toward the drums
    gRo = vec3(-9.4, .7, 31.5) + vec3(.4, 0., .8) * smoothstep(5., 9., t);
    float vz = vehicle(t).y;
    vec3 a = vec3(0., 2.4, clamp(vz + 2.5, 20., 39.));
    vec3 dr = vec3(-1., 4.5, 40.);
    gTa = mix(a, dr, smoothstep(7.6, 8.2, t) * .5);
    vec3 plat = vehToWorld(vec3(-.5, 3.3, -4.5));
    gTa = mix(gTa, plat, smoothstep(8.7, 9.3, t));
    vec3 gf = t > T_THROW && t < T_THROW + 1.4 ? gGren : vec3(6.5, .6, 25.8);
    gTa = mix(gTa, mix(vec3(6., 1.4, 26.5), gf, .6), smoothstep(9.55, 10.2, t));
    gFocal = 1.05 + .25 * smoothstep(9.65, 10.6, t);
  } else {
    // exterior: out in the blizzard looking back at the hangar; it bursts out and swings away
    // to screen right, the hangar goes up behind it, then we hold on its tail lights receding
    float k = smoothstep(T_EXT, 18., t);
    gRo = vec3(-37. + 2. * k, 3.2 - .4 * k, 86. - 1. * k);
    vec3 vp = gVP + vec3(0., 2., 0.);
    vec3 a = vec3(2., 5.5, 40.);
    gTa = mix(a, vp, .35);
    gTa = mix(gTa, mix(vec3(2., 19., 32.), vp, .4), smoothstep(T_EXPL, 14., t));
    gTa = mix(gTa, mix(vec3(2., 11., 30.), vp, .42), smoothstep(14.5, 17., t));
    gFocal = mix(1.25, .95, smoothstep(14.5, 17., t));
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
    vec2 id = floor((p.xz - vec2(6.8, 25.5)) / .64 + .5);
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
    s.alb = vec3(.8, .8, .77) * (.8 + .3 * fbm3lo(p * 3.)); s.spk = .4; s.gloss = 40.;
  } else if (m == H_GLASS){
    vec3 q = toVeh(p);
    s.alb = vec3(.01); s.spk = 2.; s.gloss = 200.;
    s.emi = vec3(1., .62, .3) * (gExt ? 1.8 : .12) * (.5 + noise3(q * 2.));             // dim cab light inside
  } else if (m == H_HEAD){
    s.alb = vec3(.2); s.emi = vec3(1., .92, .75) * 16. * gHeadOn + vec3(.02);
  } else if (m == H_TAIL){
    s.alb = vec3(.1); s.emi = vec3(1., .06, .03) * (gExt ? 18. : 7.);
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
    s.alb = monsterAlbedo(m, p) * (gExt ? .8 : .4); s.spk = monsterSpec(m); s.gloss = 40.;
  }
  return s;
}

// ---------------------------------------------------------------- interior lighting
vec3 lightInt(vec3 p, vec3 n, vec3 rd, Surf s, bool isVeh){
  vec3 col = vec3(0.);
  vec3 V = -rd;
  for (int i = 0; i < 5; i++){
    vec3 L = gLamp[i] - p; float d = length(L); L /= d;
    float cone = smoothstep(.25, .8, dot(-L, gLampDir[i]));
    float at = (i == 3 ? 12. : 30.) * cone / (1. + d * d * 1.1);
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
      float at = 60. * cone * gHeadOn / (1. + d * d * .6);
      at *= smoothstep(-.3, .2, dot(p - hp, gHDir));
      vec3 H = normalize(L + V);
      col += vec3(1., .93, .8) * at * (s.alb * max(dot(n, L), 0.) + pow(max(dot(n, H), 0.), s.gloss) * s.spk * (s.gloss * .03 + .4));
    }
  }
  // red emergency light in the corridor beyond the side door
  {
    vec3 L = vec3(-17., 2.2, 28.) - p; float d = length(L); L /= d;
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
// environment light from the fire: soft rise, no blinding spike (the core itself carries the peak)
float envHeat(){
  float b = iTime - T_EXPL;
  if (b < 0.) return 0.;
  return (1.2 * exp(-b * 1.2) + .9 * exp(-b * .2)) * smoothstep(0., .25, b);
}
float fireHeat(){
  float b = iTime - T_EXPL;
  if (b < 0.) return 0.;
  return (6. * exp(-b * 3.) + 1.2 * exp(-b * .25)) * smoothstep(0., .06, b);
}
vec3 lightExt(vec3 p, vec3 n, vec3 rd, Surf s){
  vec3 col = vec3(0.);
  vec3 V = -rd;
  // explosion / fire
  float heat = envHeat() * 1.6;
  if (heat > 0.){
    vec3 fc = fireC() - vec3(0., 3., 0.);
    vec3 L = fc - p; float d = length(L); L /= d;
    float at = 260. * heat * fireFlick() / (d * d + 30.);
    vec3 H = normalize(L + V);
    col += vec3(1., .45, .14) * at * (s.alb * max(dot(n, L), 0.) + pow(max(dot(n, H), 0.), s.gloss) * s.spk * .4);
  }
  // interior glow through the doorway before the blast
  {
    vec3 L = vec3(0., 4., 37.5) - p; float d = length(L); L /= d;
    float facing = smoothstep(-.2, .4, (p.z - 38.) / max(d, .1));
    float at = 10. * facing / (1. + d * d * .35) * (1. - smoothstep(T_EXPL, T_EXPL + .3, iTime));
    col += SODIUM * at * s.alb * max(dot(n, L), 0.);
  }
  // mast lamp
  {
    vec3 L = vec3(12., 8.0, 50.) - p; float d = length(L); L /= d;
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
    vec3 wq = q * 1.7 + vec3(0., -b * .6, b * .15);
    float n = fbm3lo(wq + 1.3 * (vec3(noise3(wq * 1.3), noise3(wq * 1.3 + 7.), noise3(wq * 1.3 + 13.)) - .5));
    // fire core: a turbulent ball
    float rf = length(q);
    float fireD = smoothstep(.2, -.15, rf - .8 + (n - .5) * 1.1);
    // smoke: mushroom cap rolling above + stem, soft eroded edges
    vec3 cq = q - vec3(.1 * b, 1.05 + .25 * b, 0.);
    float rc = length(cq * vec3(.72, 1.25, .72));
    float sm = rc - min(1., b * 1.5);
    float smokeD = smoothstep(.25, -.25, sm + (n - .5) * 1.5) * smoothstep(-.4, .3, q.y);
    float dens = fireD * 1.8 + smokeD * 1.6 * smoothstep(0., .4, b);
    if (dens < .01) continue;
    // temperature: white-hot only deep in the core, early; cools to deep red/black at the edges
    float temp = clamp((.9 - rf) * 1.2 + (n - .5) * 2.6, 0., 1.) * fireD * clamp(heat / 4., .2, 1.);
    vec3 fcol = mix(vec3(.6, .06, .01), vec3(2., .75, .18), smoothstep(.1, .45, temp));
    fcol = mix(fcol, vec3(5., 3.6, 2.), smoothstep(.6, .95, temp));
    vec3 em = fcol * temp * temp * 40.;
    // smoke: near black, underside lit orange by the fire
    float under = exp(-max(q.y - .2, 0.) * 1.3) * smoothstep(2.2, .5, length(q.xz));
    vec3 smokeC = vec3(.004, .0035, .003) + vec3(1., .33, .07) * (.18 * under * min(heat, 2.5)) * (.4 + 1.2 * n);
    float a = 1. - exp(-dens * dt / R * 4.);
    col += trans * (em * a + smokeC * a);
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
vec3 flakes(vec2 fc, float dens, vec3 tint, float scl){
  vec2 uv = fc / iResolution.y;
  vec3 col = vec3(0.);
  for (int l = ZERO; l < 3; l++){
    float fl = float(l);
    float sc = (7. + fl * 9.) * scl;                   // near layers: few big soft flakes
    vec2 q = uv * sc + vec2(iTime * (5.5 - fl * 1.2), iTime * (1.8 - fl * .4)) * (1.5 - fl * .3);
    q.y += .3 * sin(q.x * .7 + iTime);
    vec2 id = floor(q);
    vec2 f = fract(q) - .5;
    vec2 o = hash22(id + fl * 17.) - .5;
    vec2 dd = f - o * .6;
    dd.x *= .22;                               // motion streak along the wind
    float r = (.035 + .03 * hash21(id + 3.)) * (1. - fl * .2);
    float b = mix(.4, 1., hash21(id + 9.));
    col += tint * b * smoothstep(r, r * .1, length(dd)) * step(.55, hash21(id + fl * 31.)) * (1. - fl * .3);
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
  // per-ray monster culling: compact list of the (at most 4) monsters this ray passes near
  gNC = 0;
  if (!gExt){
    cullInt(ro, rd);
    for (int k = 0; k < NM; k++){
      vec4 ms = monState(k, t);
      vec3 c = ms.xyz + vec3(0., 1., 0.) - ro;
      float tc = dot(c, rd);
      if (ms.w > -50. && length(c - rd * max(tc, 0.)) < 1.35 && gNC < 4){
        gCand[gNC] = ms; gCandK[gNC] = float(k); gCandLOD[gNC] = length(c) > 22.;
        gNC++;
        gT0 = min(gT0, max(tc - 1.6, 0.)); gT1 = max(gT1, tc + 1.6);
      }
    }
  }
  if (!gExt){
    // ---------------- interior: analytic hangar box + SDF contents
    vec3 bmin = vec3(-15., 0., -14.), bmax = vec3(15., 12., 40.);
    vec3 tb = (mix(bmin, bmax, step(0., rd)) - ro) / rd;
    float tRoom = min(min(tb.x, tb.y), tb.z);
    vec3 nRoom; float mRoom = H_WALL;
    if (tRoom == tb.y){ nRoom = vec3(0., -sign(rd.y), 0.); mRoom = rd.y < 0. ? H_FLOOR : H_CEIL; }
    else if (tRoom == tb.x) nRoom = vec3(-sign(rd.x), 0., 0.);
    else nRoom = vec3(0., 0., -sign(rd.z));
    vec3 pr = ro + rd * tRoom;
    bool outside = tRoom == tb.z && rd.z > 0. && abs(pr.x) < 8. && pr.y < 10.;
    bool sideDoor = tRoom == tb.x && rd.x < 0. && abs(pr.z - 27.8) < 1.6 && pr.y < 3.4;
    float tMax = outside ? tRoom + 30. : tRoom;

    float d = max(gT0, .1); vec2 h = vec2(0.); bool hit = false;
    tMax = min(tMax, gT1);
    if (d < tMax) for (int i = 0; i < 96; i++){
      vec3 p = ro + rd * d;
      h = map(p);
      if (h.x < .0025 * d) { hit = true; break; }
      d += h.x * .95;
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
      if (h.y < 4.6){
        // the staff: backlit by the cold night through the torn doors and the tractor's red tail lights
        float fr = pow(1. - max(dot(n, -rd), 0.), 2.5);
        vec3 tl = vehToWorld(vec3(0., 1.85, -4.4));
        float dtl = length(tl - p);
        vec3 rim = vec3(.3, .42, .65) * 1.4 * smoothstep(T_RAM, T_RAM + .5, t) * max(n.z * .7 + .3, 0.)
                 + vec3(1., .08, .04) * 6. / (1. + dtl * dtl * .15) * max(dot(n, normalize(tl - p)) * .7 + .3, 0.)
                 + SODIUM * .5 * max(-n.x * .6 + .4, 0.);
        col += rim * fr;
      }
      col *= mix(.25, 1., calcAO(p, n));
    }
    // distance falloff into darkness
    col *= exp(-max(d - 12., 0.) * .03);

    // ---- volumetric light: halos around the sodium lamps, headlight beams, exhaust smoke
    float tv = min(d, 60.);
    vec3 vol = vec3(0.);
    for (int i = 0; i < 5; i++){
      vol += SODIUM * scatterPoint(ro, rd, gLamp[i] + gLampDir[i] * .4, tv, 4.) * .05;
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
      vol += beam * min(tv, 45.) / 8. * .03 * gHeadOn;
    }
    // exhaust: puffs from the stack, heavy when it lights up and when it lurches
    {
      vec3 st = vehToWorld(vec3(1.55, 5.5, -3.4));
      float amt = .4 + 1.6 * exp(-max(t - 1., 0.) * 1.5) * step(.9, t) + 1.2 * exp(-max(t - 5., 0.) * 1.2) * step(5., t);
      vec3 sc = st + vec3(0., 2., -.8);
      vec3 oc = ro - sc;
      float bb = dot(oc, rd), cc = dot(oc, oc) - 6.25;
      float disc = bb * bb - cc;
      if (disc > 0.){
        float sq = sqrt(disc);
        float s0 = max(-bb - sq, 0.), s1 = min(-bb + sq, d);
        float T = 1.;
        vec3 sm = vec3(0.);
        for (int i = ZERO; i < 6; i++){
          float ts = s0 + (float(i) + dither) / 6. * (s1 - s0);
          vec3 q = ro + rd * ts - st;
          float hy = max(q.y, 0.);
          vec2 dr = q.xz - vec2(0., -.35 * hy * hy);                     // bent back by the draught
          float rr = .25 + .35 * hy;
          float dn = smoothstep(rr, rr * .2, length(dr)) * smoothstep(-.1, .3, q.y) * smoothstep(4.5, 1.5, q.y);
          dn *= smoothstep(.35, .7, fbm3lo(q * 1.3 + vec3(0., -t * 2.5, 0.))) * amt * 2.;
          float a = 1. - exp(-dn * (s1 - s0) / 6. * 1.5);
          vec3 lit = vec3(.02, .018, .016) + SODIUM * .05;
          sm += T * a * lit * .5;
          T *= 1. - a;
        }
        col = col * T + sm;
      }
    }
    col += vol;
    // sparks where steel meets steel
    float sb = t - T_RAM;
    if (sb > 0. && sb < .9){
      for (int k = ZERO; k < 24; k++){
        float fk = float(k);
        vec3 hh = hash33(vec3(fk, 5.1, 2.3));
        vec3 o = vec3((hh.x - .5) * 4.4, .8 + 2.6 * hh.y, 40.);
        vec3 v = vec3((hh.x - .5) * 9., 2. + 5. * hh.z, -3. - 5. * hh.y);
        float u = sb - hh.z * .2;
        if (u < 0.) continue;
        vec3 sp = o + v * u + vec3(0., -9.8, 0.) * u * u * .5;
        vec3 sp0 = o + v * max(u - .03, 0.) + vec3(0., -9.8, 0.) * max(u - .03, 0.) * max(u - .03, 0.) * .5;
        vec3 ba = sp - sp0, w0 = sp0 - ro;
        float aa = 1., bb2 = dot(rd, ba), cc2 = dot(ba, ba), dd2 = dot(rd, w0), ee = dot(ba, w0);
        float sgm = clamp((aa * ee - bb2 * dd2) / max(aa * cc2 - bb2 * bb2, 1e-6), 0., 1.);
        vec3 q = sp0 + ba * sgm;
        float tq = dot(q - ro, rd);
        if (tq < 0. || tq > d + .5) continue;
        float dist = length(q - ro - rd * tq);
        col += vec3(3., 1.6, .6) * smoothstep(.02 + tq * .0015, 0., dist) * exp(-u * 3.);
      }
    }
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
      // flakes only where the view passes through the torn doorway region
      float tpz = (38. - ro.z) / rd.z;
      vec3 pz = ro + rd * tpz;
      float reg = step(0., tpz) * smoothstep(10., 6., abs(pz.x)) * smoothstep(11.5, 8., pz.y) * step(tpz, d + 2.);
      col += flakes(fc, open * .25 * reg, vec3(.5, .55, .65) + vec3(.6, .55, .45) * gHeadOn * .5, 2.2);
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
        float fl = fbm3lo(vec3(p.x * .4, p.y * .25 - t * 2.5, p.z * .4));
        s.emi += SODIUM * .08 * (1. - smoothstep(T_EXPL, T_EXPL + .2, t)) + vec3(1.6, .45, .08) * envHeat() * .9 * fireFlick() * smoothstep(.35, .75, fl) * smoothstep(12., 2., p.y);
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
      n = normalize(vec3(-(hx - h0) * 1.4, 1., -(hz - h0) * 1.4));
      Surf s; s.alb = vec3(.72, .77, .85); s.spk = .25; s.gloss = 18.; s.emi = vec3(0.);
      // tracks behind the tractor
      vec3 vq = toVeh(p);
      float rut = smoothstep(.55, .25, abs(abs(vq.x) - 1.62)) * step(vq.z, 0.) * step(p.z, 200.);
      s.alb *= 1. - .45 * rut * smoothstep(-60., -2., vq.z);
      col = lightExt(p, n, rd, s);
      float gl = step(.996, hash21(floor(p.xz * 22.)));
      col += gl * envHeat() * .3 * vec3(1., .6, .3) * smoothstep(90., 20., length(p - fireC()));
    } else {
      d = 400.;
      col = mix(vec3(.01, .013, .022), vec3(.002, .003, .006), smoothstep(0., .4, rd.y));
      // storm cloud lit from below by the fire
      col += vec3(.5, .18, .05) * envHeat() * .05 * exp(-rd.y * 4.) * smoothstep(.2, .8, fbm3lo(vec3(rd.xz / max(rd.y, .05) * 2., t * .05)));
    }
    // fog of blowing snow
    float fogA = 1. - exp(-d * .011);
    vec3 fogLit = fogCol;
    col = mix(col, fogLit * (.8 + .4 * noise3(vec3(fc / iResolution.y * 4., t * .7) + vec3(t * 1.5, 0., 0.))), fogA);

    if (!hit && rd.y >= 0.){
      // low storm ceiling lit from beneath by the fire: the backdrop the smoke reads against
      vec3 fdir = normalize(fireC() - ro);
      float ang = acos(clamp(dot(rd, fdir), -1., 1.));
      col += vec3(1., .33, .07) * envHeat() * .05 * exp(-ang * 2.5) * (.2 + 1.6 * fbm3lo(vec3(rd.xy * 6., t * .15)));
    }
    // glow halos: mast lamp, doorway, headlights, tail lights through the snow
    float tv = min(d, 120.);
    vec3 vol = SODIUM * scatterPoint(ro, rd, vec3(12., 7.8, 50.), tv, 2.) * .03;
    vol += SODIUM * scatterPoint(ro, rd, vec3(0., 4., 41.), tv, 3.) * .006 * (1. - smoothstep(T_EXPL, T_EXPL + .3, t));
    vec3 tl0 = vehToWorld(vec3(-1.9, 1.85, -4.5)), tl1 = vehToWorld(vec3(1.9, 1.85, -4.5));
    vol += vec3(1., .05, .03) * (scatterPoint(ro, rd, tl0, tv, 5.) + scatterPoint(ro, rd, tl1, tv, 5.)) * .035 * (1. + .03 * length(tl0 - ro));
    vol += vec3(1., .9, .75) * (scatterPoint(ro, rd, gHL0 + gHDir * 2., tv, 3.) + scatterPoint(ro, rd, gHL1 + gHDir * 2., tv, 3.)) * .03;
    vol += vec3(1., .45, .14) * scatterPoint(ro, rd, fireC() - vec3(0., 3., 0.), tv, .1) * .004 * envHeat() * fireFlick();
    col += vol;

    // explosion
    float tr;
    vec3 fb = fireball(ro, rd, d, dither, tr);
    col = col * tr + fb;
    col += debris(ro, rd, d);
    col += flakes(fc, .22, vec3(.3, .34, .42) + vec3(.8, .35, .1) * envHeat() * .12, 1.7);
  }
  return max(col, 0.);
}
