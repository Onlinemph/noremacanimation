// s08_lab — dead bio lab lit only by four specimen tanks + a cold flashlight.
// Tanks: analytic glass cylinders (not in the SDF) with a volumetric murky liquid,
// meniscus, bubbles and a marched sdMonster figure inside. Steel caps/pipes are SDF.
// Timeline: 0-7.5 lateral track along the row; 3-6 document insert (overlay);
// 7.5-10.2 push on tank 3: head turns, hand on glass, cracks; 10.2 burst + lunge; 11.2 cut.

#define MF_FLOOR  20.
#define MF_WALL   21.
#define MF_CEIL   22.
#define MF_CAP    23.
#define MF_PIPE   24.
#define MF_BTOP   25.
#define MF_TERM   26.
#define MF_SCREEN 27.
#define MF_PAPER  28.
#define MF_CLOCK  29.
#define MF_BOTTLE 30.
#define MF_FRAME  31.
#define MF_SHARD  32.
#define MF_LAMP   33.

const float TX = 1.75, TZ0 = .2, TSP = 1.9, TR = .52, TY0 = .5, TY1 = 2.3, LEVEL = 2.08;
const float T_BURST = 10.2;
const vec3 GREEN = vec3(.42, 1., .33);

vec3 tankC(int i){ return vec3(TX, 0., TZ0 + float(i) * TSP); }

float burstK(){ return step(T_BURST, iTime); }
float tankI(int i){
  float t = iTime;
  float fl = .92 + .08 * noise2(vec2(t * 7., float(i) * 5.));
  float base = i == 3 ? 1.15 : (i == 1 ? .8 : 1.);
  if (i == 2) base *= .75 + .25 * step(.12, noise2(vec2(t * 9., 3.)));   // failing ballast
  if (i == 3) base *= 1. + .35 * smoothstep(8.5, 10.1, t) * (.6 + .4 * sin(t * 31.));
  if (i == 3 && t > T_BURST) base = 1.1 + 1.2 * exp(-(t - T_BURST) * 6.);
  return base * fl;
}

// ------------------------------------------------------------ camera -----
vec3 camEnd(){ return vec3(-.42, 1.52, 4.95); }
vec3 lungePos(){
  float b = clamp((iTime - T_BURST) / 1.0, 0., 1.);
  vec3 c = tankC(3) + vec3(0., .45, 0.);
  vec3 cam = camEnd();
  vec3 dir = normalize(cam - c); dir.y = 0.; dir = normalize(dir);
  vec3 target = cam - dir * .8;
  target.y = cam.y - 1.3;
  float e = pow(b, 1.5);
  vec3 p = mix(c, target, e);
  p.y += sin(b * PI) * .25;
  return p;
}
vec3 gRo, gTa, gFlPos, gFlDir;
float gFocal;
void setupCamera(){
  float t = iTime;
  float s = clamp(t / 8., 0., 1.);
  vec3 ro0 = vec3(-2.0, 1.5, mix(-1.5, 3.2, s));
  vec3 ta0 = ro0 + vec3(3., -.12, 1.0);
  float k = smoothstep(6.6, 9.6, t);
  vec3 ro1 = camEnd() + vec3(0., 0., .0) + (camEnd() - tankC(3) - vec3(0., 1.52, 0.)) * .03 * (t - 8.);
  vec3 ta1 = tankC(3) + vec3(0., 1.5, 0.);
  gRo = mix(ro0, ro1, k);
  gTa = mix(ta0, ta1, k);
  gFocal = mix(1.15, 1.7, k) - .45 * smoothstep(T_BURST, T_BURST + .3, t);
  // burst: operator staggers back
  if (t > T_BURST){
    float b = t - T_BURST;
    gRo += normalize(gRo - ta1) * .35 * (1. - exp(-b * 4.)) + vec3(0., -.12 * b, 0.);
    gTa = mix(gTa, lungePos() + vec3(0., 1.2, 0.), .55 * smoothstep(0., .4, b));
  }
  // handheld
  vec3 hh = vec3(noise2(vec2(t * .9, 1.)), noise2(vec2(t * .8, 7.)), noise2(vec2(t * .7, 13.))) - .5;
  gRo += hh * .035;
  gTa += (vec3(noise2(vec2(t * .6, 21.)), noise2(vec2(t * .5, 29.)), 0.) - .5) * .06;

  // flashlight: right hand, slightly below the lens
  vec3 f = normalize(gTa - gRo), r = normalize(cross(f, vec3(0, 1, 0))), u = cross(r, f);
  gFlPos = gRo - r * .22 - u * .2 + f * .15;
  // sweep: bench & papers -> terminal -> clock -> tank 3
  vec3 a = vec3(.45, .95, -.4), b = vec3(.5, 1.05, 1.25), c = vec3(3., 2.35, 3.05), d = tankC(3) + vec3(-.3, 1.45, 0.);
  vec3 tgt = mix(a, b, smoothstep(.3, 2.8, t));
  tgt = mix(tgt, vec3(.5, .95, 2.6), smoothstep(3.2, 5.2, t));
  tgt = mix(tgt, c, smoothstep(5.2, 6.8, t));
  tgt = mix(tgt, d, smoothstep(7.0, 8.4, t));
  tgt += (vec3(noise2(vec2(t * 1.3, 3.)), noise2(vec2(t * 1.1, 5.)), noise2(vec2(t * 1.2, 8.))) - .5) * .25;
  if (t > T_BURST) tgt = mix(tgt, gRo + vec3(1.5, -1.6, -1.8), smoothstep(T_BURST, T_BURST + .1, t)); // flinch
  gFlDir = normalize(tgt - gFlPos);
}

// ------------------------------------------------------------ figures ----
vec3 dirToCam(int i){ vec3 d = camEnd() - tankC(i); d.y = 0.; return normalize(d); }
// press point of the hand on tank 3's glass (world)
vec3 pressN(){ vec3 d = dirToCam(3); return normalize(d + vec3(0., 0., -.25)); }
vec3 pressP(){ return tankC(3) + pressN() * TR + vec3(0., 1.58, 0.); }

