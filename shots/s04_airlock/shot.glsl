// s04_airlock — inside the base looking back at the blast door. Door slams, power dies,
// red emergency beacon kicks in. uP: [0]=doorAngle [1]=lockBar 0..1 [2]=powerOn 0..1
// [3]=beaconOn 0..1 [4]=dustOpacity 0..1

#define ROOMH 3.05
#define HW    2.15
#define ZDOOR 5.6
#define HOLEHW 1.05
#define HOLEHH 1.35
#define HOLECY 1.35

float doorAngle(){ return uP[0]; }

// ---- door slab in its own local frame, hinge at local origin, extends +x ----
vec2 sdDoorLocal(vec3 q){
  float t = .085;
  vec2 r = vec2(1e5, M_STEEL);
  float slab = sdRoundBox(q - vec3(HOLEHW+.06, 0., 0.), vec3(HOLEHW+.09, HOLEHH+.08, t), .05);
  r = opU(r, vec2(slab, M_STEEL));
  // ribs
  float rib = abs(mod(q.y + .15, .42) - .21) - .02;
  rib = max(rib, abs(q.x - (HOLEHW+.06)) - HOLEHW);
  rib = max(rib, abs(q.z) - t - .012);
  r = opU(r, vec2(rib, M_STEEL));
  // wheel (spokes faked cheaply via angular modulo instead of a primitive loop)
  vec3 wc = q - vec3(HOLEHW+.06, 0., t + .05);
  float wa = atan(wc.y, wc.x);
  float spokeMod = abs(mod(wa, PI/2.5) - PI/5.) * length(wc.xy);
  float wheel = min(sdTorus(wc, vec2(.26, .028)), max(spokeMod - .018, abs(wc.z) - .018) );
  wheel = min(wheel, sdCylZ(wc, .05, .05));
  r = opU(r, vec2(wheel, M_GUNMETAL));
  // hinges at x=0 side
  for (int i = 0; i < 2; i++){
    float hy = i == 0 ? -.9 : .9;
    r = opU(r, vec2(sdCylZ(q - vec3(-.03, hy, 0.), .055, .11), M_GUNMETAL));
  }
  return r;
}

vec2 sdDoor(vec3 p){
  vec3 hinge = vec3(-HOLEHW - .06, HOLECY, ZDOOR - .16);
  vec3 q = p - hinge;
  q.xz = rot2(-doorAngle()) * q.xz;
  return sdDoorLocal(q);
}

// locking bars: static in world, slide out of the frame (opposite hinge side) into the door
vec2 sdBars(vec3 p){
  vec2 r = vec2(1e5, M_GUNMETAL);
  float ext = clamp(uP[1], 0., 1.);
  for (int i = 0; i < 3; i++){
    float fy = HOLECY + (float(i) - 1.) * .55;
    float len = .22 * smoothstep(0., 1., ext) * (i == 0 ? min(1., ext*2.3) : (i==1? clamp(ext*2.3-.35,0.,1.) : clamp(ext*2.3-.7,0.,1.)));
    vec3 c = vec3(HOLEHW + .06 - len, fy, ZDOOR - .16);
    r = opU(r, vec2(sdCapsule(p, c, c + vec3(len*2.,0.,0.), .035), M_GUNMETAL));
  }
  return r;
}

vec2 map(vec3 p){
  vec2 r = vec2(p.y, M_CONCRETE);                       // floor / snow beyond the door
  if (p.z < ZDOOR + .05){                                // ceiling & walls only inside the room
    r = opU(r, vec2(ROOMH - p.y, M_STEEL));
    r = opU(r, vec2(HW - abs(p.x), M_STEEL));
  }
  // back wall with a doorway hole cut through it
  {
    vec3 q = p - vec3(0., ROOMH*.5, ZDOOR);
    float wall = sdBox(q, vec3(HW, ROOMH*.5+.15, .16));
    float hole = sdBox(q - vec3(0., HOLECY - ROOMH*.5, 0.), vec3(HOLEHW, HOLEHH, .3));
    wall = smax(wall, -hole, .01);
    r = opU(r, vec2(wall, M_STEEL));
  }
  // ceiling pipes / cable trays
  r = opU(r, vec2(sdCylZ(p - vec3(-1.75, ROOMH-.18, 0.), .06, 8.), M_GUNMETAL));
  r = opU(r, vec2(sdCylZ(p - vec3(-1.55, ROOMH-.22, 0.), .045, 8.), M_GUNMETAL));
  r = opU(r, vec2(sdBox(p - vec3(1.7, ROOMH-.22, 0.), vec3(.16, .06, 8.)), M_GUNMETAL));
  r = opU(r, sdDoor(p));
  if (p.z < ZDOOR + .05) r = opU(r, sdBars(p));
  // sign plate above the door
  {
    vec3 sp = p - vec3(0., ROOMH - .55, ZDOOR - .155);
    float plate = sdBox(sp, vec3(.85, .28, .03));
    r = opU(r, vec2(plate, 20.0));
  }
  // researcher silhouettes near camera, off to the sides (single cheap capsule each)
  for (int i = 0; i < 2; i++){
    float sg = i == 0 ? -1. : 1.;
    vec3 rp = p - vec3(sg*1.55, 0., -.9 + .2*sg);
    r = opU(r, vec2(sdCapsule(rp, vec3(0.,.15,0.), vec3(0.,1.85,0.), .27), 21.0));
  }
  return r;
}

