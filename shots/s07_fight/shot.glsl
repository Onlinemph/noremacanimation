// s07_fight — first person with the KS-23. Red beacons, torch under the barrel, muzzle flashes.
// uP: 0 KS flash, 1 pump, 2 recoil, 3 left-gun flash, 4 time since last left-gun round (-1 none),
//     6 flare on, 7 flare arc progress, 8 lens blood, 9 crowd turn, 10 crowd run, 11-13 aim point, 14 t

#define MF_WALL 70.
#define MF_FLOOR 71.
#define MF_CEIL 72.
#define MF_TABLE 73.
#define MF_BEACON 74.
#define MF_PIPE 75.
#define MF_DOOR 76.

vec3 gRo, gGunO, gGunR, gGunU, gGunF, gMuzzle, gFlare;

// ---------------------------------------------------------------- MONSTER SCRIPT (keep in sync with shot.js)
// i: seed, start (x,z), end (x,z), tRun, tHit, killedBy (0 KS, 1 gun), appear (from a side door) time
const int NM = 7;
float mSeed(int i){ return i==0?.22: i==1?.71: i==2?.41: i==3?.83: i==4?.12: i==5?.64: .37; }
vec2 mStart(int i){ return i==0?vec2(.3,16.): i==1?vec2(-.8,22.): i==2?vec2(2.8,10.): i==3?vec2(0.,24.): i==4?vec2(-2.8,12.): i==5?vec2(.6,26.): vec2(-.4,20.); }
vec2 mEnd(int i){ return i==0?vec2(.3,8.6): i==1?vec2(-.5,8.8): i==2?vec2(.45,5.6): i==3?vec2(.05,6.6): i==4?vec2(-.5,7.5): i==5?vec2(.2,9.): vec2(-.3,1.75); }
float mRun(int i){ return i==0?4.: i==1?4.5: i==2?8.: i==3?8.5: i==4?9.5: i==5?10.: 12.5; }
float mHit(int i){ return i==0?5.: i==1?6.9: i==2?9.6: i==3?12.: i==4?11.: i==5?13.4: 15.6; }
float mKS(int i){ return (i==0||i==2||i==3||i==6) ? 1. : 0.; }

// returns world position (feet), plus yaw, run, fall (signed: + forward, - backward), lift
void monsterState(int i, float t, out vec3 pos, out float yaw, out float run, out float fall){
  vec2 a = mStart(i), b = mEnd(i);
  float tr = mRun(i), th = mHit(i);
  vec2 xz;
  run = 0.;
  if (t < tr){
    xz = a;
    if (i == 0) xz.y -= .6 * t;                                         // the first one walks into the light
  } else if (t < th){
    vec2 a2 = a; if (i == 0) a2.y -= .6 * tr;
    float k = (t - tr) / (th - tr);
    xz = mix(a2, b, k);
    run = smoothstep(0., .25, t - tr);
  } else {
    xz = b;
    run = 1.;
  }
  fall = 0.;
  if (t >= th){
    float d = t - th;
    if (mKS(i) > .5){
      float push = (i == 6 ? 3.6 : 2.4) * (1. - exp(-d * 9.));
      xz.y += push;                                                     // blown back down the corridor
      fall = -1.55 * smoothstep(0., .45, d);
    } else {
      fall = 1.5 * smoothstep(.25, .7, d);                              // crumples forward after the burst
      xz.x += .1 * sin(d * 40.) * (1. - smoothstep(0., .3, d));
    }
    run = mix(1., 0., smoothstep(0., .2, d));
  }
  pos = vec3(xz.x, 0., xz.y);
  vec2 dcam = normalize(gRo.xz - pos.xz);
  yaw = atan(-dcam.x, dcam.y);
}