float gFigT;
vec3 figSpace(int i, vec3 p, out float sc){
  float t = iTime, fi = float(i);
  sc = .8;
  vec3 c = tankC(i);
  vec3 q = p - c;
  float yaw = fi * 2.1 + .9 + .12 * sin(t * .21 + fi);
  float curl = (i == 0 ? .95 : (i == 1 ? .45 : (i == 2 ? .7 : .6))) + .05 * sin(t * .4 + fi);
  float tiltZ = i == 1 ? .35 : (i == 2 ? -.25 : .12);
  float lift = .58 + .05 * sin(t * .45 + fi * 2.);
  vec3 off = vec3(.05 * sin(t * .3 + fi), 0., .05 * cos(t * .27 + fi * 3.));
  gFigT = t * .35 + fi * 7. + .0173;
  if (i == 3){
    vec3 dc = dirToCam(3);
    float face = -atan(dc.x, dc.z);
    // slow drift, then a twitchy turn toward the light at ~7.8 s
    float k = smoothstep(7.6, 8.3, t);
    k += .08 * sin(clamp(t - 8.3, 0., 1.) * 20.) * exp(-max(t - 8.3, 0.) * 4.) * step(8.3, t);
    yaw = mix(yaw, face, k);
    curl = mix(curl, .2, smoothstep(7.8, 9.0, t));
    off += dc * mix(0., .16, smoothstep(8.0, 9.2, t));
    lift = mix(lift, .52, smoothstep(8., 9., t));
    gFigT = mix(gFigT, t * .8 + .0173, smoothstep(7.5, 8.2, t));
  }
  q -= off;
  q.y -= lift;
  q = rotY(q, yaw);
  q.y -= .95 * sc;
  q.yz *= rot2(-curl);
  q.xy *= rot2(tiltZ);
  q.y += .95 * sc;
  return q / sc;
}

float sdHand(vec3 p, float press){
  vec3 n = pressN();
  vec3 up = vec3(0, 1, 0);
  vec3 sd = normalize(cross(up, n));
  vec3 P = pressP() - n * (.028 + .18 * (1. - press));
  vec3 q = p - P;
  vec3 l = vec3(dot(q, sd), dot(q, up), dot(q, n));
  float palm = sdEllipsoid(l, vec3(.048, .055, .02));
  float h = palm;
  for (int k = 0; k < 4; k++){
    float fk = float(k) - 1.5;
    vec3 a = vec3(fk * .022, .045, 0.);
    vec3 b = a + vec3(fk * .018, .085 - abs(fk) * .012, .006 * press);
    h = smin(h, sdTaper(l, a, b, .011, .008), .01);
  }
  h = smin(h, sdTaper(l, vec3(-.04, .0, -.005), vec3(-.095, .05, 0.), .012, .009), .01);   // thumb
  // forearm back into the tank toward the shoulder
  vec3 sh = vec3(.12, -.3, -.36 + .1 * press);
  h = smin(h, sdTaper(l, vec3(0., -.03, -.01), sh, .026, .038), .02);
  // flattened against the glass
  h = max(h, l.z - .012);
  return h;
}

// burst lunge (world space)
vec2 lungeMap(vec3 p){
  vec3 dc = normalize(gRo - tankC(3)); dc.y = 0.; dc = normalize(dc);
  vec3 q = p - lungePos();
  q = rotY(q, -atan(dc.x, dc.z));
  float b = sdCapsule(q, vec3(0, .2, 0), vec3(0, 2., 0), 1.0);
  if (b > .2) return vec2(b, 0.);
  return sdMonster(q, iTime * 1.3 + .0173, .31, 1.);
}

vec2 figMap(int i, vec3 p){
  if (i == 4) return lungeMap(p);
  float sc;
  vec3 m = figSpace(i, p, sc);
  float b = sdCapsule(m, vec3(0, .35, 0), vec3(0, 1.75, 0), .55);
  vec2 r;
  if (b > .12) r = vec2(b * sc, 0.);
  else { r = sdMonster(m, gFigT, fract(float(i) * .37 + .11), 0.); r.x *= sc; }
  {
    vec3 c = tankC(i);
    vec3 nk = c + vec3(.05 * sin(iTime * .3 + float(i)), 1.75, .05 * cos(iTime * .27 + float(i) * 3.));
    float hose = sdTaper(p, c + vec3(.12, TY1, .05), mix(c + vec3(.12, TY1, .05), nk, .5) + vec3(.05, -.05, 0.), .018, .016);
    hose = min(hose, sdTaper(p, mix(c + vec3(.12, TY1, .05), nk, .5) + vec3(.05, -.05, 0.), nk, .016, .014));
    hose = min(hose, sdTaper(p, c + vec3(-.15, TY1, -.1), nk + vec3(-.05, -.1, 0.), .012, .01));
    r = opU(r, vec2(hose, M_CLOTH + .5));
  }
  if (i == 3){
    float press = smoothstep(8.35, 8.9, iTime);
    if (iTime > 8.0) r = opU(r, vec2(sdHand(p, press), M_SKIN));
  }
  return r;
}

