// s05_corridor — the signature scare. Long straight corridor, slow handheld push. Flickering
// fluorescents (scripted in shot.js -> uP[0]). Monster stands far down the corridor, teleporting
// closer every blackout. uP: [0]=lightIntensity [1]=monsterZ [2]=closeUpFactor [3]=camZ [4]=camBobSeed

#define HW    1.55
#define ROOMH 2.85

float corridorZ = 60.0; // corridor extends this far for the vanishing point

vec2 map(vec3 p){
  vec2 r = vec2(p.y, M_CONCRETE);                                  // floor
  r = opU(r, vec2(ROOMH - p.y, M_STEEL));                           // ceiling
  r = opU(r, vec2(HW - abs(p.x), M_STEEL));                         // walls

  // ceiling cable tray (one side) + pipe (other side), running the length
  r = opU(r, vec2(sdBox(p - vec3(-1.2, ROOMH-.16, 0.), vec3(.14,.05,corridorZ)), M_GUNMETAL));
  r = opU(r, vec2(sdCylZ(p - vec3(1.25, ROOMH-.2, 0.), .045, corridorZ), M_GUNMETAL));

  // fluorescent fixtures every 3m, recessed boxes in the ceiling
  float fz = mod(p.z + 1.5, 3.0) - 1.5;
  vec3 fp = vec3(p.x, p.y, fz);
  r = opU(r, vec2(sdBox(fp - vec3(0., ROOMH-.05, 0.), vec3(.45,.04,.5)), 22.0));

  // toppled chair near z=3 (cheap bounding gate first — skip the detail SDF far from it)
  if (abs(p.z - 3.1) < 1.0 && abs(p.x + .85) < 1.0 && p.y < 1.0){
    vec3 cp = p - vec3(-.85, 0., 3.1);
    cp.xz = rot2(1.1) * cp.xz;
    float seat = sdBox(cp - vec3(0.,.22,0.), vec3(.22,.03,.22));
    float back = sdBox(cp - vec3(0.,.22,-.2), vec3(.22,.22,.03));
    float legs = 1e5;
    for (int i=0;i<4;i++){
      float sx = i<2?-.19:.19, sz = mod(float(i),2.)<.5?-.19:.19;
      legs = min(legs, sdCylY(cp - vec3(sx,.11,sz), .012, .12));
    }
    r = opU(r, vec2(min(min(seat,back),legs), M_GUNMETAL));
  }

  // scattered papers on the floor near z=5 (same gate trick)
  for (int i=0;i<2;i++){
    float fi = float(i);
    vec3 pp = p - vec3(hash11(fi*3.1)*1.6-.8, .004, 5.0 + hash11(fi*7.7)*1.5);
    pp.xz = rot2(hash11(fi*1.9)*6.28) * pp.xz;
    r = opU(r, vec2(sdBox(pp, vec3(.13,.002,.17)), 23.0));
  }

  // poster on the wall near z=8
  r = opU(r, vec2(sdBox(p - vec3(HW-.02, 1.55, 8.0), vec3(.02,.42,.32)), 24.0));

  // doorway with blood dragged into it, z=~11
  {
    vec3 dp = p - vec3(HW, 1.1, 11.0);
    float frame = sdBox(dp, vec3(.15, 1.1, .55));
    float hole = sdBox(dp - vec3(-.1,-.05,0.), vec3(.2, .95, .48));
    r = opU(r, vec2(smax(frame,-hole,.02), M_STEEL));
  }

  // monster (bounded). During the final face-reveal its animation time is held steady so the
  // scare pose doesn't jerk out of frame between the handful of frames the flicker allows.
  {
    float mz = uP[1];
    vec3 mp = p - vec3(0., 0., mz);
    mp.xz = rot2(PI) * mp.xz; // faces back up the corridor toward camera (+Z local == -Z world)
    float scale = 1.0;
    vec3 msc = mp / scale;
    float monT = uP[2] > 0.001 ? 12.16 : iTime;
    float bound = sdCapsule(msc, vec3(0.,.2,0.), vec3(0.,2.05,0.), .7);
    if (bound < .15){
      vec2 mm = sdMonster(msc, monT, .42, 0.0);
      mm.x *= scale;
      r = opU(r, mm);
    } else {
      r = opU(r, vec2(bound*scale + .05, 0.));
    }
  }

  return r;
}

