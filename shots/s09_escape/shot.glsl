// s09_escape — the hangar and the way out. 0-11s interior (Kharkovchanka rams the doors),
// 11-18s exterior (it bursts onto the snow as the base explodes behind it).
#define H_FLOOR   20.0
#define H_CEIL    21.0
#define H_WALL    22.0
#define H_TRUSS   23.0
#define H_DOOR    24.0
#define H_DRUMR   25.0
#define H_DRUMO   26.0
#define H_CRATE   27.0
#define H_POLE    28.0
#define H_LAMP    29.0
#define H_TRACK   30.0
#define H_CAB     31.0
#define H_ROOF    32.0
#define H_HEAD    33.0
#define H_TAIL    34.0
#define H_SNOW    35.0
#define H_FIG     36.0
#define H_LETTER  37.0
#define H_DEBRIS  38.0

const float DOOR_Z = 24.0;
const float ROOM_W = 5.2, ROOM_CEIL = 7.2;
const float EXT_T = 11.0;

// ---------------- timeline ----------------
float vehZ(float t){
  if (t < 5.0) return 11.5 + sin(t*2.3)*0.02;
  if (t < 9.3) { float k = smoothstep(5.0, 9.3, t); return mix(11.5, DOOR_Z + 0.3, k*k); }
  if (t < 11.0){ float k = smoothstep(9.3, 11.0, t); return mix(DOOR_Z + 0.3, DOOR_Z + 5.0, k); }
  float k = smoothstep(11.0, 18.0, t);
  return DOOR_Z + 5.0 + k*k*46.0;
}
float doorOpen(float t){ return clamp((t - 9.15) / 0.85, 0.0, 1.0); } // 0 shut .. 1 fully open/gone

// ---------------- vehicle (Kharkovchanka), local frame: origin at ground, facing +Z ----------------
vec2 sdVehicle(vec3 p, float t){
  vec2 r = vec2(1e5, 0.0);
  r = opU(r, vec2(sdRoundBox(p - vec3(0.,0.5,0.), vec3(1.28,0.5,2.75), 0.06), H_TRACK));
  // road wheels bumps (cheap: sine-modulated bottom edge, skip separate geo)
  r = opU(r, vec2(sdRoundBox(p - vec3(0.,1.55,-0.1), vec3(1.05,1.05,2.35), 0.10), H_CAB));
  r = opU(r, vec2(sdRoundBox(p - vec3(0.,2.72,-0.15), vec3(1.0,0.16,2.25), 0.05), H_ROOF));
  // cab windows band (dark)
  r = opU(r, vec2(sdRoundBox(p - vec3(0.,2.05,1.85), vec3(1.02,0.28,0.35), 0.03), H_WALL));
  // headlights
  r = opU(r, vec2(sdSphere(p - vec3(-0.55,1.35,2.72), 0.12), H_HEAD));
  r = opU(r, vec2(sdSphere(p - vec3( 0.55,1.35,2.72), 0.12), H_HEAD));
  // taillights
  r = opU(r, vec2(sdSphere(p - vec3(-0.75,1.15,-2.72), 0.075), H_TAIL));
  r = opU(r, vec2(sdSphere(p - vec3( 0.75,1.15,-2.72), 0.075), H_TAIL));
  // exhaust stack
  r = opU(r, vec2(sdCylY(p - vec3(0.95,2.35,-2.0), 0.05, 0.5), H_TRACK));
  // rear platform + silhouette figure throwing a grenade
  vec3 fp = p - vec3(-0.35, 2.95, -2.55);
  float armT = clamp((t - 6.6)/1.0, 0.0, 1.0);
  float wind = smoothstep(0.0,0.4,armT) * (1.0-smoothstep(0.6,1.0,armT));
  float body = sdCapsule(fp, vec3(0.,0.,0.), vec3(0.,0.62,0.), 0.13);
  float head = sdSphere(fp - vec3(0.,0.78,0.02), 0.10);
  vec3 armDir = normalize(vec3(0.15, mix(0.1,0.9,wind), mix(0.3,-0.5,wind)));
  float arm = sdCapsule(fp, vec3(0.,0.55,0.02), vec3(0.,0.55,0.02) + armDir*0.55, 0.05);
  float fig = min(body, min(head, arm));
  r = opU(r, vec2(fig, H_FIG));
  return r;
}

