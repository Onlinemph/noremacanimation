// ============================================================================
// s07_fight — "The staff charge." First-person KS-23 corridor firefight.
// Camera = Hollis. Gun = sdKS23 held lower-right, attached to camera frame.
//
// Timeline (seconds, kept in exact sync with shot.js params()/post() and cues.json):
//   0.0        power dead, red beacon sweeps, silence
//   1.2 / 1.6  monster A / B visible far end, idle twitch in flashlight sweep
//   3.3        growl
//   4.0        shriek, A & B start sprinting (charge)
//   5.00       KS23 SHOT 1  -> kills A                 pump 5.08-5.43
//   5.6        A body_fall
//   8.4        AK burst     -> kills B                 body_fall 8.85
//   8.0-15.5   horde C..H,J enter from side doors / far end, sprinting
//   9.3        PPSH burst   -> kills C                 body_fall 9.7
//   10.6       KS23 SHOT 2  -> kills D                 pump 10.68-11.03, body_fall 11.0
//   11.6       AK burst     -> kills E                 body_fall 12.05
//   13.0       PPSH burst   -> kills F                 body_fall 13.45
//   14.2       KS23 SHOT 3  -> kills G, blood hits lens  pump 14.28-14.63, body_fall 14.6
//   15.3       AK burst     -> kills H                 body_fall 15.75
//   16.4       PPSH burst   -> grazes J (stagger)
//   17.0       KS23 SHOT 4, POINT BLANK -> kills J      pump 17.08-17.43, body_fall 17.3
//   18.3       flare_shot (Okafor), arcs 18.3->19.6
//   19.6       flare lands far end, floods red, smoke
//   20.4-23.4  drone_swell / stinger(20.6), reveal of crowd, beat, they turn 22.5-23.2
//   22.8-23.6  fade to black
// ============================================================================

// ---------------------------------------------------------------- geometry --
float corrHalfW(float z){ return 1.9 + smoothstep(8.0, 12.0, z) * 1.7; }
const float CORR_H = 2.65;
const float FAR_Z = 19.0;

vec2 room(vec3 p){
  float hw = corrHalfW(p.z);
  vec2 r = vec2(p.y, M_STEEL);                          // floor
  r = opU(r, vec2(CORR_H - p.y, M_STEEL));               // ceiling
  r = opU(r, vec2(hw - abs(p.x), M_STEEL));              // side walls
  r = opU(r, vec2(FAR_Z - p.z, M_CONCRETE));             // far wall
  // door recesses (visual alcoves, side doors the horde bursts from)
  float rec1 = sdBox(p - vec3(sign(p.x) * (hw - .08), 1.15, 6.3), vec3(.1, 1.05, 1.0));
  float rec2 = sdBox(p - vec3(sign(p.x) * (hw - .08), 1.15, 8.4), vec3(.1, 1.05, .9));
  r = opU(r, vec2(min(rec1, rec2), M_CONCRETE));
  // ceiling pipe/beams for industrial detail
  for (int i = 0; i < 4; i++){
    float bz = 2.0 + float(i) * 3.6;
    r = opU(r, vec2(sdCylX(p - vec3(0., CORR_H - .12, bz), .05, hw - .1), M_GUNMETAL));
  }
  return r;
}

vec2 tables(vec3 p){
  vec2 r = vec2(1e5, 0.);
  vec3 t1 = p - vec3(-1.0, .35, 2.2); t1.xz *= rot2(.6); t1.yz *= rot2(1.15);
  r = opU(r, vec2(sdRoundBox(t1, vec3(.7, .04, .45), .02), M_STEEL));
  vec3 t1l = p - vec3(-1.0, .0, 2.2);
  r = opU(r, vec2(sdCylY(t1l - vec3(.5, .3, .1), .03, .3), M_GUNMETAL));
  vec3 t2 = p - vec3(1.1, .22, 3.4); t2.xz *= rot2(-.3); t2.yz *= rot2(-.35);
  r = opU(r, vec2(sdRoundBox(t2, vec3(.65, .04, .42), .02), M_STEEL));
  vec3 t3 = p - vec3(-.5, .06, 4.6); t3.xz *= rot2(.15);
  r = opU(r, vec2(sdRoundBox(t3, vec3(.6, .05, .4), .03), M_STEEL));
  return r;
}

