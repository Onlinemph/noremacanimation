// ============================================================================
// OBJECT 9 — shared GLSL library (prepended to every shot.glsl)
// Each shot must define:   vec3 render(vec2 fc)   returning LINEAR HDR color.
// Available uniforms: iResolution, iTime, iFrame, uP[16], iPrev, iTex0..iTex3
// ============================================================================

#define PI 3.14159265
#define TAU 6.2831853

// ---------------------------------------------------------------- hashing ---
float hash11(float p){ p = fract(p * .1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float hash31(vec3 p3){ p3 = fract(p3 * .1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }
vec2  hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
vec3  hash33(vec3 p3){ p3 = fract(p3 * vec3(.1031, .1030, .0973)); p3 += dot(p3, p3.yxz + 33.33); return fract((p3.xxy + p3.yxx) * p3.zyx); }

// ------------------------------------------------------------------ noise ---
float noise2(vec2 p){
  vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
  return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float noise3(vec3 p){
  vec3 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
  return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
             mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm2(vec2 p){ float a = .5, s = 0.; for (int i = 0; i < 5; i++){ s += a * noise2(p); p = p * 2.03 + 17.1; a *= .5; } return s; }
float fbm3(vec3 p){ float a = .5, s = 0.; for (int i = 0; i < 5; i++){ s += a * noise3(p); p = p * 2.03 + 17.1; a *= .5; } return s; }
float fbm3lo(vec3 p){ float a = .5, s = 0.; for (int i = 0; i < 3; i++){ s += a * noise3(p); p = p * 2.03 + 17.1; a *= .5; } return s; }

// ------------------------------------------------------------- transforms ---
mat2 rot2(float a){ float c = cos(a), s = sin(a); return mat2(c, s, -s, c); }
// rotate p so that direction d maps to +y (for aligning primitives)
vec3 rotX(vec3 p, float a){ p.yz *= rot2(a); return p; }
vec3 rotY(vec3 p, float a){ p.xz *= rot2(a); return p; }
vec3 rotZ(vec3 p, float a){ p.xy *= rot2(a); return p; }

// ----------------------------------------------------------------- SDFs -----
float sdSphere(vec3 p, float r){ return length(p) - r; }
float sdBox(vec3 p, vec3 b){ vec3 q = abs(p) - b; return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.); }
float sdRoundBox(vec3 p, vec3 b, float r){ vec3 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.) - r; }
float sdBox2(vec2 p, vec2 b){ vec2 q = abs(p) - b; return length(max(q, 0.)) + min(max(q.x, q.y), 0.); }
float sdCapsule(vec3 p, vec3 a, vec3 b, float r){ vec3 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.); return length(pa - ba * h) - r; }
// capsule with radius tapering from ra (at a) to rb (at b)
float sdTaper(vec3 p, vec3 a, vec3 b, float ra, float rb){ vec3 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.); return length(pa - ba * h) - mix(ra, rb, h); }
// cylinder along Y, half-height h, radius r
float sdCylY(vec3 p, float r, float h){ vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h); return min(max(d.x, d.y), 0.) + length(max(d, 0.)); }
// cylinder along Z
float sdCylZ(vec3 p, float r, float h){ vec2 d = abs(vec2(length(p.xy), p.z)) - vec2(r, h); return min(max(d.x, d.y), 0.) + length(max(d, 0.)); }
// cylinder along X
float sdCylX(vec3 p, float r, float h){ vec2 d = abs(vec2(length(p.yz), p.x)) - vec2(r, h); return min(max(d.x, d.y), 0.) + length(max(d, 0.)); }
float sdTorus(vec3 p, vec2 t){ vec2 q = vec2(length(p.xz) - t.x, p.y); return length(q) - t.y; }
float sdEllipsoid(vec3 p, vec3 r){ float k0 = length(p / r); float k1 = length(p / (r * r)); return k0 * (k0 - 1.) / k1; }
float smin(float a, float b, float k){ float h = clamp(.5 + .5 * (b - a) / k, 0., 1.); return mix(b, a, h) - k * h * (1. - h); }
float smax(float a, float b, float k){ return -smin(-a, -b, k); }
// union for (dist, material) pairs
vec2 opU(vec2 a, vec2 b){ return a.x < b.x ? a : b; }