// ---------------- interior map ----------------
vec2 mapInterior(vec3 p, float t){
  vec2 r = vec2(1e5, 0.0);
  r = opU(r, vec2(p.y, H_FLOOR));
  r = opU(r, vec2(ROOM_CEIL - p.y, H_CEIL));
  r = opU(r, vec2(p.x + ROOM_W, H_WALL));
  r = opU(r, vec2(ROOM_W - p.x, H_WALL));
  r = opU(r, vec2(p.z - (-2.0), H_WALL));

  // roof trusses: arched ribs every 4m
  for (int i = 0; i < 6; i++){
    float tz = 0.0 + float(i) * 4.2;
    vec3 q = p - vec3(0., 0., tz);
    float arch = length(vec2(abs(q.x), max(q.y - 5.4, 0.))) - 5.4;
    float rib = abs(arch) - 0.08;
    rib = max(rib, q.y - 7.1);
    rib = max(rib, abs(q.z) - 0.09);
    r = opU(r, vec2(rib, H_TRUSS));
  }

  // sodium work-light stands along both walls
  for (int i = 0; i < 4; i++){
    float lz = 2.0 + float(i) * 6.0;
    for (int s = 0; s < 2; s++){
      float sg = s == 0 ? -1. : 1.;
      vec3 lc = vec3(sg * (ROOM_W - 0.6), 0., lz);
      r = opU(r, vec2(sdCylY(p - lc - vec3(0.,1.4,0.), 0.035, 1.4), H_POLE));
      r = opU(r, vec2(sdSphere(p - lc - vec3(0.,2.85,0.), 0.14), H_LAMP));
    }
  }

  // fuel drums, clustered stage-left
  for (int i = 0; i < 6; i++){
    float fi = float(i);
    vec3 dc = vec3(-ROOM_W + 1.1 + mod(fi,3.0)*0.68, 0.45, 4.0 + floor(fi/3.0)*0.68);
    float mat = mod(fi, 2.0) < 1.0 ? H_DRUMR : H_DRUMO;
    r = opU(r, vec2(sdCylY(p - dc, 0.32, 0.45), mat));
  }
  // crates, stage-right
  for (int i = 0; i < 4; i++){
    float fi = float(i);
    vec3 cc = vec3(ROOM_W - 1.0 - mod(fi,2.0)*0.85, 0.32, 6.5 + floor(fi/2.0)*0.85);
    r = opU(r, vec2(sdRoundBox(p - cc, vec3(0.38,0.32,0.38), 0.02), H_CRATE));
  }

  // hangar doors at the far wall, split leaves, buckle & tear open once rammed
  {
    float op = doorOpen(t);
    if (op < 0.995){
      for (int s = 0; s < 2; s++){
        float sg = s == 0 ? -1. : 1.;
        vec3 dc = vec3(sg * (0.25 + ROOM_W * 0.5 * (1.0 - op*0.15)), ROOM_CEIL*0.5, DOOR_Z);
        vec3 q = p - dc;
        // buckle: bend outward around a vertical hinge at the outer edge once rammed
        float bend = op * 0.9 * sg;
        q.z += bend * (q.x*sg) * 0.6;
        q.x -= sg * op * 1.8;
        float leaf = sdRoundBox(q, vec3(ROOM_W*0.5 - 0.15, ROOM_CEIL*0.5, 0.08), 0.03);
        r = opU(r, vec2(leaf, H_DOOR));
      }
    }
  }

  // the Kharkovchanka
  {
    vec3 vc = vec3(0., 0., vehZ(t));
    vec3 vp = p - vc;
    vec2 vv = sdVehicle(vp, t);
    r = opU(r, vv);
  }

  // monsters swarming in from the far side wall, silhouettes against the sodium lights
  if (t < 9.0){
    for (int i = 0; i < 5; i++){
      float fi = float(i);
      float seed = 0.2 + fi * 0.37;
      float start = 0.5 + fi * 0.35;
      float k = clamp((t - start) * 0.6, 0.0, 1.0);
      vec3 entry = vec3(-ROOM_W + 0.4, 0., DOOR_Z - 1.0 - fi*0.9);
      vec3 target = vec3(-0.8 - fi*0.3, 0., DOOR_Z - 6.0 - fi*0.6);
      vec3 mc = mix(entry, target, k);
      vec3 mp = p - mc;
      mp.xz *= rot2(-1.5 + seed);
      float bnd = sdCapsule(mp, vec3(0.,.2,0.), vec3(0.,1.85,0.), .5);
      if (bnd < 0.3) r = opU(r, sdMonster(mp, t*1.4 + seed*5.0, seed, 1.0));
    }
  }

  return r;
}

// ---------------- exterior map (t >= EXT_T) ----------------
vec3 fireCenter(){ return vec3(0., 3.0, DOOR_Z + 1.5); }

