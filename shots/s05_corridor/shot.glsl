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

  // toppled chair near z=3
  {
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

  // scattered papers on the floor near z=5
  for (int i=0;i<4;i++){
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

  // monster (bounded)
  {
    float mz = uP[1];
    vec3 mp = p - vec3(0., 0., mz);
    mp.xz = rot2(PI) * mp.xz; // faces back up the corridor toward camera (+Z local == -Z world)
    float scale = 1.0;
    vec3 msc = mp / scale;
    float bound = sdCapsule(msc, vec3(0.,.2,0.), vec3(0.,2.05,0.), 1.05);
    if (bound < .15){
      vec2 mm = sdMonster(msc, iTime, .42, 0.0);
      mm.x *= scale;
      r = opU(r, mm);
    } else {
      r = opU(r, vec2(bound*scale + .05, 0.));
    }
  }

  return r;
}

vec3 nrm(vec3 p){ vec2 e=vec2(.0015,0.); return normalize(vec3(
  map(p+e.xyy).x-map(p-e.xyy).x, map(p+e.yxy).x-map(p-e.yxy).x, map(p+e.yyx).x-map(p-e.yyx).x)); }

float shadow(vec3 ro, vec3 rd, float maxd){
  float res = 1., t = .04;
  for (int i = 0; i < 22; i++){
    float h = map(ro + rd*t).x;
    res = min(res, 9.*h/t);
    t += clamp(h, .03, .4);
    if (h < .001 || t > maxd) break;
  }
  return clamp(res, 0., 1.);
}

vec3 matAlbedo(float m, vec3 p, vec3 n){
  if (m == M_STEEL){
    float split = 1.3;
    float edge = smoothstep(split-.08, split+.08, p.y);
    vec3 lower = vec3(.19,.27,.23), upper = vec3(.56,.53,.44);
    vec3 base = mix(lower, upper, edge);
    float grime = fbm3lo(p*1.3);
    base *= mix(1., .55, smoothstep(.5,.85,grime));
    float frost = smoothstep(.55,.93, fbm3lo(p*6.5+21.));
    base = mix(base, vec3(.82,.89,.95), frost*.45);
    // blood drag streak along the floor-adjacent wall base near the doorway
    return base;
  }
  if (m == M_GUNMETAL) return vec3(.045,.05,.055)*(.7+.5*noise3(p*160.));
  if (m == 22.0) return vec3(.9,.92,.95);                 // fluorescent tube lens (emissive-ish, lit separately)
  if (m == 23.0) return vec3(.72,.7,.6)*(.7+.4*noise3(p*40.));  // papers
  if (m == 24.0) return vec3(.5,.12,.1)*(.6+.5*noise3(p*20.));  // poster (faded red Soviet poster)
  // floor: concrete with frost + blood drag mark leading into the doorway at z~11
  vec3 conc = vec3(.12,.12,.115) * (.55+.5*fbm3lo(p*2.));
  float frostc = smoothstep(.5,.92, fbm3lo(p*7.+3.));
  conc = mix(conc, vec3(.78,.85,.92), frostc*.4);
  vec2 dragUV = vec2(p.x*1.4 - 1.6, p.z*.55 - 5.7);
  float drag = bloodSplat(dragUV, 8.3);
  float dragBand = smoothstep(.9,.3, abs(p.x-1.0)) * smoothstep(9.5,10.6,p.z) * smoothstep(12.2,11.2,p.z);
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
  for (int i = 0; i < 140; i++){
    p = ro + rd*d; h = map(p);
    if (h.x < .0008 || d > 70.) break;
    d += h.x * .85;
  }
  bool hit = d <= 70.;
  vec3 col = vec3(0.);
  if (!hit) return vec3(0.002,0.002,0.003);

  vec3 n = nrm(p);
  vec3 alb = (h.y > .5 && h.y < 4.5) ? monsterAlbedo(h.y, p) : matAlbedo(h.y, p, n);

  float lightI = uP[0];
  float closeUp = uP[2];

  // fluorescent fixtures light the corridor from above, each modulated by the scripted flicker
  float fillAmb = .006 + lightI*.01;
  col += alb * fillAmb;
  for (int k = 0; k < 6; k++){
    float fkz = float(k) * 3.0 - 1.5;
    vec3 lp = vec3(0., ROOMH-.1, fkz);
    vec3 L = lp - p; float dist = length(L);
    if (dist > 11.0) continue;
    float atten = lightI / (1. + dist*dist*.55);
    float ndotl = max(dot(n, L/dist), 0.);
    col += alb * ndotl * atten * vec3(.85,.92,1.0) * 5.5;
  }

  // harsh under/front light for the final face-reveal
  if (closeUp > .001){
    vec3 lp = ro + vec3(0., -.3, .6);
    vec3 L = lp - p; float dist = max(length(L), .05);
    float atten = closeUp / (1. + dist*dist*.8);
    col += alb * max(dot(n, L/dist),0.) * atten * vec3(1.2,1.0,.85) * 9.0;
  }

  // monster gets a rim of whatever ambient light is present so it reads as a silhouette
  if (h.y >= .5 && h.y <= 4.5){
    float rim = pow(1.0 - max(dot(n, -rd), 0.), 3.0);
    col += vec3(.5,.55,.65) * rim * (lightI*.5 + closeUp*.4 + .05);
  }

  // thin ice-fog for depth cueing
  float fog = 1.0 - exp(-d * 0.028);
  vec3 fogCol = vec3(.02,.025,.03) + vec3(.01,.012,.02)*lightI;
  col = mix(col, fogCol, clamp(fog,0.,0.85));

  return col;
}