vec3 cPos[7]; float cYaw[7], cRun[7], cFall[7], cFar[7];
void cacheMonsters(float t){
  for (int i = 0; i < NM; i++){
    vec3 pos; float yaw, run, fall;
    monsterState(i, t, pos, yaw, run, fall);
    cPos[i] = pos; cYaw[i] = yaw; cRun[i] = run; cFall[i] = fall;
    cFar[i] = step(9., distance(pos.xz, gRo.xz));
  }
}
// far LOD: capsule skeleton, same silhouette family as the crowd
float cheapMonster(vec3 q, float run, float t, float seed){
  float lean = mix(.38, .85, run);
  vec3 hip = vec3(0., .9, 0.), sh = hip + vec3(0., .5 * cos(lean), .5 * sin(lean));
  float d = sdTaper(q, hip, sh, .12, .17);
  d = smin(d, sdSphere(q - sh - vec3(.08 * (hash11(seed) - .5), .16, .1), .1), .04);
  float ph = t * mix(1.1, 6.2, run) + seed * 13.7;
  for (int s = 0; s < 2; s++){
    float sg = s == 0 ? -1. : 1.;
    vec3 a = sh + vec3(.2 * sg, 0., 0.);
    d = min(d, sdTaper(q, a, a + vec3(.05 * sg, -.7 + .4 * run, .2 + .4 * run * (.5 + .5 * sin(ph + sg))), .05, .03));
    d = min(d, sdTaper(q, hip + vec3(.1 * sg, 0., 0.), vec3(.15 * sg, .05, .35 * run * sin(ph + (s == 0 ? 0. : PI))), .08, .05));
  }
  return d;
}

vec2 monsterSDF(vec3 p, int i, float t){
  vec3 pos = cPos[i]; float yaw = cYaw[i], run = cRun[i], fall = cFall[i];
  vec3 mp = p - pos;
  if (length(mp.xz) > 2.6) return vec2(length(mp.xz) - 2.4, 0.);
  mp.xz *= rot2(yaw);
  if (fall != 0.){
    mp.y -= .1 * abs(fall) / 1.55;
    mp = rotX(mp, fall);
  }
  float b = sdCapsule(mp, vec3(0., .25, 0.), vec3(0., 1.8, .3), .85);
  if (b > .15) return vec2(b, 0.);
  if (cFar[i] > .5) return vec2(cheapMonster(mp, run, t + float(i) * 3.1, mSeed(i)), M_CLOTH + .5);
  return sdMonster(mp, t + float(i) * 3.1, mSeed(i), run);
}

// cheap crowd silhouettes for the flare reveal, rows at the far end
vec2 crowd(vec3 p){
  if (uP[6] <= 0.) return vec2(1e3, 0.);
  if (p.z < 13.9) return vec2(14. - p.z, 0.);
  float r = clamp(floor((p.z - 14.6) / 1.8 + .5), 0., 3.);
  float zc = 14.6 + r * 1.8;
  float off = mod(r, 2.) * .47;
  float ci = clamp(floor((p.x - off) / .95 + .5), -2., 2.);
  vec2 id = vec2(ci, r);
  vec2 jit = (hash22(id * 7.3) - .5) * vec2(.3, .5);
  vec3 q = p - vec3(ci * .95 + off + jit.x, 0., zc + jit.y);
  float turn = uP[9], run = uP[10];
  float yaw = mix(.2 * (hash21(id) - .5), PI + .3 * (hash21(id + 4.) - .5), turn);
  q.xz *= rot2(yaw);
  float tw = uP[14] * (3. + 4. * hash21(id + 1.));
  float twitch = pow(noise2(vec2(tw, id.x * 3. + id.y)), 5.) * 2.;
  float lean = .35 + .4 * run + .1 * hash21(id + 2.);
  vec3 hip = vec3(0., .95 - .08 * run, 0.);
  vec3 sh = hip + vec3(0., .5 * cos(lean), .5 * sin(lean));
  vec3 hd = sh + vec3(.12 * (hash21(id + 3.) - .5) + .08 * twitch, .17, .1);
  float d = sdTaper(q, hip, sh, .12, .17);
  d = smin(d, sdSphere(q - hd, .1), .04);
  for (int s = 0; s < 2; s++){
    float sg = s == 0 ? -1. : 1.;
    vec3 a = sh + vec3(.2 * sg, 0., 0.);
    vec3 hnd = a + vec3(.05 * sg, -.75 + .4 * run, .2 + .4 * run);
    d = min(d, sdTaper(q, a, hnd, .05, .03));
    d = min(d, sdTaper(q, hip + vec3(.1 * sg, 0., 0.), vec3(.14 * sg, .05, .15 * sin(uP[14] * 7. * run + sg)), .08, .05));
  }
  return vec2(d, M_CLOTH + .5);
}