// ------------------------------------------------------------ fight cast ----
float fVisT(int i){ float a[9] = float[9](1.2, 1.6, 7.7, 8.0, 8.3, 9.3, 9.6, 10.2, 15.2); return a[i]; }
float fChargeT(int i){ float a[9] = float[9](4.0, 4.0, 8.0, 8.3, 8.6, 9.6, 9.9, 10.6, 15.5); return a[i]; }
float fKillT(int i){ float a[9] = float[9](5.0, 8.4, 9.3, 10.6, 11.6, 13.0, 14.2, 15.3, 17.0); return a[i]; }
float fSeed(int i){ float a[9] = float[9](.18, .42, .55, .71, .29, .83, .63, .37, .90); return a[i]; }
vec2 fSpawnXZ(int i){
  vec2 a[9] = vec2[9](
    vec2(-.5, 9.2), vec2(.6, 9.6),
    vec2(-2.4, 6.4), vec2(2.4, 6.6),
    vec2(-2.2, 7.6), vec2(2.3, 7.2),
    vec2(-.3, 11.5), vec2(2.1, 6.2),
    vec2(.3, 5.3)
  );
  return a[i];
}
// Each monster is shot while still several meters out; only the last (index 8,
// the point-blank kill) is allowed to close to near-camera range. Targets must
// stay well clear of the camera origin (z ~ -0.35) or the raymarch starts
// inside solid geometry and the whole frame goes black.
vec2 fTargetXZ(int i){
  vec2 a[9] = vec2[9](
    vec2(-.15, 2.6), vec2(.25, 3.4),
    vec2(-.5, 3.0), vec2(.5, 3.6),
    vec2(-.4, 2.8), vec2(.45, 3.2),
    vec2(-.2, 2.4), vec2(.35, 3.0),
    vec2(.15, 1.75)
  );
  return a[i];
}

vec2 fightPosXZ(int i, float t){
  float t0 = fChargeT(i), t1 = fKillT(i);
  vec2 sp = fSpawnXZ(i), tp = fTargetXZ(i);
  float f = clamp((t - t0) / max(t1 - t0, .001), 0., 1.);
  f = f * f * (3. - 2. * f);
  vec2 pos = mix(sp, tp, f);
  if (t > t1){
    vec2 back = normalize(sp - tp);
    pos += back * min((t - t1) * 5.0, 1.3);
  }
  return pos;
}

vec3 fightClothAlbedo(float m, float seed, vec3 p){
  vec3 base = monsterAlbedo(m, p);
  if (m == M_CLOTH && seed > .5) base = mix(base, vec3(.22, .19, .10), .6); // telogreika
  return base;
}

vec2 evalFightMonster(int i, vec3 p, float t){
  float vt = fVisT(i);
  if (t < vt) return vec2(1e4, 0.);
  vec2 pxz = fightPosXZ(i, t);
  vec3 wp = vec3(pxz.x, 0., pxz.y);
  float t0 = fChargeT(i), t1 = fKillT(i);
  float seed = fSeed(i);
  vec3 lp = p - wp;
  float wobble = .15 * sin(seed * 40. + t * .7);
  lp.xz *= rot2(PI + wobble);
  bool fallen = t > t1;
  float fallAge = t - t1;
  if (fallen){
    float fp = clamp((fallAge - .05) / .5, 0., 1.); fp = fp * fp * (3. - 2. * fp);
    lp.yz *= rot2(fp * 1.7);
  }
  if (fallen && fallAge > 2.0){
    vec2 r = vec2(sdCapsule(lp, vec3(0, .15, .1), vec3(0, .32, 1.05), .27) - .015,
                  fract(seed * 7.) > .5 ? M_CLOTH : M_SKIN);
    return r;
  }
  float bound = sdCapsule(lp, vec3(0, .2, 0), vec3(0, 2.1, 0), 1.0);
  if (bound > .2) return vec2(bound, 0.);
  float run = t < t0 ? 0. : 1.;
  float animT = min(t, t1);
  return sdMonster(lp, animT, seed, run);
}