// ---------------------------------------------------------------- camera ----
// Returns world-space ray direction. fov = vertical focal factor (1.5 ~ 67deg, 2.5 ~ tele)
vec3 camRay(vec2 fc, vec3 ro, vec3 ta, float focal, float roll){
  vec2 uv = (fc - .5 * iResolution) / iResolution.y;
  vec3 f = normalize(ta - ro);
  vec3 r = normalize(cross(f, vec3(sin(roll), cos(roll), 0.)));
  vec3 u = cross(r, f);
  return normalize(uv.x * r + uv.y * u + focal * f);
}
vec2 screenUV(vec2 fc){ return (fc - .5 * iResolution) / iResolution.y; }

// ---------------------------------------------------------------- lighting --
// Flashlight / spotlight falloff. ldir normalized. Returns 0..1 cone * inverse-square-ish.
float spotLight(vec3 p, vec3 lpos, vec3 ldir, float cosOuter, float cosInner){
  vec3 L = p - lpos; float d = length(L);
  float c = dot(L / d, ldir);
  float cone = smoothstep(cosOuter, cosInner, c);
  return cone / (1. + d * d * .15);
}
// Flashlight cookie: ring structure typical of cheap reflector torches
float flashCookie(vec3 p, vec3 lpos, vec3 ldir){
  vec3 L = normalize(p - lpos);
  float a = acos(clamp(dot(L, ldir), -1., 1.));
  return .75 + .35 * smoothstep(.09, .06, a) + .1 * sin(a * 140.);
}
// Henyey–Greenstein phase for volumetric scattering
float hgPhase(float cosT, float g){ float g2 = g * g; return (1. - g2) / (4. * PI * pow(1. + g2 - 2. * g * cosT, 1.5)); }

// ---------------------------------------------------------------- palette ---
// Material IDs shared across shots (return as .y from map functions):
#define M_SKIN   1.0   // frostbitten dead flesh, grey-blue with purple mottling
#define M_CLOTH  2.0   // dirty lab coat / padded telogreika
#define M_GORE   3.0   // wet exposed flesh / blood, dark red, glossy
#define M_BONE   4.0   // teeth, ribs, claws
#define M_GUNMETAL 5.0 // blued steel
#define M_WOOD   6.0   // stock/forend wood
#define M_CONCRETE 7.0
#define M_STEEL  8.0   // painted steel (walls, doors)
#define M_ICE    9.0
#define M_SNOW   10.0

vec3 skinColor(vec3 p){
  float n = fbm3lo(p * 9.);
  vec3 base = mix(vec3(.46, .47, .50), vec3(.30, .26, .33), n);       // grey-blue to purple bruise
  base = mix(base, vec3(.20, .06, .06), smoothstep(.62, .75, fbm3lo(p * 4. + 3.))); // dried blood
  float vein = smoothstep(.035, .0, abs(noise3(p * 13.) - .5)) * smoothstep(.3, .7, noise3(p * 3. + 5.));
  base = mix(base, vec3(.12, .08, .16), vein * .8);                                   // dark veins
  return base;
}
vec3 goreColor(vec3 p){
  float n = noise3(p * 30.);
  return mix(vec3(.05, .004, .006), vec3(.15, .014, .013), n);
}
// procedural blood splatter mask on a 2D surface coordinate (meters). 0..1
float bloodSplat(vec2 p, float seed){
  float m = 0.;
  vec2 c = hash22(vec2(seed, seed * 1.7)) * .3;
  float d = length(p - c);
  float blob = smoothstep(.28, .12, d + (fbm2(p * 6. + seed) - .5) * .25);
  m = max(m, blob);
  for (int i = 0; i < 10; i++){
    vec2 h = hash22(vec2(seed + float(i) * 7.3, 3.1));
    vec2 dir = normalize(h - .5);
    float along = dot(p - c, dir), across = abs(dot(p - c, vec2(-dir.y, dir.x)));
    float len = .3 + .6 * h.x;
    m = max(m, smoothstep(.018 * (1. - along / len), .0, across) * step(0., along) * step(along, len));
    vec2 dp = c + dir * (len + .05 * h.y);
    m = max(m, smoothstep(.03 * h.y + .01, .0, length(p - dp)));
  }
  // drips running down (-y)
  float dx = fract(p.x * 7. + seed) - .5; float cid = floor(p.x * 7. + seed);
  float dl = hash11(cid) * .6 * blob;
  m = max(m, smoothstep(.06, .02, abs(dx)) * step(p.y, c.y) * step(c.y - dl - .2, p.y) * step(.55, hash11(cid + 4.)));
  return clamp(m, 0., 1.);
}