// ------------------------------------------------------------ scene ------
vec2 map(vec3 p){
  // room planes are intersected analytically in render(); this is objects only
  vec2 r = vec2(1e5, 0.);

  // ---- tank hardware (domain repetition along z), nested bounds
  float ci = clamp(floor((p.z - TZ0) / TSP + .5), 0., 3.);
  vec3 q = p - vec3(TX, 0., TZ0 + ci * TSP);
  float rr = length(q.xz);
  float bT = rr - .72;
  if (bT > .1) r.x = min(r.x, bT);
  else {
    float ang = atan(q.z, q.x);
    float sect = (floor(ang / (TAU / 14.)) + .5) * (TAU / 14.);
    vec2 bxz = vec2(cos(sect), sin(sect)) * .565;
    float capD = 1e5, bolts = 1e5, pv = 1e5;
    if (q.y < .75){
      capD = sdCylY(q - vec3(0., .19, 0.), .66, .19);
      capD = min(capD, sdCylY(q - vec3(0., .44, 0.), .6, .06));
      bolts = sdCylY(q - vec3(bxz.x, .51, bxz.y), .018, .018);
    } else if (q.y > 2.1){
      capD = sdCylY(q - vec3(0., TY1 + .07, 0.), .6, .07);
      capD = min(capD, sdCylY(q - vec3(0., TY1 + .2, 0.), .5, .08));
      capD = smin(capD, sdEllipsoid(q - vec3(0., TY1 + .28, 0.), vec3(.45, .14, .45)), .03);
      bolts = sdCylY(q - vec3(bxz.x, TY1 - .01, bxz.y), .018, .018);
      pv = sdCylY(q - vec3(.12, 2.9, 0.), .055, .45);
      pv = min(pv, sdCylY(q - vec3(-.18, 2.8, .1), .035, .5));
    }
    // guide rods between caps (three)
    float a3 = floor((ang + PI / 3.) / (TAU / 3.)) * (TAU / 3.);
    capD = min(capD, sdCylY(q - vec3(cos(a3) * .6, 1.4, sin(a3) * .6), .014, .92));
    r = opU(r, vec2(capD, MF_CAP));
    r = opU(r, vec2(bolts, MF_PIPE));
    r = opU(r, vec2(pv, MF_PIPE));
  }
  // feed pipes + valve to the back wall
  {
    float bF = sdBox(q - vec3(.95, .2, 0.), vec3(.45, .14, .32));
    if (bF > .1) r.x = min(r.x, bF);
    else {
      float pv = sdCylX(q - vec3(.95, .22, .18), .05, .4);
      pv = min(pv, sdCylX(q - vec3(.9, .12, -.2), .035, .45));
      pv = min(pv, sdTorus((q - vec3(.8, .22, .18)).yxz, vec2(.08, .012)));
      r = opU(r, vec2(pv, MF_PIPE));
    }
  }
  // manifolds along z
  r = opU(r, vec2(sdCylZ(p - vec3(TX + .12, 3.05, 3.), .09, 3.8), MF_PIPE));
  r = opU(r, vec2(sdCylZ(p - vec3(TX + .92, .2, 3.), .07, 3.8), MF_PIPE));
  r = opU(r, vec2(sdCylZ(p - vec3(2.95, 1.9, 3.), .05, 3.8), MF_PIPE));

  // ---- broken tank 3 after the burst: jagged glass stumps
  if (iTime > T_BURST){
    vec3 bq = p - tankC(3);
    float ang = atan(bq.z, bq.x);
    float jag = .12 + .35 * abs(sin(ang * 3.1 + 1.)) * noise2(vec2(ang * 4., 1.)) ;
    float shell = abs(length(bq.xz) - TR) - .008;
    float stumpB = max(shell, max(bq.y - TY0 - jag, TY0 - bq.y));
    float jagT = .1 + .3 * abs(sin(ang * 2.3)) * noise2(vec2(ang * 5., 7.));
    float stumpT = max(shell, max(TY1 - jagT - bq.y, bq.y - TY1));
    r = opU(r, vec2(min(stumpB, stumpT), MF_SHARD));
  }

  // ---- lab bench along the row (between camera and tanks)
  float bB = sdBox(p - vec3(.52, .8, 1.1), vec3(.42, .82, 2.62));
  if (bB > .1) r.x = min(r.x, bB);
  else {
    float bt = sdBox(p - vec3(.52, .9, 1.05), vec3(.36, .025, 2.45));
    r = opU(r, vec2(bt, MF_BTOP));
    vec3 lq = p - vec3(.52, .44, 1.05);
    lq.x = abs(lq.x) - .31; lq.z = abs(lq.z) - 2.38;
    float fr = sdBox(lq, vec3(.025, .44, .025));
    fr = min(fr, sdBox(p - vec3(.52, .2, 1.05), vec3(.33, .015, 2.4)));  // lower shelf
    // drawer cabinet
    fr = min(fr, sdBox(p - vec3(.55, .45, -.8), vec3(.3, .4, .42)));
    r = opU(r, vec2(fr, MF_FRAME));
    // CRT terminal, screen facing the camera (-x)
    float bTm = sdBox(p - vec3(.5, 1.12, 1.25), vec3(.36, .24, .3));
    if (bTm > .05) r.x = min(r.x, bTm); else {
    vec3 tq = p - vec3(.62, 1.13, 1.25);
    float term = sdRoundBox(tq, vec3(.2, .2, .22), .03);
    term = min(term, sdRoundBox(tq - vec3(.2, -.02, 0.), vec3(.14, .15, .16), .05));
    float scr = sdRoundBox(tq + vec3(.2, 0., 0.), vec3(.012, .14, .17), .02);
    term = max(term, -scr);
    r = opU(r, vec2(term, MF_TERM));
    r = opU(r, vec2(sdBox(tq + vec3(.205, 0., 0.), vec3(.004, .13, .16)), MF_SCREEN));
    r = opU(r, vec2(sdRoundBox(p - vec3(.3, .94, 1.2), vec3(.09, .012, .22), .008), MF_TERM)); // keyboard
    }
    // papers and a clipboard, slightly rotated
    if (p.y < 1.){
    vec3 pq = p - vec3(.42, .928, -.2); pq.xz *= rot2(.35);
    float pap = sdBox(pq, vec3(.11, .002, .15));
    vec3 pq2 = p - vec3(.55, .929, .35); pq2.xz *= rot2(-.2);
    pap = min(pap, sdBox(pq2, vec3(.105, .002, .148)));
    vec3 pq3 = p - vec3(.36, .93, 2.2); pq3.xz *= rot2(.9);
    pap = min(pap, sdBox(pq3, vec3(.105, .003, .148)));
    r = opU(r, vec2(pap, MF_PAPER));
    }
    // bottles / flasks: silhouettes against the tanks
    float bBo = sdBox(p - vec3(.62, 1.1, 2.85), vec3(.16, .2, .38));
    if (bBo > .05) r.x = min(r.x, bBo); else {
    for (int k = 0; k < 4; k++){
      float fk = float(k);
      vec3 bp = p - vec3(.6 + .08 * sin(fk * 3.), .925, 2.55 + fk * .19);
      float hgt = .12 + .06 * hash11(fk + 3.);
      float bot = sdCylY(bp - vec3(0., hgt, 0.), .045 + .015 * hash11(fk), hgt);
      bot = smin(bot, sdCylY(bp - vec3(0., hgt * 2. + .04, 0.), .016, .05), .03);
      if (k == 2) bot = min(sdSphere(bp - vec3(0., .09, 0.), .09), sdCylY(bp - vec3(0., .22, 0.), .02, .07)); // round flask
      r = opU(r, vec2(bot, MF_BOTTLE));
    }
    }
    // microscope silhouette
    vec3 mq = p - vec3(.6, .925, 3.25);
    float mic = sdBox(mq - vec3(0., .02, 0.), vec3(.08, .02, .1));
    mic = min(mic, sdCapsule(mq, vec3(.06, .02, 0.), vec3(.02, .3, 0.), .02));
    mic = min(mic, sdCapsule(mq, vec3(.0, .28, 0.), vec3(-.08, .2, 0.), .025));
    r = opU(r, vec2(mic, MF_FRAME));
  }
  // ---- wall clock between tanks 1 and 2 (face toward -x)
  vec3 cq = p - vec3(3.02, 2.55, 3.05);
  r = opU(r, vec2(sdCylX(cq, .2, .035), MF_CLOCK));
  return r;
}