vec3 nrm(vec3 p){                     // tetrahedron trick: 4 taps instead of 6
  const vec2 e = vec2(1.,-1.) * .0015;
  return normalize(e.xyy*map(p+e.xyy).x + e.yyx*map(p+e.yyx).x + e.yxy*map(p+e.yxy).x + e.xxx*map(p+e.xxx).x);
}

vec3 matAlbedo(float m, vec3 p, vec3 n){
  if (m == M_STEEL){
    float split = 1.35;
    float edge = smoothstep(split-.08, split+.08, p.y);
    vec3 lower = vec3(.20,.28,.24), upper = vec3(.58,.55,.45);
    vec3 base = mix(lower, upper, edge);
    float grime = fbm3lo(p*1.4);
    base *= mix(1., .55, smoothstep(.5,.85,grime));
    float rivetGrid = max(abs(mod(p.y+.1,.85)-.425), abs(mod(p.x+p.z*0.001+.1,.85)-.425));
    base *= mix(1., .8, smoothstep(.02,.0,rivetGrid-.4));
    float frost = smoothstep(.5,.92, fbm3lo(p*7.+11.));
    base = mix(base, vec3(.86,.92,.97), frost*.55);
    return base;
  }
  if (m == M_GUNMETAL) return vec3(.05,.055,.06)*(.75+.5*noise3(p*180.));
  if (m == 20.0){                                        // sign plate: stencil texture
    vec2 uv = vec2(1. - ((p.x/.85)*.5+.5), (p.y-(ROOMH-.55))/.28*.5+.5);
    vec3 tex = texture(iTex0, clamp(uv,0.,1.)).rgb;
    return tex * .9 + .02;
  }
  if (m == 21.0) return vec3(.015,.014,.016);            // silhouette
  // floor: concrete inside, packed snow beyond the doorway
  float outside = smoothstep(ZDOOR-.1, ZDOOR+.3, p.z);
  vec3 conc = vec3(.13,.13,.125) * (.6+.5*fbm3lo(p*2.1));
  float frostc = smoothstep(.45,.9, fbm3lo(p*8.+3.));
  conc = mix(conc, vec3(.8,.87,.93), frostc*.5);
  // bloodSplat() is a 10-iteration loop — gate it to near the patch instead of paying for it
  // on every floor pixel in the frame.
  vec2 bloodCenter = vec2(-.35, 3.1);
  float bloodGate = smoothstep(1.8, 0., length(p.xz - bloodCenter)) * (1.-outside);
  if (bloodGate > .01){
    float blood = bloodSplat((p.xz - bloodCenter) * 1.1, 4.7) * bloodGate;
    conc = mix(conc, vec3(.10,.015,.02), blood*.75);
  }
  vec3 snow = vec3(.75,.8,.88) * (.7+.5*fbm3lo(p*3.));
  return mix(conc, snow, outside);
}

vec3 background(vec3 rd, float t){
  vec3 col = vec3(.01,.015,.03) + vec3(.02,.03,.06)*max(0.,rd.y);
  col += aurora(rd, t) * .5;
  col += vec3(.5,.6,.8) * stars(rd) * .6;
  float snowStreak = smoothstep(.9985,1.,fract(sin(dot(floor(rd.xy*260.+t*4.),vec2(41.,7.)))*4173.));
  col += snowStreak * .5;
  return col;
}