// ---------------------------------------------------------------- MONSTER ---
// "The former staff." Emaciated humanoid, feet at y=0, facing +Z, ~1.9 m tall when upright.
// p      : point in monster local space
// t      : time (drives twitching and gait)
// seed   : per-individual variation (0..1). seed < .5 wears a lab coat, >= .5 a padded telogreika.
// run    : 0 = twitching idle stance, 1 = sprinting lunge
// returns vec2(dist, material). Cloth material is M_CLOTH (lab coat) or M_CLOTH + .5 (dark jacket):
// always shade through monsterAlbedo(mat, p), which handles both.
// Bound it first with sdCapsule(p, vec3(0,.2,0), vec3(0,2.,0), 1.0) for speed.

// two-bone IK: returns the middle joint for chain a -> ? -> b with bone lengths l1, l2, bending toward pole
vec3 ikJoint(vec3 a, vec3 b, float l1, float l2, vec3 pole){
  vec3 d = b - a; float L = clamp(length(d), abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3);
  vec3 dn = normalize(d);
  float x = (l1 * l1 - l2 * l2 + L * L) / (2. * L);
  float y = sqrt(max(l1 * l1 - x * x, 0.));
  vec3 pv = normalize(pole - dn * dot(pole, dn) + 1e-5);
  return a + dn * x + pv * y;
}