// blood spray: a handful of SDF droplets flung from the hit point at the instant
// of each kill, arcing under gravity and shrinking — reads clearly against the
// muzzle-flash / lit background for one glance legibility.
vec2 evalBloodSpray(vec3 p, float t){
  vec2 r = vec2(1e5, M_GORE);
  for (int i = 0; i < 9; i++){
    float kt = fKillT(i);
    float dt = t - kt;
    if (dt < 0.0 || dt > 0.4) continue;
    vec2 hitxz = fightPosXZ(i, kt);
    vec3 hp = vec3(hitxz.x, 1.1, hitxz.y);
    float seed = fSeed(i);
    for (int k = 0; k < 5; k++){
      vec3 h3 = hash33(vec3(seed * 7.0 + float(k), float(i), 3.1));
      vec3 dir = normalize(vec3(h3.x - .5, h3.y * .6 + .15, -(h3.z * .5 + .25)));
      float spd = 2.2 + 2.6 * h3.x;
      vec3 dp = hp + dir * spd * dt - vec3(0., 4.2 * dt * dt, 0.);
      float rad = max(.004, .05 * (1.0 - dt / 0.4));
      r = opU(r, vec2(sdSphere(p - dp, rad), M_GORE));
    }
  }
  return r;
}

// ------------------------------------------------------------- reveal crowd -
vec2 cVec(int i){
  vec2 a[10] = vec2[10](
    vec2(-1.6, 14.0), vec2(1.2, 14.6), vec2(-.2, 15.2),
    vec2(-2.6, 15.6), vec2(2.4, 15.2), vec2(-1.0, 16.4),
    vec2(1.6, 16.8), vec2(0., 17.6), vec2(-2.8, 17.2), vec2(2.9, 16.2)
  );
  return a[i];
}
vec2 cheapHuman(vec3 p, float seed){
  float body = sdCapsule(p, vec3(0, .17, 0), vec3(0, 1.5, 0), .17 + .015 * sin(seed * 30.));
  vec3 hp = p - vec3(.02 * sin(iTime * 9. + seed * 20.), 1.72, 0.);
  float head = sdSphere(hp, .105);
  return vec2(min(body, head), fract(seed * 5.) > .5 ? M_CLOTH : M_SKIN);
}
vec2 evalCrowd(int i, vec3 p, float t){
  vec2 base = cVec(i);
  vec3 wp = vec3(base.x, 0., base.y);
  vec3 lp = p - wp;
  float seed = hash11(float(i) * 3.71 + 2.0);
  float yaw = .7 * sin(seed * 12.) + PI * smoothstep(22.5, 23.3, t);
  lp.xz *= rot2(yaw);
  if (i < 3){
    float bound = sdCapsule(lp, vec3(0, .2, 0), vec3(0, 2.1, 0), 1.0);
    if (bound > .2) return vec2(bound, 0.);
    return sdMonster(lp, t, seed, 0.0);
  }
  return cheapHuman(lp, seed);
}

// -------------------------------------------------------------------- gun ---
vec3 gRight, gUp, gFwd, gGunPos;
vec2 evalGun(vec3 p){
  vec3 pg = p - gGunPos;
  vec3 pl = vec3(dot(pg, gRight), dot(pg, gUp), dot(pg, gFwd));
  float pump = uP[1];
  pl.yz *= rot2(-.55 - .12 * pump);          // held low, tilted up-right into frame
  pl.xy *= rot2(.10);
  vec2 g = sdKS23(pl * 1.15, pump);
  g.x /= 1.15;
  return g;
}

// --------------------------------------------------------------------- map --
vec2 map(vec3 p){
  vec2 r = room(p);
  r = opU(r, tables(p));
  for (int i = 0; i < 9; i++) r = opU(r, evalFightMonster(i, p, iTime));
  r = opU(r, evalBloodSpray(p, iTime));
  if (iTime > 18.6) for (int i = 0; i < 10; i++) r = opU(r, evalCrowd(i, p, iTime));
  r = opU(r, evalGun(p));
  return r;
}
vec3 nrm(vec3 p){ vec2 e = vec2(.0015, 0); return normalize(vec3(
  map(p + e.xyy).x - map(p - e.xyy).x,
  map(p + e.yxy).x - map(p - e.yxy).x,
  map(p + e.yyx).x - map(p - e.yyx).x)); }