vec3 render(vec2 fc){
  vec2 uv = screenUV(fc);
  float sway = noise2(vec2(iTime*.6,3.1)) - .5;
  vec3 ro = vec3(sway*.02, 1.55 + .01*sin(iTime*1.7), -1.2);
  vec3 ta = vec3(sway*.05, 1.42, ZDOOR);
  vec3 rd = camRay(fc, ro, ta, 1.65, sway*.01);

  float d = 0.; vec2 h; vec3 p;
  for (int i = 0; i < 40; i++){
    p = ro + rd*d; h = map(p);
    if (h.x < .003 || d > 45.) break;
    d += h.x * 1.08;
  }

  float power = uP[2], beacon = uP[3];
  vec3 col;
  bool hit = d <= 45.;
  vec3 n = hit ? nrm(p) : vec3(0.);
  vec3 alb = hit ? matAlbedo(h.y, p, n) : vec3(0.);

  // --- flashlights (2 researchers sweeping) ---
  vec3 flPos[2]; flPos[0] = vec3(-1.4,1.75,-1.0); flPos[1] = vec3(1.35,1.65,-1.15);
  float flPh[2]; flPh[0] = 0.; flPh[1] = 2.4;
  vec3 flCol = vec3(.9,.95,1.1);

  col = vec3(0.);
  if (hit){
    float amb = .02 + power*.018;
    col += alb * amb;
    // soft overhead fill (dies with power) — point falloff, not a tight hotspot
    vec3 workL = vec3(0., 2.85, -.3);
    vec3 wl3 = workL - p; float wd = length(wl3);
    float wl = power / (1. + wd*wd*.35);
    col += alb * max(dot(n, wl3/wd),0.) * wl * vec3(1.,.97,.85) * 1.1;

    for (int i = 0; i < 2; i++){
      float sweep = sin(iTime*.55 + flPh[i]) * .5;
      vec3 dir = normalize(vec3(sweep*.8 + (i==0?.35:-.3), -.25 - .1*sin(iTime*.31+flPh[i]), 1.));
      vec3 L = p - flPos[i];
      float dist = length(L);
      float cone = spotLight(p, flPos[i], dir, .78, .96) * flashCookie(p, flPos[i], dir);
      col += alb * max(dot(n, -L/dist),0.) * cone * flCol * 3.4;
    }

    // red rotating beacon
    float bAng = iTime * 2.6;
    vec3 bDir = vec3(sin(bAng), -.1, cos(bAng));
    vec3 bPos = vec3(0., ROOMH-.2, .5);
    float bcone = spotLight(p, bPos, bDir, .55, .9) * beacon;
    float pulse = .55 + .45*sin(iTime*9.0);
    col += alb * max(dot(n, normalize(bPos-p)),0.) * bcone * pulse * vec3(2.0,.07,.04) * 1.1;
    col += alb * beacon * vec3(.035,0.,0.);                // faint red fill

    // cold blue spill from outside if door open
    float doorOpen = clamp(doorAngle()/1.3, 0., 1.);
    float ext = smoothstep(ZDOOR-3., ZDOOR+.5, p.z) * doorOpen;
    col += alb * ext * vec3(.04,.06,.11);
  } else {
    col = background(rd, iTime);
  }

  // --- cheap volumetric fog / light shafts along the primary ray (few steps, one dominant light) ---
  vec3 fog = vec3(0.);
  float marchMax = min(d, 8.0);
  const int STEPS = 2;
  float stepLen = marchMax / float(STEPS);
  float dith = hash21(fc + iTime*90.);
  float bAng = iTime * 2.6;
  vec3 bDir = vec3(sin(bAng), -.1, cos(bAng));
  vec3 bPos = vec3(0., ROOMH-.2, .5);
  for (int i = 0; i < STEPS; i++){
    float s = (float(i) + dith) * stepLen;
    if (s > marchMax) break;
    vec3 fp = ro + rd*s;
    float density = .06 + .1*smoothstep(ZDOOR-2.5, ZDOOR+1., fp.z)*clamp(doorAngle()/1.3,0.,1.);
    density *= .5 + .5*fbm3lo(fp*.8 + vec3(0.,-iTime*.3,0.));
    // one representative flashlight beam (close enough visually, half the cost)
    vec3 L = fp - flPos[0];
    float dist = length(L);
    float sweep = sin(iTime*.55) * .5;
    vec3 dir = normalize(vec3(sweep*.8 + .35, -.25 - .1*sin(iTime*.31), 1.));
    float cone = spotLight(fp, flPos[0], dir, .8, .97);
    float ph = hgPhase(dot(rd, normalize(-L)), .5);
    fog += flCol * cone * ph * density * stepLen * 2.4;
    if (beacon > .01){
      float bcone = spotLight(fp, bPos, bDir, .5, .92) * beacon;
      fog += vec3(1.1,.04,.02) * bcone * density * stepLen * 1.1;
    }
  }
  col += fog;

  // dust puff at the slam (subtle, localized near the door, not a full-screen haze)
  float dust = uP[4];
  if (dust > .001 && hit){
    float dn = fbm3lo(vec3(p.xy*2., iTime*.6));
    float nearDoor = smoothstep(3.5, 0.5, abs(d - ZDOOR + 1.2));
    col += vec3(.35,.33,.3) * dust * dn * nearDoor * .18;
  }

  return col;
}