#define ZERO min(iFrame, 0)
// normals/AO as non-unrollable loops: one inlined copy of the SDF each (SwiftShader cost is code-size bound)
vec3 nrm(vec3 p){
  vec3 n = vec3(0.);
  for (int i = ZERO; i < 4; i++){
    vec3 e = .5773 * (2. * vec3(float(((i + 3) >> 1) & 1), float((i >> 1) & 1), float(i & 1)) - 1.);
    n += e * map(p + e * .0015).x;
  }
  return normalize(n);
}
vec3 figNrm(int fi, vec3 p){
  vec3 n = vec3(0.);
  for (int i = ZERO; i < 4; i++){
    vec3 e = .5773 * (2. * vec3(float(((i + 3) >> 1) & 1), float((i >> 1) & 1), float(i & 1)) - 1.);
    n += e * figMap(fi, p + e * .002).x;
  }
  return normalize(n);
}
float calcAO(vec3 p, vec3 n){
  float o = 0., s = 1.;
  for (int i = ZERO; i < 2; i++){
    float h = .03 + .12 * float(i);
    o += (h - map(p + n * h).x) * s; s *= .6;
  }
  return clamp(1. - 2.8 * o, 0., 1.);
}

// ------------------------------------------------------------ lighting ---
vec3 lightAll(vec3 p, vec3 n, vec3 rd, vec3 alb, float spk, float gloss){
  vec3 col = vec3(0.);
  vec3 V = -rd;
  for (int i = 0; i < 4; i++){
    vec3 c = tankC(i);
    vec3 pc = vec3(c.x, clamp(p.y, .75, 2.05), c.z);
    if (i == 3 && iTime > T_BURST) pc.y = .65;
    float kb = (i == 3 && iTime > T_BURST) ? .45 : 1.;
    vec3 L = pc - p; float d = length(L); L /= d;
    float dd = max(d - TR * .5, 0.);
    float at = kb * tankI(i) * 1.1 / (1. + 5. * dd * dd);
    // caps block light that would leave the tank steeply up/down
    at *= smoothstep(-.1, .35, 1. - abs(L.y));
    float ndl = max(dot(n, L), 0.);
    vec3 H = normalize(L + V);
    float sp = pow(max(dot(n, H), 0.), gloss) * spk * (gloss * .04 + .5);
    col += GREEN * at * (alb * ndl + sp);
  }
  // flashlight
  vec3 Lf = gFlPos - p; float lf = length(Lf); Lf /= lf;
  float cone = smoothstep(.935, .985, dot(-Lf, gFlDir)) * flashCookie(p, gFlPos, gFlDir);
  float fa = cone * 3.2 / (1. + lf * lf * .35);
  vec3 Hf = normalize(Lf + V);
  vec3 fcol = vec3(.72, .84, 1.);
  col += fcol * fa * (alb * max(dot(n, Lf), 0.) + pow(max(dot(n, Hf), 0.), gloss) * spk * (gloss * .04 + .5));
  // CRT glow
  vec3 Lt = vec3(.38, 1.13, 1.25) - p; float lt = length(Lt); Lt /= lt;
  float tflick = .8 + .2 * step(.3, noise2(vec2(iTime * 11., 2.)));
  col += vec3(.15, .6, .2) * .12 * tflick * alb * max(dot(n, Lt), 0.) / (1. + lt * lt * 12.);
  // whisper of cold fill so absolute black keeps a hint of form
  col += alb * vec3(.006, .008, .011);
  return col;
}