vec3 nrm(vec3 p){                     // tetrahedron trick: 4 taps instead of 6
  const vec2 e = vec2(1.,-1.) * .0015;
  return normalize(e.xyy*map(p+e.xyy).x + e.yyx*map(p+e.yyx).x + e.yxy*map(p+e.yxy).x + e.xxx*map(p+e.xxx).x);
}

vec3 matAlbedo(float m, vec3 p, vec3 n){
  if (m == M_STEEL){
    float split = 1.3;
    float edge = smoothstep(split-.08, split+.08, p.y);
    vec3 lower = vec3(.16,.23,.20), upper = vec3(.5,.47,.4);
    vec3 base = mix(lower, upper, edge);
    float grime = fbm3lo(p*1.3);
    base *= mix(1., .5, smoothstep(.5,.85,grime));
    float stain = smoothstep(.6,.9, fbm3lo(p*.7 + vec3(0.,p.y*.2,0.)));
    base *= mix(1., .65, stain * smoothstep(2.6, .3, p.y));  // water stains running down
    // frost crust: heaviest low on the wall, fading out above the paint line
    float frostN = fbm3lo(p*6.5+21.);
    float frost = smoothstep(.4,.85, frostN) * smoothstep(1.9, .0, p.y);
    base = mix(base, vec3(.78,.86,.93), frost*.6);
    return base;
  }
  if (m == M_GUNMETAL) return vec3(.03,.033,.036)*(.7+.5*noise3(p*160.));
  if (m == 22.0) return vec3(.9,.92,.95);                 // fluorescent tube lens (emissive-ish, lit separately)
  if (m == 23.0) return vec3(.72,.7,.6)*(.7+.4*noise3(p*40.));  // papers
  if (m == 24.0){                                        // poster: stencilled Cyrillic safety notice
    vec2 uv = vec2(1. - ((p.z-8.0)/.32*.5+.5), (p.y-1.55)/.42*.5+.5);
    vec3 tex = texture(iTex0, clamp(uv,0.,1.)).rgb;
    return tex * (.75+.4*noise3(p*20.));
  }
  // floor: concrete with frost + blood drag mark leading into the doorway at z~11
  vec3 conc = vec3(.12,.12,.115) * (.55+.5*fbm3lo(p*2.));
  float frostc = smoothstep(.5,.92, fbm3lo(p*7.+3.));
  conc = mix(conc, vec3(.78,.85,.92), frostc*.4);
  // bloodSplat() is a 10-iteration loop — check the cheap band mask first, only pay for it near the doorway
  float dragBand = smoothstep(.9,.3, abs(p.x-1.0)) * smoothstep(9.5,10.6,p.z) * smoothstep(12.2,11.2,p.z);
  float drag = 0.0;
  if (dragBand > .01){
    vec2 dragUV = vec2(p.x*1.4 - 1.6, p.z*.55 - 5.7);
    drag = bloodSplat(dragUV, 8.3);
  }
  conc = mix(conc, vec3(.09,.012,.016), clamp(drag*1.3,0.,1.)*dragBand);
  return conc;
}