vec2 sdKS23Detail(vec3 p, float pump){
  vec2 r = vec2(1e5, M_GUNMETAL);
  float barrel = sdCylZ(p - vec3(0., .02, .37), .019, .26);
  barrel = max(barrel, -sdCylZ(p - vec3(0., .02, .6), .0115, .1));
  r = opU(r, vec2(barrel, M_GUNMETAL));
  r = opU(r, vec2(sdBox(p - vec3(0., .045, .6), vec3(.003, .01, .006)), M_GUNMETAL));   // front sight
  r = opU(r, vec2(sdCylZ(p - vec3(0., .005, .6), .026, .012), M_GUNMETAL));             // muzzle band
  r = opU(r, vec2(sdCylZ(p - vec3(0., -.024, .3), .016, .2), M_GUNMETAL));              // mag tube
  float fz = .26 - .09 * pump;
  float fe = sdRoundBox(p - vec3(0., -.02, fz), vec3(.028, .024, .085), .014);
  fe += .0015 * sin(p.z * 180.) * step(abs(p.y + .02), .02);                            // pump ribs
  r = opU(r, vec2(fe, M_WOOD));
  // tapered receiver: narrower front block blended into a taller rear block
  float rcFront = sdRoundBox(p - vec3(0., .0, .075), vec3(.0215, .033, .045), .006);
  float rcRear  = sdRoundBox(p - vec3(0., .010, -.03), vec3(.0255, .050, .105), .007);
  float rc = smin(rcFront, rcRear, .025);
  rc = smax(rc, -sdBox(p - vec3(.023, .022, .05), vec3(.009, .020, .052)), .004);       // ejection port
  rc = smax(rc, -sdBox(p - vec3(.021, .014, -.02), vec3(.004, .005, .09)), .0025);      // bolt rail R
  rc = smax(rc, -sdBox(p - vec3(-.021, .014, -.02), vec3(.004, .005, .09)), .0025);     // bolt rail L
  r = opU(r, vec2(rc, M_GUNMETAL));
  r = opU(r, vec2(sdBox(p - vec3(0., .062, -.115), vec3(.0045, .007, .012)), M_GUNMETAL)); // rear sight
  r = opU(r, vec2(max(sdTorus((p - vec3(0., -.058, -.03)).xzy, vec2(.028, .0045)), -(p.y + .045)), M_GUNMETAL));
  r = opU(r, vec2(sdCapsule(p, vec3(0., -.04, -.025), vec3(0., -.068, -.035), .003), M_GUNMETAL));
  // wooden stock: side profile (z back, y up) as a convex polygon, extruded and rounded.
  // wrist leaves the receiver's rear face, comb drops gently, deep butt with rubber pad.
  vec2 q = vec2(p.z, p.y);
  float prof = -1e5;
  const int NP = 6;
  vec2 P[6] = vec2[6](vec2(-.125, .052), vec2(-.555, .012), vec2(-.565, -.148), vec2(-.30, -.082), vec2(-.17, -.062), vec2(-.125, -.035));
  for (int i = 0; i < NP; i++){
    vec2 e = P[(i + 1) % NP] - P[i];
    vec2 nn = normalize(vec2(e.y, -e.x));
    prof = max(prof, dot(q - P[i], nn));
  }
  float halfW = .017 + .006 * smoothstep(-.2, -.5, p.z);          // stock thickens toward the butt
  float stock = length(max(vec2(prof + .008, abs(p.x) - halfW + .008), 0.)) + min(max(prof + .008, abs(p.x) - halfW + .008), 0.) - .008;
  // semi-pistol grip swell under the wrist
  float grip = sdRoundBox(rotX(p - vec3(0., -.075, -.17), -.45), vec3(.017, .045, .022), .012);
  r = opU(r, vec2(smin(stock, grip, .02), M_WOOD));
  // rubber buttpad
  float pad = max(abs(p.z + .567) - .008, abs(p.x) - halfW);
  pad = max(pad, dot(vec2(p.z, p.y) - vec2(-.56, .0), vec2(0., 1.)) - .012);
  pad = max(pad, -(p.y + .15));
  r = opU(r, vec2(pad, M_GUNMETAL));
  return r;
}