vec3 shadeScene(vec2 h, vec3 p, vec3 n, vec3 rd){
  float m = h.y;
  vec3 alb = vec3(.2);
  float spk = .1, gloss = 16.;
  vec3 emi = vec3(0.);
  if (m == MF_FLOOR){
    vec2 g = p.xz / .5;
    vec2 gf = abs(fract(g) - .5);
    float grout = smoothstep(.47, .5, max(gf.x, gf.y));
    float n1 = fbm3lo(p * 2.3);
    alb = mix(vec3(.15, .15, .14), vec3(.09, .1, .1), n1) * (.85 + .3 * hash21(floor(g)));
    alb *= 1. - .6 * grout;
    float wet = smoothstep(.45, .6, fbm3lo(p * vec3(.8, 1., .8) + 4.));
    alb *= 1. - .35 * wet;
    spk = .15 + 1.4 * wet; gloss = mix(12., 90., wet);
    // green puddle spreading from the burst tank
    if (iTime > T_BURST){
      vec3 c = tankC(3);
      float rr = length(p.xz - c.xz + vec2(.3, 0.) * (iTime - T_BURST));
      float R = .6 + 1.8 * (1. - exp(-(iTime - T_BURST) * 2.2));
      float pud = smoothstep(R, R - .3, rr + .25 * (fbm3lo(p * 3.) - .5));
      emi += GREEN * pud * .18 * (.6 + .4 * noise3(p * 6. + iTime));
      spk += pud * 2.; gloss = mix(gloss, 140., pud);
    }
  } else if (m == MF_WALL){
    float n1 = fbm3lo(p * 1.8);
    vec3 cream = mix(vec3(.3, .29, .25), vec3(.2, .19, .16), n1);
    vec3 green = mix(vec3(.09, .14, .12), vec3(.05, .08, .07), n1);
    // tiles on the lower wall
    vec2 tg = vec2(p.z + p.x, p.y) / .15;
    vec2 tf = abs(fract(tg) - .5);
    float tl = smoothstep(.44, .5, max(tf.x, tf.y));
    alb = mix(green * (1. - .5 * tl), cream, smoothstep(1.48, 1.5, p.y));
    alb *= .8 + .4 * fbm3lo(p * 9.);
    float drip = smoothstep(.6, .75, noise2(vec2((p.z + p.x) * 14., p.y * .6)));
    alb *= 1. - .5 * drip * smoothstep(1.4, .3, p.y);
    spk = .12; gloss = 30.;
  } else if (m == MF_CEIL){
    alb = vec3(.06);
  } else if (m == MF_CAP || m == MF_PIPE){
    float n1 = fbm3lo(p * 5.);
    alb = m == MF_CAP ? mix(vec3(.28, .29, .28), vec3(.16, .17, .16), n1) : mix(vec3(.12, .16, .14), vec3(.07, .09, .08), n1);
    float rust = smoothstep(.55, .72, fbm3lo(p * 11. + 2.));
    alb = mix(alb, vec3(.18, .08, .04), rust * .7);
    spk = (1. - rust) * .9; gloss = 60.;
    // lamp grate on top of the bottom cap, inside the tank
    vec3 q = p - tankC(int(clamp(floor((p.z - TZ0) / TSP + .5), 0., 3.)));
    {
      int ti = int(clamp(floor((p.z - TZ0) / TSP + .5), 0., 3.));
      float dg = min(abs(q.y - TY0), abs(q.y - TY1)) + max(length(q.xz) - TR, 0.) * .5;
      float lit = exp(-dg * 14.) * (q.y < 1.4 ? 1. : .35);
      if (!(ti == 3 && iTime > T_BURST)) emi += GREEN * tankI(ti) * lit * .25 * alb * 4.;
    }
    if (q.y > TY0 - .01 && q.y < TY0 + .02 && length(q.xz) < TR){
      float grate = step(.3, abs(fract(q.x * 14.) - .5)) * step(.3, abs(fract(q.z * 14.) - .5));
      int ti = int(clamp(floor((p.z - TZ0) / TSP + .5), 0., 3.));
      emi += GREEN * tankI(ti) * (1.5 + 3. * grate) * smoothstep(TR, TR * .3, length(q.xz));
    }
  } else if (m == MF_BTOP){
    alb = mix(vec3(.08, .09, .08), vec3(.04, .045, .04), fbm3lo(p * 6.));
    spk = .6; gloss = 50.;
  } else if (m == MF_FRAME){
    alb = vec3(.1, .12, .11) * (.7 + .5 * noise3(p * 20.)); spk = .5; gloss = 40.;
  } else if (m == MF_TERM){
    alb = vec3(.36, .34, .28) * (.7 + .4 * fbm3lo(p * 12.)); spk = .3; gloss = 30.;
  } else if (m == MF_SCREEN){
    vec2 uv = vec2((p.z - (1.25 - .16)) / .32, (p.y - (1.13 - .13)) / .26);
    vec3 tx = texture(iTex0, uv).rgb;
    float flick = .8 + .2 * step(.3, noise2(vec2(iTime * 11., 2.)));
    float roll = .85 + .15 * sin(uv.y * 40. - iTime * 6.);
    emi = tx * vec3(.3, 1., .45) * 1.6 * flick * roll + vec3(.004, .02, .008);
    alb = vec3(.02); spk = 1.2; gloss = 120.;
  } else if (m == MF_PAPER){
    vec2 uv = fract(p.xz * vec2(3.2, 2.3));
    alb = vec3(.55, .52, .44) * (.6 + .4 * texture(iTex1, uv).rgb);
    spk = .05;
  } else if (m == MF_CLOCK){
    vec3 cq = p - vec3(3.02, 2.55, 3.05);
    if (n.x < -.5){
      vec2 uv = vec2(cq.z, cq.y) / .4 + .5;
      vec4 tx = texture(iTex2, uv);
      alb = mix(vec3(.3, .29, .25), vec3(.02), tx.r);
      spk = 1.; gloss = 150.;   // glass cover
    } else alb = vec3(.05);
  } else if (m == MF_BOTTLE){
    alb = vec3(.02, .03, .025); spk = 1.6; gloss = 120.;
  } else if (m == MF_SHARD){
    alb = vec3(.03, .06, .04); spk = 3.; gloss = 200.;
    emi = GREEN * .15;
  } else if (m <= 4.5){
    alb = monsterAlbedo(m, p); spk = monsterSpec(m) * 1.5; gloss = 50.;
    alb *= .7;
  }
  return lightAll(p, n, rd, alb, spk, gloss) + emi;
}

// analytic in-scatter of a point light along a ray segment [0, tmax]
float scatterPoint(vec3 ro, vec3 rd, vec3 c, float tmax, float k){
  vec3 oc = c - ro;
  float b = dot(oc, rd);
  float h2 = max(dot(oc, oc) - b * b, 0.);
  float a = sqrt(1. / k + h2);
  return (atan((tmax - b) / a) - atan(-b / a)) / (k * a);
}

// ------------------------------------------------------------ tank -------
// crack mask on tank 3 glass at world point p
float crackMask(vec3 p){
  float t = iTime;
  float grow = smoothstep(8.9, 10.15, t);
  if (grow <= 0.) return 0.;
  vec3 c = pressP();
  vec3 n = pressN();
  vec3 sd = normalize(cross(vec3(0, 1, 0), n));
  vec2 v = vec2(dot(p - c, sd), p.y - c.y);
  float r = length(v);
  float R = grow * grow * .75 + .05;
  if (r > R) return 0.;
  float a = atan(v.y, v.x);
  float wob = (noise2(vec2(r * 9., a * 2.)) - .5) * .5;
  float sec = (a + wob) / TAU * 11.;
  float rad = abs(fract(sec) - .5) * r * TAU / 11.;
  float lineR = smoothstep(.0025, .0, rad) * step(.06, r) * step(.3, hash11(floor(sec) + 3.) + .7 * step(r, R * .6));
  float rings = 0.;
  for (int k = 0; k < 3; k++){
    float rk = (.1 + .08 * float(k)) * (1. + .2 * noise2(vec2(a * 3., float(k))));
    rings = max(rings, smoothstep(.0025, .0, abs(r - rk)) * step(rk, R) * step(.35, noise2(vec2(a * 6., float(k) * 4.))));
  }
  // only some fragments catch the light
  float spark = .25 + .75 * step(.55, hash11(floor(sec) * 7. + floor(r * 12.)));
  return clamp(max(lineR, rings) * spark * smoothstep(R, R * .8, r), 0., 1.);
}