vec3 render(vec2 fc){
  float t = iTime;
  float camZ = uP[3];
  float bobX = (noise2(vec2(t*.9, 5.1)) - .5) * .05;
  float bobY = sin(t*1.9) * .012 + (noise2(vec2(t*1.3, 8.7))-.5)*.02;
  vec3 ro = vec3(bobX, 1.5 + bobY, camZ);
  vec3 ta = vec3(bobX*.6, 1.46 + bobY*.6, camZ + 8.0);
  vec3 rd = camRay(fc, ro, ta, 1.9, bobX*.02);

  float d = 0.; vec2 h; vec3 p;
  for (int i = 0; i < 48; i++){
    p = ro + rd*d; h = map(p);
    if (h.x < .0032 || d > 70.) break;
    d += h.x * 1.12;
  }
  bool hit = d <= 70.;
  vec3 col = vec3(0.);
  if (!hit) return vec3(0.002,0.002,0.003);

  vec3 n = nrm(p);
  bool isMon = h.y >= .5 && h.y <= 4.5;
  vec3 alb = isMon ? monsterAlbedo(h.y, p) : matAlbedo(h.y, p, n);

  float lightI = uP[0];
  float closeUp = uP[2];
  bool finalPhase = closeUp > .001;

  col += alb * .0025; // near-black ambient floor — most of the frame should read dark

  float monK = isMon ? 0.32 : 1.0; // the monster reads mostly by rim/silhouette, not direct key light

  // cheap AO for the final face-reveal only (a handful of extra map() samples along the normal,
  // negligible cost over the whole shot since it's gated to ~7 frames) — carves real shadow into
  // the eye sockets / mouth instead of a flat wash.
  float ao = 1.0;
  if (finalPhase){
    float occ = 0.0, wgt = 1.0, step_ = .045;
    for (int i = 1; i <= 4; i++){
      float sd = float(i) * step_;
      float sc = map(p + n * sd).x;
      occ += wgt * max(0.0, sd - sc);
      wgt *= 0.6;
    }
    ao = clamp(1.0 - occ * 4.6, 0.05, 1.0);
  }

  // the character's own flashlight, mounted at the camera, slight independent handheld sway
  vec3 flDir = normalize(rd + vec3(sin(t*2.3)*.02, cos(t*1.9)*.015, 0.));
  vec3 flPos = ro + vec3(.10,-.06,.05);
  {
    vec3 L = p - flPos; float dist = max(length(L), .5);
    float cone = spotLight(p, flPos, flDir, .82, .965) * flashCookie(p, flPos, flDir);
    float ndotl = max(dot(n, -L/dist), 0.);
    float flPow = finalPhase ? (isMon ? 0.85 : 0.02) : 0.5;
    col += alb * ndotl * cone * flPow * monK * ao * vec3(1.0,.97,.92) * 3.0;
  }

  // fluorescent fixtures: most are dead. only a sparse deterministic subset ever lights up,
  // and it pools tightly (steep falloff) rather than flooding the whole corridor.
  if (!finalPhase){
    for (int k = 0; k < 4; k++){
      float fkz = float(k) * 3.0 - 1.5;
      float alive = step(0.62, hash11(float(k)*7.13 + 4.0));
      if (alive < .5) continue;
      vec3 lp = vec3(0., ROOMH-.1, fkz);
      vec3 L = lp - p; float dist = max(length(L), .7);
      if (dist > 5.5) continue;
      float atten = lightI / (1. + dist*dist*2.6);
      float ndotl = max(dot(n, L/dist), 0.);
      col += alb * ndotl * atten * monK * vec3(.8,.9,1.0) * 1.7;
      // fake haze glow around the pool, cheap (no extra march)
      col += vec3(.5,.6,.75) * atten * atten * .18;
    }
  }

  // harsh flashlight-driven under/front light for the final face-reveal (camera is right on it)
  if (finalPhase){
    vec3 lp = ro + vec3(.05,-.55,.15);
    vec3 L = lp - p; float dist = max(length(L), .5);
    float atten = closeUp / (1. + dist*dist*3.4) * (isMon ? 1.0 : 0.08);
    col += alb * max(dot(n, L/dist),0.) * atten * ao * vec3(1.2,1.0,.8) * 11.0;
  }

  // monster: keep it mostly in shadow — a rim from whatever light is behind it, face reads dark
  // unless the flashlight is square on it (close phases / final)
  if (isMon){
    float rim = pow(1.0 - max(dot(n, -rd), 0.), 2.5);
    col += vec3(.3,.35,.45) * rim * (lightI*.3 + .03);
  }

  // cold volumetric haze: thicker with distance, and glowing where the flashlight cone crosses it.
  // during the final reveal the background must read as flat black, not fog.
  float hazeRate = finalPhase ? 0.55 : 0.05;
  float hazeAmt = 1.0 - exp(-d * hazeRate);
  vec3 hazeCol = vec3(0.);
  if (!finalPhase){
    hazeCol = vec3(.006,.007,.009);
    vec3 L = p - flPos; float dist = max(length(L), .4);
    float cone = spotLight(p, flPos, flDir, .8, .96);
    hazeCol += vec3(.35,.38,.42) * cone * .05 * min(d, 8.0);
  }
  col = mix(col, hazeCol, clamp(hazeAmt, 0., finalPhase ? 1.0 : 0.9));
  if (finalPhase && !isMon) col = min(col, vec3(0.02)); // background stays flat black behind the reveal

  return col;
}