// ---------------------------------------------------------------- shading ---
vec3 shade(vec3 p, vec3 n, vec3 rd, float m, float seed){
  vec3 alb;
  float spec;
  if (m == 0.) { alb = vec3(.06, .065, .075) * (.7 + .5 * fbm3lo(p * 3.)); spec = .15; }         // gun-attached "misc" or default steel
  else if (m <= 4.5) { alb = fightClothAlbedo(m, seed, p); spec = monsterSpec(m); }
  else if (m <= 6.5) { alb = gunAlbedo(m, p); spec = .55; }
  else if (m == M_CONCRETE){ alb = mix(vec3(.14,.14,.15), vec3(.03,.03,.035), smoothstep(.4,.8,fbm3lo(p*1.5))); spec=.05; }
  else { // M_STEEL walls/floor/ceiling: grime, frost, old paint, blood
    // fade high-frequency detail with distance to avoid aliasing/static on far surfaces
    float distFade = clamp(1.0 - length(p - (gGunPos)) * .045, .35, 1.0);
    float grime = fbm3lo(p * (0.9 * distFade + .15));
    vec3 paint = mix(vec3(.10, .13, .11), vec3(.03, .035, .04), smoothstep(.3, .75, grime));
    float frost = smoothstep(.55, .8, fbm3lo(p * (1.1 * distFade + .2) + vec3(0,0,9.)));
    paint = mix(paint, vec3(.55, .62, .68) * .5, frost * step(p.y, .05));
    float bl = 0.;
    if (p.y < .06) bl = max(bl, bloodSplat(p.xz * .5 + 11., 4.1));
    for (int i = 0; i < 9; i++){ if (fKillT(i) < iTime){ vec2 sp = fightPosXZ(i, min(iTime, fKillT(i) + 3.)); bl = max(bl, bloodSplat((p.xz - sp) * .8 + float(i)*3., float(i)+1.3)); } }
    paint = mix(paint, goreColor(p) * .6, bl * step(p.y, .08));
    alb = paint; spec = .08 + frost * .3;
  }
  vec3 lit = vec3(0.);
  float ao = clamp(map(p + n * .18).x / .18, .1, 1.);
  float rim = pow(1.0 - max(dot(n, -rd), 0.), 3.0);
  bool isGun = (m > 4.5 && m < 6.5);

  // rotating red emergency beacon: a tight sweeping cone, not a fill
  vec3 bpos = vec3(0., CORR_H - .1, 1.2);
  float bang = iTime * 1.9;
  vec3 bdir = normalize(vec3(sin(bang), -.22, cos(bang)));
  float bsweep = spotLight(p, bpos, bdir, .55, .93) * (.55 + .45 * abs(sin(bang * 2.)));
  vec3 L1 = normalize(bpos - p);
  lit += vec3(1., .05, .04) * bsweep * max(dot(n, L1), 0.) * 2.6;
  if (isGun) lit += vec3(1., .05, .04) * bsweep * rim * 1.6;

  // flashlight mounted under the gun, aimed with camera
  vec3 fdir = gFwd;
  vec3 L2 = normalize(gGunPos - p);
  float fl = spotLight(p, gGunPos, fdir, .80, .975) * flashCookie(p, gGunPos, fdir);
  lit += vec3(.85, .92, 1.0) * fl * max(dot(n, L2), 0.) * 6.5;
  if (isGun) lit += vec3(.85, .92, 1.0) * .5 * rim;

  // muzzle flash: brief, blinding, whites out whatever it hits
  float mf = uP[2];
  if (mf > .001){
    vec3 mpos = gGunPos + gFwd * .62;
    vec3 L3 = normalize(mpos - p);
    float d3 = length(mpos - p);
    lit += vec3(1., .82, .55) * mf * max(dot(n, L3), 0.) * 9. / (1. + d3 * d3 * .6);
    if (isGun) lit += vec3(1., .8, .55) * mf * 1.2;
  }

  // AK / PPSh strobing muzzle flashes from off-screen left
  float ak = uP[4], pp = uP[5];
  if (ak + pp > .001){
    vec3 lpos = vec3(-3.6, 1.5, 1.0);
    vec3 L4 = normalize(lpos - p);
    lit += vec3(.9, .93, 1.0) * (ak + pp) * max(dot(n, L4), 0.) * 2.6;
  }

  // flare: airborne, then a small, intense, localized core on the ground far end.
  // Falls off hard within ~6-8m so it does not wash the whole corridor pink; anything
  // between the flare and camera (the crowd) stays a dark silhouette against the glow.
  float fp = uP[6], fg = uP[7], rv = uP[8];
  if (fp > .001 || rv > .001){
    float arc = sin(fp * PI) * 2.2;
    vec3 flarePos = mix(vec3(-1.1, 1.6, .2), vec3(.2, .25, 15.5), fp) + vec3(0., arc, 0.);
    vec3 L5 = normalize(flarePos - p);
    float d5 = length(flarePos - p);
    float pls = .75 + .25 * sin(iTime * 5.0);
    float falloff = 1. / (1. + d5 * d5 * .55);
    lit += vec3(1., .10, .30) * (fp > .001 && fp < 1. ? 1.4 : fg * pls) * max(dot(n, L5), 0.) * 12. * falloff;
    if (isGun) lit += vec3(1., .12, .32) * fg * rim * 1.2 * falloff;
  }

  vec3 col = lit * ao;
  // near-black ambient floor: keeps unlit surfaces reading as silhouette, not grey mush
  col += alb * .006;
  if (isGun) col += alb * .02; // just enough that the gun never vanishes to pure void
  // specular from strongest nearby source (beacon/flashlight combined dir approx)
  vec3 Ls = normalize(L2 + L1 * .3);
  float sp = pow(max(dot(reflect(-Ls, n), -rd), 0.), 28.) * spec;
  col += (fl * 3. + bsweep + mf * 2.) * sp;
  col *= alb;
  return col;
}