vec3 tankComposite(int i, vec3 ro, vec3 rd, float t0, float t1, float tOp, vec3 behind, float dither, float tm, float fmat, vec3 fn){
  vec3 c = tankC(i);
  float I = tankI(i);
  vec3 pe = ro + rd * t0;
  vec3 ne = normalize(vec3(pe.x - c.x, 0., pe.z - c.z));
  float cosi = max(dot(-rd, ne), 0.);
  float F = .04 + .96 * pow(1. - cosi, 5.);
  float tEnd = min(t1, tOp);
  float tB = tm > 0. ? tm : tEnd;

  // --- murky glowing liquid: short dithered march
  vec3 acc = vec3(0.);
  float T = 1.;
  const int NS = 7;
  float seg = (tB - t0) / float(NS);
  for (int k = 0; k < NS; k++){
    float ts = t0 + (float(k) + dither) * seg;
    vec3 q = ro + rd * ts - c;
    float liquid = step(q.y, LEVEL + .01 * sin(q.x * 20. + iTime * 2.));
    float hgt = q.y - TY0;
    float lamp = exp(-hgt * 1.6) * 1.4 + .12;
    float murk = .5 + .9 * noise3(q * vec3(3., 1.6, 3.) + vec3(0., -iTime * .12, float(i) * 3.));
    float rad = 1. - .4 * length(q.xz) / TR;
    float em = liquid * lamp * murk * rad * I * .13 + (1. - liquid) * .015 * I;
    float sig = liquid * (.55 + .6 * murk) + (1. - liquid) * .05;
    acc += T * em * seg;
    T *= exp(-sig * seg);
  }
  vec3 col = GREEN * acc;
  // colour shifts deeper/yellower in the murk
  col *= mix(vec3(1.), vec3(1.15, .9, .6), clamp(1. - T, 0., 1.) * .4);

  // --- figure shading: backlit silhouette, wet highlights
  if (tm > 0.){
    vec3 p = ro + rd * tm;
    vec3 n = fn;
    float sc; vec3 m = figSpace(i, p, sc);
    vec2 hm = vec2(0., fmat);
    vec3 alb = monsterAlbedo(hm.y, m) * .35;
    vec3 q = p - c;
    // light: glow from the lamp below and the surrounding liquid (wrap)
    float below = max(dot(n, normalize(vec3(-q.x, -1.2, -q.z))), 0.);
    float lampA = exp(-(q.y - TY0) * 1.5) * 1.6 + .08;
    vec3 fc = alb * GREEN * I * (below * below * lampA);
    // rim from the glow behind the figure
    float rim = pow(1. - max(dot(n, -rd), 0.), 3.);
    fc += GREEN * I * rim * .15 * (.3 + lampA);
    // wet spec from the lamp and from the flashlight
    vec3 Lb = normalize(vec3(-q.x * .3, -1., -q.z * .3));
    float sp = pow(max(dot(reflect(rd, n), Lb), 0.), 24.) * monsterSpec(hm.y);
    fc += GREEN * sp * lampA * I * 1.5;
    vec3 Lf = normalize(gFlPos - p);
    float cone = smoothstep(.935, .985, dot(-Lf, gFlDir));
    fc += vec3(.72, .84, 1.) * cone * (alb * max(dot(n, Lf), 0.) * .6 + pow(max(dot(reflect(rd, n), Lf), 0.), 40.) * monsterSpec(hm.y) * 2.);
    col += T * fc;
  } else {
    // frosted rear glass lit from the lamp below: the lightbox the figure is seen against
    if (t1 < tOp + .02){
      vec3 pr = ro + rd * t1 - c;
      float yr = pr.y - TY0;
      float g = exp(-yr * 2.2) * 1.5 + .06;
      g *= .55 + .6 * fbm3lo(pr * vec3(5., 1.2, 5.) + vec3(0., -iTime * .05, float(i)));
      g *= .65 + .35 * smoothstep(.3, .6, noise3(pr * 2.2 + vec3(float(i) * 5., iTime * .03, 0.)));   // dark murk clouds
      g *= 1. - .3 * smoothstep(.55, .7, noise2(vec2(atan(pr.z, pr.x) * 9., pr.y * 1.5 + float(i))));  // algae streaks
      g *= step(pr.y, LEVEL) + .15;
      col += T * mix(GREEN, vec3(.6, .8, .2), smoothstep(.3, 1.4, yr)) * I * g * .6;
      col += T * behind * .15;
    } else col += T * behind * .7;
  }

  // --- meniscus + underside of the surface (total internal reflection band)
  if (abs(rd.y) > 1e-4){
    float tl = (LEVEL + c.y - ro.y) / rd.y;
    if (tl > t0 && tl < tB){
      vec3 pl = ro + rd * tl - c;
      float rr = length(pl.xz) / TR;
      float under = step(ro.y, LEVEL);
      col += GREEN * I * (.07 + .7 * pow(rr, 10.)) * .7 * under * (.5 + .5 * noise3(pl * 12. + iTime));
    }
  }
  float ye = pe.y - c.y;
  float men = smoothstep(.025, .0, abs(ye - LEVEL - .008)) + .5 * smoothstep(.06, .0, ye - LEVEL) * step(LEVEL, ye);
  col += GREEN * I * men * .7;

  // --- bubbles & suspended flecks (analytic points, only in front of the figure)
  float liqT = tB;
  for (int k = 0; k < 18; k++){
    float fk = float(k);
    vec3 hk = hash33(vec3(fk, float(i) * 7.1, 3.3));
    float col3 = floor(fk / 6.);
    vec3 hc = hash33(vec3(col3, float(i), 9.));
    float spd = .18 + .25 * hk.y;
    float y = TY0 + .1 + fract(iTime * spd * .5 + hk.x) * (LEVEL - TY0 - .1);
    float ang = hc.x * TAU, rad = .15 + .25 * hc.y;
    vec3 bp = c + vec3(cos(ang) * rad + .02 * sin(y * 20. + fk), y, sin(ang) * rad + .02 * cos(y * 17. + fk));
    vec3 ob = bp - ro;
    float tb = dot(ob, rd);
    if (tb < t0 || tb > liqT) continue;
    float db = length(ob - rd * tb);
    float br = (.006 + .012 * hk.z) * (1. + .5 * (y - TY0));
    float ring = smoothstep(br, br * .75, db) * (.35 + .65 * smoothstep(br * .4, br * .9, db));
    col += vec3(.7, 1., .75) * ring * .9 * I * exp(-(tb - t0) * 1.2);
  }
  for (int k = 0; k < 14; k++){
    float fk = float(k);
    vec3 hk = hash33(vec3(fk, float(i) * 3.7, 17.));
    vec3 fp = c + vec3((hk.x - .5) * .8, TY0 + .2 + hk.y * 1.4 + .05 * sin(iTime * .3 + fk), (hk.z - .5) * .8);
    fp.y += fract(iTime * .02 + hk.x) * .2;
    vec3 of = fp - ro; float tf = dot(of, rd);
    if (tf < t0 || tf > liqT || length(fp.xz - c.xz) > TR) continue;
    float df = length(of - rd * tf);
    col += GREEN * smoothstep(.006, .0, df) * .5 * I * exp(-(tf - t0) * 1.5);
  }

  // --- glass: grime, condensation, reflections, bright edges
  float grime = fbm3lo(pe * vec3(6., 2., 6.) + float(i));
  float cond = smoothstep(.55, .75, noise3(pe * vec3(25., 8., 25.)));
  col *= 1. - .3 * grime * (1. - F);
  col += GREEN * I * .05 * cond;
  col += GREEN * I * pow(1. - cosi, 4.) * .3;                         // thick glass at grazing angles glows
  vec3 R = reflect(rd, ne);
  // flashlight glint on the glass
  vec3 Lf = normalize(gFlPos - pe);
  float cone = smoothstep(.935, .985, dot(-Lf, gFlDir));
  col += vec3(.8, .9, 1.) * cone * pow(max(dot(R, Lf), 0.), 600.) * 2.5;
  col += vec3(.8, .9, 1.) * cone * F * .25;
  // neighbours reflected as vertical streaks
  for (int j = 0; j < 4; j++){
    if (j == i) continue;
    vec3 L = normalize(tankC(j) + vec3(0., 1.3, 0.) - pe);
    col += GREEN * tankI(j) * pow(max(dot(R, L), 0.), 40.) * .8 * F * 4.;
  }
  // cracks catching light
  if (i == 3){
    float cr = crackMask(pe);
    col = col * (1. - .35 * cr) + cr * (vec3(.7, 1., .8) * (.25 + 3. * cone) + GREEN * .35 * I);
  }
  return col;
}