vec2 sdMonster(vec3 p, float t, float seed, float run){
  float sd = seed * 13.7;
  float jacket = step(.5, seed);
  float spasm = pow(noise2(vec2(t * 5. + sd, sd * 3.)), 4.) * 3.;          // occasional violent spasms
  float jerk = (noise2(vec2(t * 23., sd)) - .5) * spasm;
  float ph = t * mix(1.1, 6.2, run) + sd;                                  // gait phase
  float lean = mix(.38, .85, run) + .08 * sin(t * .7 + sd) + .06 * jerk;
  float roll = .12 * (hash11(sd + 1.) - .5) + .05 * jerk;                  // lopsided stance

  vec3 P = vec3(.03 * jerk, mix(.9, .82, run) + run * .05 * abs(sin(ph)), 0.);
  vec3 u = normalize(vec3(sin(roll), cos(lean), sin(lean)));             // spine direction
  vec3 f = normalize(vec3(0., -sin(lean), cos(lean)));                    // chest forward
  vec3 x = normalize(cross(u, f));                                        // body right
  f = cross(x, u);

  vec3 C = P + u * .42;                                                   // chest
  vec3 N = P + u * .6;                                                    // neck base
  float tilt = 1.1 * (hash11(sd + 2.) - .5) + .35 * jerk;                 // broken-neck tilt
  vec3 hy = normalize(u * cos(tilt) + x * sin(tilt) + f * .45);
  vec3 H = N + hy * .13;
  vec3 hz = normalize(f - hy * dot(f, hy));
  vec3 hx = cross(hy, hz);

  vec3 bq = vec3(dot(p - C, x), dot(p - C, u), dot(p - C, f));           // body space around chest
  vec3 hq = vec3(dot(p - H, hx), dot(p - H, hy), dot(p - H, hz));        // head space

  // ---------------- flesh (one smooth organic union)
  float rib = sdEllipsoid(bq - vec3(0., -.05, 0.), vec3(.155, .2, .11));
  float abdo = sdTaper(p, P + u * .04, C - u * .12, .075, .1);
  float pel = sdEllipsoid(p - P, vec3(.14, .09, .09));
  float neck = sdTaper(p, N - u * .05, H - hy * .06, .042, .034);
  float flesh = smin(rib, abdo, .06);
  flesh = smin(flesh, pel, .05);
  flesh = smin(flesh, neck, .03);
  // vertebrae ridge down the back
  vec3 vq = bq - vec3(0., 0., -.105);
  float vy = clamp(vq.y, -.5, .15);
  vq.y = mod(vq.y + .0225, .045) - .0225;
  float vert = max(sdSphere(vq * vec3(1., 1.3, 1.), .017), abs(vy - bq.y) - .02);
  flesh = smin(flesh, vert, .012);
  // shoulder blades
  flesh = smin(flesh, sdEllipsoid(vec3(abs(bq.x) - .08, bq.y - .06, bq.z + .08), vec3(.05, .07, .02)), .02);

  // chest split open like a second mouth
  vec3 wq = bq - vec3(0., -.09, .1);
  float wound = sdEllipsoid(wq, vec3(.06 + .03 * run + .015 * spasm, .23, .085));
  flesh = smax(flesh, -wound, .015);
  // ribs torn outward, pointing forward like teeth (mirror + repeat)
  vec3 rq = vec3(abs(bq.x), bq.y + .09, bq.z);
  float ryc = clamp(floor(rq.y / .06 + .5), -3., 3.);
  rq.y -= ryc * .06;
  float spread = .05 + .03 * run;
  float ribs = sdTaper(rq, vec3(spread + .04, 0., .03), vec3(spread - .005, .015, .14 - .012 * abs(ryc)), .008, .002);

  // tendrils of the lake organism writhing out of the wound
  float tend = 1e5;
  // (loops with a data-dependent trip count are genuinely skipped by SwiftShader; ifs are not)
  int nTend = length(bq) < .7 ? 4 : 0;
  {
    for (int k = 0; k < nTend; k++){
      float fk = float(k);
      vec3 a = vec3((hash11(sd + fk) - .5) * .06, -.2 + fk * .1, .06);
      float len = .1 + .12 * run + .06 * hash11(sd + fk * 3.);
      vec3 prev = a;
      for (int j = 1; j < 5; j++){
        float fj = float(j) / 4.;
        vec3 nxt = a + vec3(sin(t * 3.1 + fk * 2. + fj * 4.) * .06 * fj, (hash11(fk + 9.) - .5) * .15 * fj + sin(t * 2.3 + fk + fj * 5.) * .04 * fj, len * fj);
        tend = min(tend, sdTaper(bq, prev, nxt, .008 * (1. - fj * .7) + .003, .008 * (1. - fj * .9) + .0015));
        prev = nxt;
      }
    }
  }

  // ---------------- head: long skull, eye sockets, jaw unhinged far too low
  float jawDrop = .07 + .07 * run + .03 * spasm;
  // detail only when the sample is near the head; otherwise a conservative bound
  float head, mouth, eyes, teeth;
  float hb = length(hq - vec3(0., -.07, .02)) - .21;
  head = hb; mouth = 1.; eyes = hb; teeth = hb;
  int nHead = hb > .03 ? 0 : 1;
  for (int hk = 0; hk < nHead; hk++){
    float skull = sdEllipsoid(hq - vec3(0., .025, -.015), vec3(.072, .095, .09));
    // brow ridge, cheekbones, sunken temples, narrow chin
    skull = smin(skull, sdCapsule(hq, vec3(-.04, .042, .072), vec3(.04, .042, .072), .008), .02);
    skull = smin(skull, sdEllipsoid(vec3(abs(hq.x) - .046, hq.y + .008, hq.z - .045), vec3(.013, .009, .022)), .012);
    skull = smax(skull, -sdSphere(vec3(abs(hq.x) - .085, hq.y - .03, hq.z - .03), .03), .02);
    vec3 jq = hq - vec3(0., -.06 - jawDrop * .55, .035);
    float jaw = sdEllipsoid(jq, vec3(.048, .028 + jawDrop * .5, .052));
    mouth = sdEllipsoid(hq - vec3(0., -.062 - jawDrop * .45, .07), vec3(.036, .018 + jawDrop * .48, .05));
    head = smin(skull, jaw, .02);
    head = smax(head, -mouth, .005);
    vec3 eq = vec3(abs(hq.x) - .031, hq.y - .016, hq.z - .066);
    head = smax(head, -sdSphere(eq, .024), .005);
    head = smax(head, -sdEllipsoid(hq - vec3(0., -.018, .088), vec3(.011, .017, .02)), .004);   // nasal cavity
    // cheek tears
    head = smax(head, -sdEllipsoid(vec3(abs(hq.x) - .042, hq.y + .045, hq.z - .05), vec3(.008, .04, .03)), .004);
    eyes = sdSphere(eq + vec3(0., 0., .012), .0045);   // tiny milky pupils deep in the sockets
    // teeth: inward-pointing spikes lining the mouth cavity, clipped to the head volume
    vec3 tq = hq - vec3(0., -.062 - jawDrop * .45, .07);
    vec2 trad = vec2(.036, .018 + jawDrop * .48);
    float tr = length(tq.xy / trad);
    float ta = atan(tq.x, tq.y);
    float rin = .72 + .22 * abs(sin(ta * 9.));
    teeth = max(rin - tr, tr - 1.05) * min(trad.x, trad.y);
    teeth = max(teeth, smin(skull, jaw, .02) + .002);
    teeth = max(teeth, abs(tq.z + .01) - .03);
  }

  flesh = smin(flesh, head, .02);

  // ---------------- limbs
  float limbs = 1e5, cloth = 1e5, claws = 1e5, sleeves = 1e5, pants = 1e5;
  for (int s = 0; s < 2; s++){
    float sg = s == 0 ? -1. : 1.;
    float aph = ph + (s == 0 ? 0. : PI);
    // arm
    vec3 S = C + x * sg * .18 + u * (.06 - .04 * sg * (hash11(sd + 5.) - .5));
    vec3 idleT = S + vec3(0., -.7, 0.) + f * .1 + x * sg * .06 + vec3(0., 0., .06 * sin(t * .9 + sd + sg)) + vec3(.04, .08, .04) * jerk * sg;
    vec3 runT = S + f * (.35 + .2 * sin(aph)) + vec3(0., -.2 + .15 * sin(aph), .15) + x * sg * .08;
    vec3 T = mix(idleT, runT, run);
    vec3 E = ikJoint(S, T, .33, .42, -f + x * sg * .6 + vec3(0., -.3, 0.));
    vec3 W = E + normalize(T - E) * .42;
    limbs = min(limbs, sdTaper(p, S, E, .042, .032));
    limbs = min(limbs, sdTaper(p, E, W, .032, .022));
    sleeves = min(sleeves, sdTaper(p, S - u * .02, mix(E, W, .35), .055, .045));
    // hand and long curled fingers/claws
    vec3 hd = normalize(W - E);
    vec3 side = normalize(cross(hd, f) + 1e-4);
    vec3 palm = W + hd * .07;
    limbs = min(limbs, sdTaper(p, W, palm, .026, .02));
    int nClaw = length(p - palm) < .3 ? 3 : 0;
    for (int k = 0; k < nClaw; k++){
      float kk = float(k) - 1.;
      vec3 k1 = palm + hd * .07 + side * kk * .025;
      vec3 k2 = k1 + normalize(hd + f * .7 * (1. - run) - u * .2) * .11;
      limbs = min(limbs, sdTaper(p, palm, k1, .011, .009));
      claws = min(claws, sdTaper(p, k1, k2, .008, .001));
    }
    // leg
    float lph = ph + (s == 0 ? 0. : PI);
    vec3 Hp = P + x * sg * .1 - u * .05;
    float stride = mix(.1, .42, run);
    float lift = max(0., cos(lph)) * mix(.03, .22, run);
    vec3 F = vec3(sg * (.15 + .04 * hash11(sd + sg)), .08 + lift, sin(lph) * stride + .05 * run);
    vec3 K = ikJoint(Hp, F, .46, .45, f + x * sg * (.3 - .5 * hash11(sd + 7. + sg)));
    pants = min(pants, sdTaper(p, Hp, K, .072, .055));
    pants = min(pants, sdTaper(p, K, F, .052, .043));
    pants = min(pants, sdRoundBox(p - F - vec3(0., -.03, .06), vec3(.045, .035, .11), .03));
  }
  flesh = smin(flesh, limbs, .025);

  // ---------------- garment
  float gbody = smin(sdEllipsoid(bq - vec3(0., -.03, -.01), vec3(.175, .235, .13)),
                     sdTaper(p, P + u * .15, P - vec3(0., jacket > .5 ? .12 : .5, 0.) + f * .05, .15, jacket > .5 ? .16 : .2), .06);
  float shell = abs(gbody) - .01;
  float gap = .075 + .12 * smoothstep(.05, -.4, bq.y);
  shell = max(shell, -max(abs(bq.x) - gap, -bq.z));                      // open at the front
  shell = max(shell, bq.y - .2);                                          // collar line
  float hem = dot(p - P, vec3(0., 1., 0.)) + (jacket > .5 ? .12 : .48) + .05 * sin(p.x * 23. + sd) + .03 * sin(p.z * 37.);
  shell = max(shell, -hem);                                               // ragged hem
  shell = max(shell, -sdEllipsoid(bq - vec3(.05, -.25, -.12), vec3(.05, .07, .05)));  // torn hole
  cloth = min(cloth, shell);
  cloth = min(cloth, sleeves);
  if (jacket > .5) cloth += .004 * abs(sin(bq.y * 70.));                  // quilted telogreika

  // skin surface detail (only near the surface)
  if (flesh < .03) flesh += (noise3(p * 32.) - .5) * .006 + (noise3(p * 90.) - .5) * .0015;

  flesh = smin(flesh, tend, .015);
  vec2 res = vec2(flesh, abs(wound) < .02 || abs(mouth) < .01 || tend < .004 ? M_GORE : M_SKIN);
  res = opU(res, vec2(cloth, M_CLOTH + .5 * jacket));
  res = opU(res, vec2(pants, M_CLOTH + .5));
  res = opU(res, vec2(min(min(ribs, teeth), min(claws, eyes)), M_BONE));
  return res;
}