vec2 gunSDF(vec3 p){
  vec3 q = p - gGunO;
  if (dot(q, q) > .8) return vec2(length(q) - .85, 0.);
  vec3 l = vec3(dot(q, gGunR), dot(q, gGunU), dot(q, gGunF));
  // flashlight clamped under the barrel
  vec2 r = sdKS23Detail(l, uP[1]);
  r = opU(r, vec2(sdCylZ(l - vec3(0., -.06, .44), .022, .07), M_GUNMETAL));
  r = opU(r, vec2(sdBox(l - vec3(0., -.045, .44), vec3(.008, .012, .03)), M_GUNMETAL));
  return r;
}

vec2 room(vec3 p){
  vec2 r = vec2(p.y, MF_FLOOR);
  r = opU(r, vec2(3.1 - p.y, MF_CEIL));
  float wall = 2.1 - abs(p.x);
  // side doorways (dark voids) at z 10 (right, +x) and z 12 (left, -x)
  float door = min(sdBox(p - vec3(2.4, 1.1, 10.), vec3(.6, 1.1, .6)), sdBox(p - vec3(-2.4, 1.1, 12.), vec3(.6, 1.1, .6)));
  wall = max(wall, -door);
  r = opU(r, vec2(wall, MF_WALL));
  // back room behind the doorways (so rays find something)
  r = opU(r, vec2(max(abs(p.x) - 4., -(abs(p.x) - 2.2)) , MF_WALL));
  // far wall with double doors
  r = opU(r, vec2(31. - p.z, MF_DOOR));
  // pilasters
  float pz = mod(p.z, 4.) - 2.;
  r = opU(r, vec2(sdBox(vec3(abs(p.x) - 2.1, p.y - 1.5, pz), vec3(.12, 1.6, .18)), MF_WALL));
  // pipes on the ceiling
  r = opU(r, vec2(length(vec2(p.x - 1.4, p.y - 2.9)) - .09, MF_PIPE));
  r = opU(r, vec2(length(vec2(p.x - 1.15, p.y - 2.95)) - .06, MF_PIPE));
  r = opU(r, vec2(sdBox(vec3(p.x + 1.3, p.y - 2.95, 0.), vec3(.25, .03, 1e3)), MF_PIPE));
  // red beacons
  r = opU(r, vec2(sdCylY(p - vec3(0., 3.0, 7.), .09, .1), MF_BEACON));
  r = opU(r, vec2(sdCylY(p - vec3(0., 3.0, 17.), .09, .1), MF_BEACON));
  // overturned canteen tables
  vec3 tq = p - vec3(-1.25, .4, 5.2); tq.xz *= rot2(.25);
  r = opU(r, vec2(sdBox(tq, vec3(.8, .4, .03)), MF_TABLE));
  vec3 tq2 = p - vec3(1.35, .38, 14.); tq2.xz *= rot2(-.4); tq2.xy *= rot2(.1);
  r = opU(r, vec2(sdBox(tq2, vec3(.8, .38, .03)), MF_TABLE));
  // its legs sticking out toward the camera
  vec3 tl = p - vec3(-1.25, 0., 5.2); tl.xz *= rot2(.25);
  r = opU(r, vec2(sdCapsule(vec3(abs(tl.x) - .7, abs(tl.y - .4) - .3, tl.z), vec3(0.), vec3(0., 0., -.7), .025), MF_TABLE));
  return r;
}