// ------------------------------------------------------------ burst fx ---
vec3 burstFX(vec3 ro, vec3 rd, float tOp){
  float b = iTime - T_BURST;
  if (b < 0. || b > 1.2) return vec3(0.);
  vec3 col = vec3(0.);
  vec3 c = tankC(3);
  vec3 n = normalize(gRo - c); n.y = 0.; n = normalize(n);
  vec3 sd = normalize(cross(vec3(0, 1, 0), n));
  for (int k = 0; k < 80; k++){
    float fk = float(k);
    vec3 h = hash33(vec3(fk, 1.7, 5.3));
    vec3 h2 = hash33(vec3(fk, 8.1, 2.9));
    bool shard = k < 32;
    vec3 o = c + vec3(0., TY0 + .15 + h.y * 1.7, 0.) + n * TR * (.6 + .4 * h2.z) + sd * (h.x - .5) * .95;
    float spd = shard ? 2.5 + 3.5 * h.z : 1.2 + 3.2 * h.z;
    vec3 v = n * spd + sd * (h2.x - .5) * 3.2 + vec3(0., (h2.y - .3) * 2.8, 0.);
    float tb = b - h2.z * (shard ? .08 : .3);
    if (tb < 0.) continue;
    vec3 p = o + v * tb + vec3(0., -4.9 * tb * tb, 0.);
    float tq0 = max(tb - (shard ? .02 : .06), 0.);
    vec3 pp = o + v * tq0 + vec3(0., -4.9 * tq0 * tq0, 0.);
    if (p.y < 0.) continue;
    // distance from the view ray to the motion segment
    vec3 ba = p - pp;
    vec3 w0 = pp - ro;
    // closest points between ray and segment
    float aa = dot(rd, rd), bb = dot(rd, ba), cc = dot(ba, ba), dd = dot(rd, w0), ee = dot(ba, w0);
    float den = max(aa * cc - bb * bb, 1e-6);
    float s = clamp((aa * ee - bb * dd) / den, 0., 1.);
    vec3 q = pp + ba * s;
    float tq = dot(q - ro, rd);
    if (tq < 0. || tq > tOp) continue;
    float dist = length(q - ro - rd * tq);
    if (shard){
      float sz = .003 + .006 * h.z;
      float glint = pow(hash11(fk + floor(iTime * 24.) * .37), 5.) * 16. + .3;
      col += vec3(.85, 1., .9) * smoothstep(sz, 0., dist) * glint;
    } else {
      float sz = .006 + .022 * h.z * h.z;
      col += GREEN * smoothstep(sz, sz * .2, dist) * (.8 + .8 * h2.y) * exp(-tb * 1.5);
    }
  }
  return col;
}