vec2 mapExterior(vec3 p, float t){
  vec2 r = vec2(1e5, 0.0);
  // snow ground, gently undulating
  float snow = p.y - (fbm3lo(p*0.25 + vec3(0.,0.,3.))*0.25 - 0.05);
  r = opU(r, vec2(snow, H_SNOW));

  // low dark hangar silhouette block behind, with a torn doorway glow
  vec3 hc = vec3(0., ROOM_CEIL*0.5, DOOR_Z + 2.0);
  float building = sdRoundBox(p - hc, vec3(ROOM_W+1.0, ROOM_CEIL*0.5, 3.0), 0.1);
  r = opU(r, vec2(building, H_WALL));

  // debris chunks thrown by the blast
  float bt = max(t - EXT_T, 0.0);
  for (int i = 0; i < 8; i++){
    float fi = float(i);
    vec3 dir = normalize(hash33(vec3(fi, 3.1, 7.2)) - 0.5 + vec3(0.,0.6,0.3));
    float dist = min(bt * 4.0, 10.0) * (0.5 + 0.5*hash11(fi+2.0));
    vec3 dc = fireCenter() + dir*dist - vec3(0., bt*bt*1.2, 0.);
    dc.y = max(dc.y, 0.05);
    vec3 q = p - dc;
    q.xy *= rot2(bt*(1.5+hash11(fi)));
    r = opU(r, vec2(sdRoundBox(q, vec3(0.12,0.09,0.09), 0.02), H_DEBRIS));
  }

  // the Kharkovchanka, receding
  {
    vec3 vc = vec3(0., 0., vehZ(t));
    vec3 vp = p - vc;
    vec2 vv = sdVehicle(vp, t);
    r = opU(r, vv);
  }
  return r;
}

vec2 map(vec3 p){
  float t = iTime;
  return t < EXT_T ? mapInterior(p, t) : mapExterior(p, t);
}

vec3 nrm(vec3 p){
  vec2 e = vec2(0.0015, 0.);
  return normalize(vec3(
    map(p + e.xyy).x - map(p - e.xyy).x,
    map(p + e.yxy).x - map(p - e.yxy).x,
    map(p + e.yyx).x - map(p - e.yyx).x));
}

float shadow(vec3 ro, vec3 rd, float maxT){
  float res = 1.0, tt = 0.03;
  for (int i = 0; i < 12; i++){
    float h = map(ro + rd*tt).x;
    res = min(res, 8.0*h/tt);
    tt += clamp(h, 0.03, 0.3);
    if (res < 0.04 || tt > maxT) break;
  }
  return clamp(res, 0.0, 1.0);
}

// ---------------- fireball (cheap fbm-shaded volumetric proxy) ----------------
vec3 fireballColor(vec3 ro, vec3 rd, float d, float t){
  float bt = t - EXT_T;
  if (bt < 0.0) return vec3(0.);
  vec3 c = fireCenter();
  float radius = min(bt * 5.5, 9.0) * (1.0 - 0.15*smoothstep(3.0,8.0,bt));
  vec3 oc = ro - c;
  float b = dot(oc, rd), cc2 = dot(oc,oc) - radius*radius;
  float disc = b*b - cc2;
  if (disc < 0.0) return vec3(0.);
  float sq = sqrt(disc);
  float t0 = max(-b - sq, 0.0), t1 = min(-b + sq, d);
  if (t1 <= t0) return vec3(0.);
  vec3 col = vec3(0.);
  const int FS = 10;
  float dith = fract(sin(dot(rd.xy, vec2(41.3,7.1)))*4131.3);
  for (int i = 0; i < FS; i++){
    float ft = (float(i)+dith)/float(FS);
    float tt = mix(t0, t1, ft);
    vec3 sp = ro + rd*tt;
    float rr = length(sp - c) / max(radius,0.001);
    float n = fbm3lo(sp*0.9 - vec3(0.,bt*2.2,0.));
    float density = smoothstep(1.0,0.3,rr) * (0.4 + 0.8*n);
    float core = smoothstep(0.35,0.0,rr);
    vec3 hot = mix(vec3(1.0,.35,.05), vec3(1.0,.85,.35), core);
    vec3 smoke = vec3(.06,.05,.05);
    vec3 c2 = mix(smoke, hot, smoothstep(0.15,0.75,density) * (1.0 - smoothstep(2.5,7.0,bt)*0.6));
    col += c2 * density * (1.0/float(FS)) * 3.2;
  }
  return col;
}