vec2 map(vec3 p){
  vec2 r = room(p);
  float t = uP[14];
  for (int i = 0; i < NM; i++){
    if (mSeed(i) < 0.) continue;
    r = opU(r, monsterSDF(p, i, t));
  }
  r = opU(r, crowd(p));
  r = opU(r, gunSDF(p));
  return r;
}

vec3 calcNormal(vec3 p){
  const vec2 k = vec2(1., -1.); const float e = .0012;
  return normalize(k.xyy * map(p + k.xyy * e).x + k.yyx * map(p + k.yyx * e).x + k.yxy * map(p + k.yxy * e).x + k.xxx * map(p + k.xxx * e).x);
}
float calcAO(vec3 p, vec3 n){
  float o = 0., s = 1.;
  for (int i = 0; i < 2; i++){ float h = .05 + .15 * float(i); o += (h - map(p + n * h).x) * s; s *= .7; }
  return clamp(1. - 2.2 * o, 0., 1.);
}

// blood pools under the dead
float bloodPools(vec3 p, float t){
  float m = 0.;
  for (int i = 0; i < NM; i++){
    float th = mHit(i);
    if (t < th + .3) continue;
    vec3 pos = cPos[i];
    vec2 c = pos.xz + vec2(0., mKS(i) > .5 ? .8 : -.8);
    float r = .5 + .9 * smoothstep(0., 6., t - th);
    m = max(m, smoothstep(r, r * .6, length((p.xz - c) * vec2(1., .7)) + (fbm2(p.xz * 5.) - .5) * .4));
  }
  return m;
}

vec3 albedo(float m, vec3 p, out float rough){
  rough = .75;
  float t = uP[14];
  if (m == MF_WALL){
    float n = fbm3lo(p * 2.);
    vec3 cream = mix(vec3(.3, .28, .23), vec3(.2, .19, .16), n);
    vec3 green = mix(vec3(.07, .1, .085), vec3(.05, .07, .06), n);
    vec3 c = mix(green, cream, smoothstep(1.28, 1.3, p.y));
    c *= mix(.5, 1., smoothstep(0., .6, p.y));
    float fr = smoothstep(.55, .75, fbm3lo(p * 2.7)) * (1. - smoothstep(.2, 1.3, p.y));
    c = mix(c, vec3(.5, .56, .63), fr * .7);
    // spatter where the fighting happened
    if (abs(p.z - 8.) < 1.6) c = mix(c, vec3(.12, .01, .01), bloodSplat(vec2(p.z - 8., p.y - 1.2), 5.1 + sign(p.x)) * .85);
    if (abs(p.z - 13.5) < 1.6 && p.x < 0.) c = mix(c, vec3(.12, .01, .01), bloodSplat(vec2(p.z - 13.5, p.y - 1.), 2.3) * .8);
    return c;
  }
  if (m == MF_FLOOR){
    vec3 c = vec3(.06, .058, .055) * (.6 + .6 * fbm2(p.xz * 1.5));
    float fr = smoothstep(.55, .75, fbm2(p.xz * .9 + 3.));
    c = mix(c, vec3(.45, .5, .55), fr * .5);
    rough = mix(.6, .25, fr);
    float bp = bloodPools(p, t);
    c = mix(c, vec3(.09, .006, .006), bp);
    rough = mix(rough, .06, bp);
    return c;
  }
  if (m == MF_CEIL) return vec3(.04);
  if (m == MF_TABLE){ rough = .5; return vec3(.18, .12, .07) * (.6 + .5 * fbm3lo(p * 5.)); }
  if (m == MF_PIPE){ rough = .5; return vec3(.08); }
  if (m == MF_DOOR){ rough = .6; return vec3(.06, .08, .07) * (.7 + .5 * fbm3lo(p * 3.)); }
  if (m == MF_BEACON){ rough = .3; return vec3(.3, .02, .02); }
  if (m == M_WOOD){ rough = .35; return mix(vec3(.07, .032, .014), vec3(.2, .1, .042), fbm3lo(p * vec3(30., 30., 6.))); }
  if (m == M_GUNMETAL){ rough = .2; return vec3(.03, .033, .04); }
  if (m <= 4.){ rough = m == M_GORE ? .1 : .55; return monsterAlbedo(m, p); }
  return vec3(.2);
}