// Shading helper for monster materials.
vec3 monsterAlbedo(float m, vec3 p){
  if (m == M_SKIN)  return skinColor(p) * vec3(.36, .37, .37);
  if (m >= M_CLOTH && m < M_GORE){
    float dirt = smoothstep(.4, .75, fbm3lo(p * 5.));
    float blood = smoothstep(.48, .66, noise3(p * 3. + 9.)) + .6 * smoothstep(.62, .7, noise3(p * 11. + 2.));
    vec3 base = m > M_CLOTH ? vec3(.07, .075, .06) : vec3(.36, .35, .31);  // telogreika vs lab coat
    base = mix(base, vec3(.12, .09, .07), dirt * .8);
    base *= .75 + .25 * noise3(p * 40.);                                  // fabric grime
    return mix(base, vec3(.12, .012, .012), clamp(blood, 0., 1.));
  }
  if (m == M_GORE)  return goreColor(p);
  if (m == M_BONE)  return vec3(.55, .5, .4);
  return vec3(.5);
}
float monsterSpec(float m){ return m == M_GORE ? 1. : (m == M_SKIN ? .3 : (m == M_BONE ? .4 : .04)); }

// ---------------------------------------------------------------- KS-23 -----
// Soviet 23mm pump-action carbine (KS-23, 1985). Local frame: barrel along +Z (muzzle at z~.62),
// Y up, receiver around origin, stock extends to -Z. Scale: meters. pump: 0 = forward, 1 = racked back.
vec2 sdKS23(vec3 p, float pump){
  vec2 r = vec2(1e5, M_GUNMETAL);
  // barrel (thick 23mm bore)
  float barrel = sdCylZ(p - vec3(0., .02, .37), .019, .26);
  barrel = max(barrel, -sdCylZ(p - vec3(0., .02, .6), .0115, .1));          // bore
  r = opU(r, vec2(barrel, M_GUNMETAL));
  // front sight + muzzle band
  r = opU(r, vec2(sdBox(p - vec3(0., .045, .6), vec3(.003, .01, .006)), M_GUNMETAL));
  r = opU(r, vec2(sdCylZ(p - vec3(0., .005, .6), .026, .012), M_GUNMETAL));
  // magazine tube under barrel
  r = opU(r, vec2(sdCylZ(p - vec3(0., -.024, .3), .016, .2), M_GUNMETAL));
  // pump forend (wood, ribbed)
  float fz = .26 - .09 * pump;
  float fe = sdRoundBox(p - vec3(0., -.02, fz), vec3(.028, .024, .085), .014);
  fe += .0015 * sin(p.z * 180.) * step(abs(p.y + .02), .02);
  r = opU(r, vec2(fe, M_WOOD));
  // receiver
  float rc = sdRoundBox(p - vec3(0., .005, .02), vec3(.024, .045, .11), .006);
  rc = smax(rc, -sdBox(p - vec3(.024, .02, .03), vec3(.006, .014, .05)), .002);  // ejection port
  r = opU(r, vec2(rc, M_GUNMETAL));
  // trigger guard + trigger
  r = opU(r, vec2(max(sdTorus((p - vec3(0., -.055, -.03)).xzy, vec2(.025, .004)), -(p.y + .045)), M_GUNMETAL));
  r = opU(r, vec2(sdCapsule(p, vec3(0., -.04, -.025), vec3(0., -.065, -.035), .003), M_GUNMETAL));
  // wooden stock with semi-pistol grip, dropping downward
  vec3 sq = p - vec3(0., -.03, -.1);
  sq.yz *= rot2(-.18);
  float stock = sdRoundBox(sq - vec3(0., -.02, -.22), vec3(.02 + .008 * clamp(-sq.z * 2., 0., 1.), .035 + .045 * clamp(-sq.z * 2.5, 0., 1.), .22), .015);
  float grip = sdRoundBox(rotX(p - vec3(0., -.08, -.1), .5), vec3(.018, .05, .025), .012);
  r = opU(r, vec2(smin(stock, grip, .03), M_WOOD));
  // rubber buttpad
  r = opU(r, vec2(sdRoundBox(sq - vec3(0., -.03, -.445), vec3(.024, .08, .008), .006), M_GUNMETAL));
  return r;
}
vec3 gunAlbedo(float m, vec3 p){
  if (m == M_WOOD) return mix(vec3(.28, .12, .05), vec3(.45, .22, .09), .5 + .5 * sin(p.z * 120. + 8. * noise3(p * 40.))) * .8;
  return vec3(.07, .075, .08) * (.8 + .4 * noise3(p * 200.));
}