vec3 snowAlb(vec3 p){
  float n = fbm3lo(p*3.0);
  return mix(vec3(.55,.58,.62), vec3(.7,.73,.76), n) * (0.85+0.3*fbm3lo(p*10.));
}
vec3 metalAlb(vec3 p, vec3 base){
  return base * (0.75 + 0.4*fbm3lo(p*20.)) ;
}

vec3 shade(vec2 h, vec3 p, vec3 n, vec3 rd, vec3 keyPos, vec3 keyCol, float keyInt, float keyAtten, bool ext, float t){
  float m = h.y;
  vec3 albedo = vec3(.3); float rough = 0.6; bool emissive = false; vec3 emitCol = vec3(0.);

  if (m == H_FLOOR) albedo = vec3(.05,.055,.06) * (0.7+0.4*fbm3lo(p*4.));
  else if (m == H_CEIL) albedo = vec3(.02,.022,.024);
  else if (m == H_WALL) albedo = vec3(.10,.10,.11) * (0.7+0.4*fbm3lo(p*3.5));
  else if (m == H_TRUSS) { albedo = vec3(.08,.075,.07); rough = 0.4; }
  else if (m == H_DOOR) { albedo = mix(vec3(.28,.10,.06), vec3(.35,.32,.28), smoothstep(.5,.7,fbm3lo(p*6.))); rough = 0.5; }
  else if (m == H_DRUMR) { albedo = metalAlb(p, vec3(.42,.06,.05)); rough = 0.35; }
  else if (m == H_DRUMO) { albedo = metalAlb(p, vec3(.24,.26,.12)); rough = 0.4; }
  else if (m == H_CRATE) { albedo = vec3(.22,.16,.09)*(0.7+0.4*fbm3lo(p*9.)); rough = 0.7; }
  else if (m == H_POLE)  { albedo = vec3(.05,.05,.05); rough = 0.4; }
  else if (m == H_LAMP)  { emissive = true; emitCol = vec3(1.0,.55,.15) * 5.0; }
  else if (m == H_TRACK) { albedo = metalAlb(p, vec3(.05,.045,.04)); rough = 0.5; }
  else if (m == H_CAB)   { albedo = metalAlb(p, vec3(.5,.16,.06)); rough = 0.35; }
  else if (m == H_ROOF)  { albedo = metalAlb(p, vec3(.7,.7,.68)); rough = 0.4; }
  else if (m == H_HEAD)  { emissive = true; emitCol = vec3(1.0,.92,.78) * (ext ? 3.0 : 7.0); }
  else if (m == H_TAIL)  { emissive = true; emitCol = vec3(1.0,.1,.08) * 4.0; }
  else if (m == H_FIG)   { albedo = vec3(.02,.02,.022); rough = 0.7; }
  else if (m == H_SNOW)  albedo = snowAlb(p);
  else if (m == H_DEBRIS){ albedo = vec3(.12,.09,.07); rough = 0.5; }
  else albedo = vec3(.3);

  if (emissive) return emitCol;

  vec3 col = vec3(0.);
  vec3 L = keyPos - p; float ld = length(L); L /= max(ld,1e-4);
  float ndl = max(dot(n,L), 0.0);
  float atten = 1.0 / (1.0 + ld*ld*keyAtten);
  float sh = shadow(p + n*0.008, L, ld);
  col += albedo * ndl * atten * sh * keyCol * keyInt;

  vec3 h2 = normalize(L - rd);
  float spec = pow(max(dot(n,h2),0.0), mix(60.0,10.0,rough)) * (1.0-rough) * atten;
  col += spec * keyCol * sh * 0.35;

  // cold ambient fill
  vec3 fillDir = vec3(0., 1., -0.2);
  col += albedo * max(dot(n, normalize(fillDir)), 0.0) * (ext ? vec3(.03,.035,.045) : vec3(.008,.009,.012));
  col += albedo * (ext ? vec3(.01,.011,.014) : vec3(.004,.0045,.006));

  return col;
}