// -------------------------------------------------------------- volumetrics -
vec3 volumetric(vec3 ro, vec3 rd, float tmax){
  vec3 acc = vec3(0.);
  float steps = 7.0;
  float dith = hash21(gl_FragCoord.xy + iTime * 91.7);
  vec3 bpos = vec3(0., CORR_H - .1, 1.2);
  float bang = iTime * 1.9;
  vec3 bdir = normalize(vec3(sin(bang), -.22, cos(bang)));
  float fp = uP[6], fg = uP[7];
  vec3 flarePos = mix(vec3(-1.1, 1.6, .2), vec3(.2, .25, 15.5), fp) + vec3(0., sin(fp*PI)*2.2, 0.);
  for (int i = 0; i < 7; i++){
    float ti = (float(i) + dith) / steps * min(tmax, 16.0);
    vec3 p = ro + rd * ti;
    float fog = exp(-ti * .07);
    // beacon: a thin sweeping shaft, not ambient wash
    float bl = spotLight(p, bpos, bdir, .55, .94) * (.55 + .45 * abs(sin(bang * 2.)));
    acc += vec3(1., .05, .04) * bl * fog * .016;
    // flashlight shaft under the gun
    float fl = spotLight(p, gGunPos, gFwd, .90, .985);
    acc += vec3(.8, .9, 1.0) * fl * fog * .020;
    // flare: tight, only glows near its own position (landing point / arc)
    if (fg > .001 || (fp > .001 && fp < 1.)){
      float d5 = length(flarePos - p);
      float k = fp > .001 && fp < 1. ? 1.0 : fg;
      acc += vec3(1., .10, .28) * k * fog * .09 / (1. + d5 * d5 * .35);
    }
  }
  return acc * (min(tmax,16.0) / steps);
}

// --------------------------------------------------------------- camera ----
vec3 render(vec2 fc){
  float t = iTime;
  // handheld sway
  vec3 swayPos = vec3(fbm3lo(vec3(t * .5, 0., 0.)) - .5, fbm3lo(vec3(0., t * .6, 3.)) - .5, 0.) * .05;
  float bob = sin(t * 1.8) * .012;
  vec3 ro = vec3(.06, 1.56 + bob, -.35) + swayPos;
  float recoil = uP[0], pb = uP[3];
  vec3 ta = ro + vec3(.02 * sin(t * .37), -.02 + recoil * .55 + pb * .25, 6.0);
  float roll = .01 * sin(t * .8) + recoil * .02;
  vec3 rd = camRay(fc, ro, ta, 1.65, roll);

  vec3 f = normalize(ta - ro);
  vec3 r = normalize(cross(f, vec3(sin(roll), cos(roll), 0.)));
  vec3 u = cross(r, f);
  gRight = r; gUp = u; gFwd = f;
  gGunPos = ro + r * .30 - u * .24 + f * (.55 - recoil * .09);

  float d = 0.; vec2 h = vec2(0.);
  for (int i = 0; i < 130; i++){
    vec3 p = ro + rd * d;
    h = map(p);
    if (h.x < .0009 || d > 24.) break;
    d += h.x * .82;
  }
  vec3 col;
  if (d > 24.){
    col = vec3(0.02, 0.015, 0.02) * (1.0 + uP[8]*4.0);
  } else {
    vec3 p = ro + rd * d, n = nrm(p);
    float seed = 0.;
    // recover which fight monster we hit (for cloth tint) by nearest match; cheap approx via re-deriving seed from material continuity is skipped, use generic
    col = shade(p, n, rd, h.y, hash21(floor(p.xz*4.)));
  }
  col += volumetric(ro, rd, d > 24. ? 16.0 : d);
  return col;
}