// ---------------------------------------------------------------- misc ------
// Stars for polar night sky (dir = view direction). Returns intensity.
float stars(vec3 dir){
  vec3 q = dir * 300.;
  vec3 id = floor(q); vec3 f = fract(q) - .5;
  float h = hash31(id);
  float s = smoothstep(.12, .0, length(f)) * step(.985, h) * (h - .985) * 60.;
  return s;
}
// Aurora australis band (dir = view direction). Returns rgb.
vec3 aurora(vec3 dir, float t){
  if (dir.y < 0.02) return vec3(0.);
  vec3 col = vec3(0.);
  for (int i = 0; i < 24; i++){
    float fi = float(i);
    float h = .6 + fi * .06;
    vec2 pp = dir.xz / dir.y * h;
    float n = fbm2(pp * .35 + vec2(t * .02, fi * .02));
    float band = smoothstep(.0, .4, n) * smoothstep(.9, .4, n);
    float curtain = pow(max(0., 1. - abs(sin(pp.x * .4 + n * 4. + t * .05))), 3.);
    vec3 c = mix(vec3(.1, 1., .45), vec3(.7, .1, .9), fi / 24.);
    col += c * band * curtain * .03 * exp(-fi * .08);
  }
  return col * smoothstep(.02, .25, dir.y);
}