vec3 render(vec2 fc){
  float t = iTime;
  vec3 ro, ta; float focal;
  vec3 vc = vec3(0., 0., vehZ(t));

  if (t < 5.0){
    // wide shot from high in the rafters
    float k = clamp(t/5.0, 0., 1.);
    ro = vec3(mix(-2.6,-1.2,k), mix(6.4,5.8,k), mix(3.0, 6.5, k));
    ta = vec3(0.3, 1.6, mix(11.0, DOOR_Z-2.0, k*0.4));
    focal = 1.55;
  } else if (t < 11.0){
    // low angle near the tracks, close to the vehicle as it rams the doors
    float k = clamp((t-5.0)/6.0, 0., 1.);
    ro = vc + vec3(mix(-2.6,-1.8,k), 0.45, mix(-1.6,-3.4,k));
    ta = vc + vec3(0.1, 1.2, 3.0);
    focal = mix(2.0, 1.7, k);
  } else {
    // exterior: camera outside, looking back at the burning hangar as the tractor passes
    float k = clamp((t-11.0)/7.0, 0., 1.);
    ro = mix(vec3(3.6, 1.6, DOOR_Z+7.0), vec3(5.5, 2.0, DOOR_Z+15.0), k);
    ta = mix(vec3(0., 2.2, DOOR_Z+1.0), vec3(-1.0, 2.6, DOOR_Z+4.0), k);
    focal = 1.5;
  }

  vec3 rd = camRay(fc, ro, ta, focal, t < 5.0 ? 0.03 : 0.0);

  bool ext = t >= EXT_T;
  float d = 0.0; vec2 h; bool hitAny = false;
  for (int i = 0; i < 130; i++){
    vec3 p = ro + rd*d;
    h = map(p);
    float th = 0.0018 * max(d,1.0);
    if (h.x < th){ hitAny = true; break; }
    d += h.x * 0.82;
    if (d > 60.0) break;
  }

  // key light: headlights pre-ram / fireball glow post-blast, else sodium work lights
  vec3 keyPos; vec3 keyCol; float keyInt; float keyAtten;
  if (ext){
    vec3 fc3 = fireCenter();
    keyPos = fc3 + vec3(0.,1.0,-1.0);
    keyCol = vec3(1.0,.55,.25); keyInt = min((t-EXT_T)*3.0, 3.2); keyAtten = 0.02;
  } else {
    vec3 hc = vc + vec3(0.,1.35,2.72);
    keyPos = hc;
    keyCol = vec3(1.0,.92,.75); keyInt = 3.0; keyAtten = 0.35;
  }

  vec3 col;
  float hitD = hitAny ? d : 60.0;
  if (!hitAny){
    col = ext ? vec3(.006,.007,.01) : vec3(.002,.0022,.003);
  } else {
    vec3 p = ro + rd*d;
    vec3 n = nrm(p);
    col = shade(h, p, n, rd, keyPos, keyCol, keyInt, keyAtten, ext, t);

    // sodium ambient glow pooling near the work lights (interior only)
    if (!ext){
      for (int i = 0; i < 4; i++){
        float lz = 2.0 + float(i) * 6.0;
        for (int s = 0; s < 2; s++){
          float sg = s == 0. ? -1. : 1.;
          vec3 lc = vec3(sg*(ROOM_W-0.6), 2.85, lz);
          float ld = length(lc-p);
          col += vec3(1.0,.5,.12) * (1.0/(1.0+ld*ld*0.5)) * 0.55 * max(dot(n, normalize(lc-p)),0.0);
        }
      }
    }

    float fogK = ext ? 0.0009 : 0.01;
    float fog = min(1.0 - exp(-d*d*fogK), ext ? 0.55 : 0.4);
    vec3 fogCol = ext ? vec3(.02,.022,.03) : vec3(.003,.0035,.004);
    col = mix(col, fogCol, fog);
  }

  // fireball (exterior climax)
  if (ext){
    col += fireballColor(ro, rd, hitD, t);
  }

  // headlight volumetric shaft (interior, once lit) + exhaust smoke glow
  if (!ext && t > 0.6){
    vec3 hc = vc + vec3(0.,1.35,2.72);
    vec3 hdir = normalize(vec3(0.,-0.05,1.0));
    float dith = fract(sin(dot(fc, vec2(12.9898,78.233)))*43758.5453);
    vec3 vol = vec3(0.);
    const int VS = 7;
    for (int i = 0; i < VS; i++){
      float ft = (float(i)+dith)/float(VS);
      float sd = ft * min(hitD, 10.0);
      vec3 sp = ro + rd*sd;
      float c = dot(normalize(sp-hc), hdir);
      vol += smoothstep(0.9,0.995,c) / (1.0 + sd*sd*0.04);
    }
    float lightOn = smoothstep(0.6,1.0,t);
    col += vol * vec3(1.0,.9,.7) * 0.03 * lightOn;
  }

  // flash + shake handled in post via shot.js; add a soft screen-space bloom seed for the blast frame
  if (ext && t < EXT_T + 0.4){
    float k = 1.0 - smoothstep(EXT_T, EXT_T+0.4, t);
    col += vec3(1.0,.7,.4) * k*k*1.4;
  }

  return col;
}