// ---------------------------------------------------------------- lights
struct Lit { vec3 d; vec3 s; };
void addLight(inout Lit L, vec3 p, vec3 n, vec3 v, float rough, vec3 lp, vec3 col){
  vec3 l = lp - p; float d2 = dot(l, l); l *= inversesqrt(d2);
  float ndl = max(dot(n, l), 0.);
  col /= (1. + d2);
  L.d += col * ndl;
  vec3 h = normalize(l + v);
  L.s += col * ndl * pow(max(dot(n, h), 0.), mix(100., 10., rough)) * (1. - rough);
}
vec3 beaconDir(float z, float t){ float a = t * 4.8 + z * .3; return normalize(vec3(cos(a), -.45, sin(a))); }

Lit lighting(vec3 p, vec3 n, vec3 v, float rough){
  Lit L; L.d = vec3(0.); L.s = vec3(0.);
  float t = uP[14];
  // rotating red beacons
  for (int i = 0; i < 2; i++){
    vec3 bp = vec3(0., 2.9, i == 0 ? 7. : 17.);
    vec3 dir = beaconDir(bp.z, t);
    float cone = smoothstep(.72, .93, dot(normalize(p - bp), dir));
    addLight(L, p, n, v, rough, bp, vec3(1., .06, .03) * (cone * 6. + .4));
  }
  // torch under the barrel
  vec3 tp = gMuzzle - gGunF * .15 - gGunU * .06;
  float sp = spotLight(p, tp, gGunF, .955, .99) * mix(1., flashCookie(p, tp, gGunF), .3);
  addLight(L, p, n, v, rough, tp, vec3(1., .96, .88) * sp * 8. * (1. - .5 * uP[6]) * (1. + dot(p - tp, p - tp)));
  // KS-23 muzzle flash
  if (uP[0] > 0.) addLight(L, p, n, v, rough, gMuzzle + gGunF * .3, vec3(1., .7, .35) * uP[0] * 9.);
  // side guns' muzzle flash (off screen left)
  if (uP[3] > 0.) addLight(L, p, n, v, rough, vec3(1.7, 1.35, .6), vec3(1., .75, .4) * uP[3] * 14.);
  // flare
  if (uP[6] > 0.){
    float fl = uP[6] * (.8 + .2 * noise2(vec2(t * 13., 1.)) + .1 * sin(t * 31.));
    addLight(L, p, n, v, rough, gFlare + vec3(0., .15, 0.), vec3(1., .12, .35) * fl * 45.);
  }
  return L;
}

// blood spray particles for the hits
vec4 bloodSpray(vec3 ro, vec3 rd, float maxD, float t){
  vec4 acc = vec4(0.);
  for (int i = 0; i < NM; i++){
    float d = t - mHit(i);
    if (d < 0. || d > 1.4) continue;
    vec3 pos; float yaw, run, fall;
    monsterState(i, mHit(i), pos, yaw, run, fall);
    vec3 o = pos + vec3(0., 1.25, 0.);
    float ks = mKS(i);
    for (int k = 0; k < 18; k++){
      vec3 hsh = hash33(vec3(float(i), float(k), 3.));
      vec3 vel = normalize(vec3(hsh.x - .5, hsh.y * .8 - .1, .4 + hsh.z * (ks > .5 ? 1.2 : .5))) * (2. + 5. * hsh.x) * (ks > .5 ? 1. : .6);
      if (i == 6 && k < 7) vel.z = -abs(vel.z) - 3.;                  // point blank: toward the camera
      vec3 pp = o + vel * d + vec3(0., -4.9 * d * d, 0.);
      if (pp.y < 0.) continue;
      float tc = dot(pp - ro, rd);
      if (tc < 0. || tc > maxD) continue;
      float dist = length(ro + rd * tc - pp);
      float rad = (.018 + .03 * hsh.z) * (1. + d);
      float a = smoothstep(rad, rad * .5, dist) * (1. - smoothstep(1., 1.4, d));
      acc = mix(acc, vec4(vec3(.07, .004, .004), 1.), a);
    }
  }
  return acc;
}