// ------------------------------------------------------------ render -----
vec3 render(vec2 fc){
  if (uP[0] > .5) return vec3(0.);
  setupCamera();
  vec3 ro = gRo;
  vec3 rd = camRay(fc, ro, gTa, gFocal, .01 * sin(iTime * .5));
  float dither = hash21(fc + fract(iTime * 7.13) * 100.);

  // analytic room box
  vec3 bmin = vec3(-2.4, 0., -3.2), bmax = vec3(3.05, 3.3, 8.6);
  vec3 tb = (mix(bmin, bmax, step(0., rd)) - ro) / rd;
  float tRoom = min(min(tb.x, tb.y), tb.z);
  vec3 nRoom; float mRoom;
  if (tRoom == tb.y){ nRoom = vec3(0., -sign(rd.y), 0.); mRoom = rd.y < 0. ? MF_FLOOR : MF_CEIL; }
  else if (tRoom == tb.x){ nRoom = vec3(-sign(rd.x), 0., 0.); mRoom = MF_WALL; }
  else { nRoom = vec3(0., 0., -sign(rd.z)); mRoom = MF_WALL; }
  // objects AABB
  vec3 omin = vec3(-.05, 0., -1.3), omax = vec3(3.05, 3.3, 7.);
  vec3 ta = (omin - ro) / rd, tc = (omax - ro) / rd;
  vec3 tn = min(ta, tc), tf = max(ta, tc);
  float tIn = max(max(tn.x, tn.y), max(tn.z, 0.)), tOut = min(min(tf.x, tf.y), tf.z);
  // nearest tank the ray enters through its glass side
  float bestT = 1e5, bestT1 = 0.; int bi = -1;
  for (int i = 0; i < 4; i++){
    if (i == 3 && iTime > T_BURST) continue;
    vec3 q = ro - tankC(i);
    float a = dot(rd.xz, rd.xz), b = dot(q.xz, rd.xz), cc = dot(q.xz, q.xz) - TR * TR;
    float disc = b * b - a * cc;
    if (disc < 0.) continue;
    float sq = sqrt(disc);
    float t0 = (-b - sq) / a, t1 = (-b + sq) / a;
    float y0 = ro.y + rd.y * t0;
    if (t0 > 0. && t0 < bestT && y0 > TY0 && y0 < TY1){ bestT = t0; bestT1 = t1; bi = i; }
  }
  float tEndM = min(min(tRoom, tOut), bestT);
  float d = tIn; vec2 h = vec2(0.); bool hit = false;
  if (tIn < tEndM){
    for (int i = 0; i < 64; i++){
      vec3 p = ro + rd * d;
      h = map(p);
      if (h.x < .002 * d) { hit = true; break; }
      d += h.x;
      if (d > tEndM) break;
    }
  }
  // ---- the one creature march per pixel: the lunging monster (burst) or the figure in this tank
  bool tankPix = !hit && bi >= 0 && bestT < tRoom;
  float tExit = 0.; vec3 behind = vec3(.004, .01, .006);
  if (tankPix){
    vec3 c = tankC(bi);
    float I = tankI(bi);
    tExit = bestT1;
    if (rd.y < 0.){
      float tp = (TY0 - ro.y) / rd.y;
      if (tp < tExit){
        tExit = tp;
        vec3 q = ro + rd * tp - c;
        float grate = step(.3, abs(fract(q.x * 14.) - .5)) * step(.3, abs(fract(q.z * 14.) - .5));
        behind = GREEN * I * (.6 + 2.2 * grate) * smoothstep(TR, TR * .2, length(q.xz));
      }
    } else {
      float tp = (TY1 - ro.y) / rd.y;
      if (tp < tExit){ tExit = tp; behind = GREEN * I * .06; }
    }
  }
  int fi = -1; float fa = 0., fb = 0.;
  bool lunge = iTime > T_BURST && iTime < 11.4;
  if (lunge){ fi = 4; fa = .05; fb = hit ? d : (tankPix ? bestT : tRoom); }
  else if (tankPix){ fi = bi; fa = bestT + .01; fb = tExit; }
  float tm = -1., fmat = 0.; vec3 fn = vec3(0., 1., 0.);
  if (fi >= 0){
    float tt = fa;
    for (int k = 0; k < 40; k++){
      vec2 fh = figMap(fi, ro + rd * tt);
      if (fh.x < .0015 * tt) { tm = tt; fmat = fh.y; break; }
      tt += max(fh.x, .006);
      if (tt > fb) break;
    }
    if (tm > 0.) fn = figNrm(fi, ro + rd * tm);
  }

  vec3 col = vec3(0.);
  if (lunge && tm > 0.){
    // the creature out of the tank: silhouette against the green, wet rim light
    vec3 p = ro + rd * tm;
    vec3 alb = monsterAlbedo(fmat, p) * .6;
    vec3 lc = tankC(3) + vec3(0., .9, 0.) - normalize(camEnd() - tankC(3)) * .9;   // glow source behind the creature
    vec3 Lb = normalize(lc - p);
    float lb = tankI(3) * 1.4 / (1. + dot(lc - p, lc - p) * .8);
    float rim = pow(1. - max(dot(fn, -rd), 0.), 2.5) * max(dot(fn, Lb) + .3, 0.);
    col = GREEN * lb * (alb * max(dot(fn, Lb), 0.) * .5 + rim * .8 + pow(max(dot(reflect(rd, fn), Lb), 0.), 20.) * monsterSpec(fmat) * 1.5);
    vec3 Lf = normalize(gFlPos - p);
    col += vec3(.72, .84, 1.) * smoothstep(.935, .985, dot(-Lf, gFlDir)) * alb * max(dot(fn, Lf), 0.) * .5;
    d = tm;
  } else if (tankPix){
    d = tExit;
    col = tankComposite(bi, ro, rd, bestT, bestT1, tExit, behind, dither, lunge ? -1. : tm, fmat, fn);
  } else {
    vec3 n;
    if (!hit){ d = tRoom; h = vec2(0., mRoom); n = nRoom; }
    else n = nrm(ro + rd * d);
    vec3 p = ro + rd * d;
    col = shadeScene(h, p, n, rd);
    col *= mix(.3, 1., calcAO(p, n));
    col *= exp(-max(d - 4., 0.) * .25);
  }

  // glowing fog around the tanks (analytic) and in the flashlight beam
  float tmax = min(d, 14.);
  vec3 fog = vec3(0.);
  for (int i = 0; i < 4; i++){
    vec3 c = tankC(i) + vec3(0., 1.2, 0.);
    fog += GREEN * tankI(i) * scatterPoint(ro, rd, c, tmax, 2.2);
    fog += GREEN * tankI(i) * .5 * scatterPoint(ro, rd, tankC(i) + vec3(0., .25, 0.), tmax, 5.);
  }
  if (iTime > T_BURST){
    // atomised liquid hanging behind the creature: the backdrop its silhouette reads against
    float bm = iTime - T_BURST;
    vec3 mc = tankC(3) + vec3(0., 1.1, 0.) + normalize(camEnd() - tankC(3)) * (.3 + .8 * bm);
    fog += GREEN * 2. * exp(-bm * 1.2) * scatterPoint(ro, rd, mc, tmax, 4.);
  }
  col += fog * .009 * (.7 + .6 * noise3(ro + rd * 2. + vec3(0., 0., iTime * .1)));
  vec3 beam = vec3(0.);
  for (int i = 0; i < 6; i++){
    float ts = (float(i) + dither) / 6. * min(tmax, 6.);
    vec3 sp = ro + rd * ts;
    vec3 L = sp - gFlPos; float ld = length(L);
    float cn = smoothstep(.935, .985, dot(L / ld, gFlDir));
    beam += vec3(.72, .84, 1.) * cn / (1. + ld * ld * .5) * (.6 + .8 * noise3(sp * 2. + iTime * .2));
  }
  col += beam * min(tmax, 6.) / 6. * .05;

  col += burstFX(ro, rd, d);
  return col;
}