vec3 render(vec2 fc){
  float t = uP[14];
  vec3 aimP = vec3(uP[11], uP[12], uP[13]);
  float rec = uP[2];
  gRo = vec3(.1 + .03 * sin(t * .9), 1.62 + .012 * sin(t * 5.3), 0.);
  vec3 ta = aimP + vec3(.08 * (noise2(vec2(t * 1.3, 2.)) - .5), .06 * (noise2(vec2(t * 1.1, 5.)) - .5) + rec * .5, 0.);
  vec3 rd = camRay(fc, gRo, ta, 1.3, .02 * sin(t * .7) - .04 * rec);
  cacheMonsters(t);
  vec3 f = normalize(ta - gRo);
  vec3 rgt = normalize(cross(f, vec3(0., 1., 0.)));
  vec3 up = cross(rgt, f);
  // gun in view: lower right, canted slightly, kicking on recoil, rolling with the pump
  gGunF = normalize(f + up * (.03 + rec * .35) + rgt * .02);
  gGunR = normalize(cross(gGunF, up));
  gGunU = cross(gGunR, gGunF);
  float cant = .12 + uP[1] * .15;
  vec3 r2 = gGunR * cos(cant) + gGunU * sin(cant);
  gGunU = gGunU * cos(cant) - gGunR * sin(cant); gGunR = r2;
  gGunO = gRo + rgt * .16 - up * (.135 - rec * .03) + f * (.42 - rec * .09);
  gMuzzle = gGunO + gGunF * .63 + gGunU * .02;
  // flare arc
  vec3 fa = vec3(1.6, 1.4, 1.), fb = vec3(-.3, .05, 16.6);
  float fk = uP[7];
  gFlare = mix(fa, fb, fk) + vec3(0., 3.2 * fk * (1. - fk), 0.);

  float d = 0.; vec2 h = vec2(0.); bool hit = false;
  for (int i = 0; i < 120; i++){
    h = map(gRo + rd * d);
    if (h.x < .0015 * (1. + d)){ hit = true; break; }
    d += h.x * .9;
    if (d > 40.) break;
  }
  vec3 col = vec3(0.);
  if (hit){
    vec3 p = gRo + rd * d, n = calcNormal(p), v = -rd;
    float rough; vec3 alb = albedo(h.y, p, rough);
    Lit L = lighting(p, n, v, rough);
    float ao = calcAO(p, n);
    col = alb * (L.d + vec3(.006, .004, .004)) * mix(.35, 1., ao) + L.s * ao;
    if (h.y <= 4.){ float fr = pow(1. - max(dot(n, v), 0.), 3.); col += fr * L.s * .6 + fr * L.d * .05; }
    if (h.y == M_WOOD || h.y == M_GUNMETAL){
      // the gun in hand catches red beacon spill and the torch's bounce off the floor
      col += alb * (vec3(.12, .02, .015) * (.6 + .4 * sin(t * 4.8)) + vec3(.05, .045, .04) * max(-n.y, 0.) + vec3(.03) * max(n.y, 0.));
      col += vec3(.25, .05, .03) * pow(1. - max(dot(n, v), 0.), 4.) * .5;
    }
    if (h.y == MF_BEACON) col += vec3(1., .05, .02) * (2. + 6. * pow(max(0., dot(beaconDir(p.z, t), -rd)), 4.));
  }
  // haze: beacons, torch, flare smoke, gun smoke, muzzle light
  float dith = hash21(fc + fract(t * 3.) * 41.);
  float maxD = min(hit ? d : 40., 30.);
  vec3 fog = vec3(0.); float smokeA = 0.;
  for (int i = 0; i < 9; i++){
    float s = (float(i) + dith) / 9.; s = s * s * maxD;
    vec3 q = gRo + rd * s;
    float dens = .45 + .55 * noise3(q * .7 + vec3(0., t * .1, t * .2));
    for (int b = 0; b < 2; b++){
      vec3 bp = vec3(0., 2.9, b == 0 ? 7. : 17.);
      vec3 L = q - bp; float dl = length(L);
      fog += vec3(1., .06, .03) * smoothstep(.8, .95, dot(L / dl, beaconDir(bp.z, t))) * 3. / (1. + dl * dl * .15) * dens;
    }
    vec3 tp = gMuzzle - gGunF * .15;
    fog += vec3(1., .96, .88) * spotLight(q, tp, gGunF, .955, .99) * 2.5 * dens * (1. - .75 * uP[6]);
    if (uP[0] > 0.) fog += vec3(1., .7, .35) * uP[0] * 1.2 / (1. + dot(q - gMuzzle, q - gMuzzle) * 6.);
    if (uP[6] > 0.){
      vec3 fq = q - gFlare;
      float sm = smoothstep(4.5, 0., length(fq * vec3(1., .8, .6))) * uP[6] * (.5 + .5 * fbm3lo(q * .8 + vec3(0., -t * .4, 0.)));
      fog += vec3(1., .15, .38) * (sm * 4. + 3. / (1. + dot(fq, fq) * .6)) * uP[6];
    }
  }
  col += fog * maxD / 9. * .02;
  // flare core
  if (uP[6] > 0.){
    float tc = dot(gFlare - gRo, rd);
    float dd = length(gRo + rd * tc - gFlare);
    if (tc > 0. && (!hit || tc < d + .3)) col += vec3(1., .5, .7) * uP[6] * (smoothstep(.06, .0, dd) * 6. + .02 / (dd * dd + .01) * .05);
  }
  // tracers from the side guns
  if (uP[4] >= 0.){
    int tgt = t < 8. ? 1 : (t < 12. ? 4 : 5);
    vec3 tpos; float yw, rn, fl;
    monsterState(tgt, min(t, mHit(tgt)), tpos, yw, rn, fl);
    vec3 a = vec3(1.9, 1.35, .8), b = tpos + vec3(.05 * sin(t * 50.), 1.2 + .2 * sin(t * 37.), 0.);
    vec3 dir = normalize(b - a);
    float tr = uP[4] * 320.;
    vec3 s0 = a + dir * max(tr - 5., 0.), s1 = a + dir * min(tr, length(b - a));
    // closest distance between the view ray and the tracer segment
    vec3 u = s1 - s0, w0 = gRo - s0;
    float aa = dot(rd, rd), bb = dot(rd, u), cc = dot(u, u), dd2 = dot(rd, w0), ee = dot(u, w0);
    float den = max(aa * cc - bb * bb, 1e-5);
    float sc = clamp((bb * ee - cc * dd2) / den, 0., 100.), tc2 = clamp((aa * ee - bb * dd2) / den, 0., 1.);
    float dist = length(gRo + rd * sc - (s0 + u * tc2));
    if (!hit || sc < d) col += vec3(1., .75, .4) * smoothstep(.02, .0, dist) * 5. * step(tr, length(b - a) + 5.);
  }
  // KS-23 muzzle flash sprite
  if (uP[0] > 0.){
    float tc = dot(gMuzzle - gRo, rd);
    vec3 cp = gRo + rd * tc - gMuzzle;
    float along = dot(cp, gGunF), across = length(cp - gGunF * along);
    float star = smoothstep(.05 + .08 * uP[0], 0., across + abs(along - .14) * .3) + smoothstep(.012, 0., across) * smoothstep(.4, 0., abs(along - .2));
    col += vec3(1.5, .9, .45) * star * uP[0] * 5.;
  }
  // blood spray
  vec4 bs = bloodSpray(gRo, rd, hit ? d : 40., t);
  vec3 bl = bs.rgb * (.4 + 3. * uP[0]) + vec3(.2, .01, .01) * .15;
  col = mix(col, bl + col * .15, bs.a);
  return col;
}
