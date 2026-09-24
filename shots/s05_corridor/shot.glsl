// s05_corridor — long dead corridor, fluorescent tubes, the figure that gets closer every blackout.
// uP: 0 tube level, 1 monster z, 2 facing (0 away .. 1 toward camera), 3 run, 4 camera z,
//     5 flashlight level, 6 scare flag, 7 monster animation time

#define W_HALF 1.2
#define CEIL 2.6
#define FIX_SPACING 4.0

#define MW_WALL 30.
#define MW_FLOOR 31.
#define MW_CEIL 32.
#define MW_FIX 33.
#define MW_TUBE 34.
#define MW_DOOR 35.
#define MW_PIPE 36.
#define MW_CHAIR 37.

vec3 gCam, gFlashPos, gFlashDir;
float gMonZ;

// per-fixture state: 0 dead, 1 alive, 2 faulty
float fixtureState(float k){
  if (k < 0. || k > 9.) return 0.;
  float h = hash11(k * 7.13 + 3.);
  if (k == 6.) return 1.;              // the one lighting the figure at 26 m
  if (k == 2.) return 2.;
  return h < .45 ? 0. : 1.;
}
float fixtureI(float k){
  float s = fixtureState(k);
  float lv = uP[0];
  if (s == 0.) return 0.;
  if (s == 2.) return lv * step(.35, noise2(vec2(iTime * 11., k))) * .8;
  return lv;
}
float fixZ(float k){ return 2. + FIX_SPACING * k; }

// ---------------------------------------------------------------- scene
vec2 corridor(vec3 p){
  // hollow box
  vec2 r = vec2(W_HALF - abs(p.x), MW_WALL);
  r = opU(r, vec2(p.y, MW_FLOOR));
  r = opU(r, vec2(CEIL - p.y, MW_CEIL));
  // pilasters every 4 m
  float pz = mod(p.z, 4.) - 2.;
  r = opU(r, vec2(sdBox(vec3(abs(p.x) - W_HALF, p.y - 1.3, pz), vec3(.09, 1.3, .14)), MW_WALL));
  // doors: recessed frames every 6 m, alternating sides
  float dz = mod(p.z + 1., 6.) - 3.;
  float side = mod(floor((p.z + 1.) / 6.), 2.) < .5 ? -1. : 1.;
  if (p.x * side > 0.){
    float frame = sdBox(vec3(abs(p.x) - W_HALF, p.y - 1.05, dz), vec3(.05, 1.1, .55));
    float recess = sdBox(vec3(abs(p.x) - W_HALF - .07, p.y - 1.02, dz), vec3(.1, 1.02, .45));
    r = opU(r, vec2(max(frame, -recess), MW_DOOR));
    r = opU(r, vec2(sdBox(vec3(abs(p.x) - W_HALF - .1, p.y - 1.02, dz), vec3(.02, 1.02, .45)), MW_DOOR));
  }
  // ceiling: cable tray on the left, two pipes on the right
  r = opU(r, vec2(sdBox(vec3(p.x + .8, p.y - 2.45, 0.), vec3(.22, .025, 1e3)), MW_PIPE));
  r = opU(r, vec2(length(vec2(p.x - .85, p.y - 2.42)) - .07, MW_PIPE));
  r = opU(r, vec2(length(vec2(p.x - .62, p.y - 2.48)) - .045, MW_PIPE));
  // light fixtures (housing + tube)
  float k = clamp(floor((p.z - 2.) / FIX_SPACING + .5), 0., 9.);
  vec3 fq = p - vec3(0., 2.47, fixZ(k));
  r = opU(r, vec2(sdBox(fq, vec3(.12, .04, .65)), MW_FIX));
  r = opU(r, vec2(sdCapsule(fq, vec3(0., -.06, -.6), vec3(0., -.06, .6), .022), MW_TUBE + k * .01));
  // toppled chair at z = 7.5, left side
  vec3 cq = p - vec3(-.55, .22, 7.5);
  cq.xy *= rot2(1.35); cq.xz *= rot2(.4);
  if (length(cq) < .8){
    float ch = sdBox(cq - vec3(0., .2, 0.), vec3(.22, .02, .22));
    ch = min(ch, sdBox(cq - vec3(0., .45, -.2), vec3(.22, .22, .02)));
    vec3 lq = vec3(abs(cq.x) - .19, cq.y, abs(cq.z) - .19);
    ch = min(ch, sdBox(lq, vec3(.015, .22, .015)));
    r = opU(r, vec2(ch, MW_CHAIR));
  }
  return r;
}

vec2 monsterMap(vec3 p){
  vec3 mp = p - vec3(.15, 0., gMonZ);
  // facing: 1 -> faces -z (toward camera), 0 -> faces +z, rotated to be half turned
  float yaw = mix(.6, PI, uP[2]);
  mp.xz *= rot2(yaw);
  // rear up: straighten the spine about the hips so the head comes up to face height
  vec3 hip = vec3(0., .9, 0.);
  mp = hip + rotX(mp - hip, -uP[8]);
  float b = sdCapsule(mp, vec3(0., .2, 0.), vec3(0., 2., 0.), 1.);
  if (b > .25) return vec2(b, 0.);
  return sdMonster(mp, uP[7], .31, uP[3]);
}

vec2 map(vec3 p){
  vec2 r = corridor(p);
  r = opU(r, monsterMap(p));
  return r;
}

vec3 calcNormal(vec3 p){
  const vec2 k = vec2(1., -1.); const float e = .0012;
  return normalize(k.xyy * map(p + k.xyy * e).x + k.yyx * map(p + k.yyx * e).x + k.yxy * map(p + k.yxy * e).x + k.xxx * map(p + k.xxx * e).x);
}
float calcAO(vec3 p, vec3 n){
  float o = 0., s = 1.;
  for (int i = 0; i < 3; i++){ float h = .03 + .1 * float(i); o += (h - map(p + n * h).x) * s; s *= .7; }
  return clamp(1. - 2.5 * o, 0., 1.);
}

// ---------------------------------------------------------------- materials
vec3 albedo(float m, vec3 p, vec3 n, out float rough){
  rough = .7;
  if (m == MW_WALL){
    float fn = fbm3lo(p * vec3(2., 3., 2.));
    vec3 cream = mix(vec3(.32, .30, .25), vec3(.22, .21, .17), fn);
    vec3 green = mix(vec3(.07, .11, .09), vec3(.05, .075, .065), fn);
    vec3 c = mix(green, cream, smoothstep(1.28, 1.3, p.y));
    c *= 1. - .55 * smoothstep(.025, 0., abs(p.y - 1.29));
    // grime rising from the floor, water stains running down
    c *= mix(.45, 1., smoothstep(0., .5, p.y));
    c *= 1. - .35 * smoothstep(.55, .8, fbm2(vec2(p.z * 3., p.y * .4)));
    // frost crust on the lower wall
    float fr = smoothstep(.52, .72, fbm3lo(p * 3.1 + 2.)) * (1. - smoothstep(.2, 1.1, p.y));
    c = mix(c, vec3(.55, .62, .7), fr * .8);
    rough = mix(.8, .25, fr);
    // posters / signs (atlas)
    if (p.x < 0. && abs(p.z - 5.2) < .42 && abs(p.y - 1.6) < .42){
      vec4 tx = texture(iTex0, vec2((p.z - 5.2) / .84 * .5 * -1. + .25, (p.y - 1.6) / .84 + .5));
      c = mix(c, tx.rgb * .8, tx.a);
    }
    if (p.x > 0. && abs(p.z - 13.8) < .9 && abs(p.y - 1.75) < .45){
      vec4 tx = texture(iTex0, vec2((p.z - 13.8) / 1.8 * .5 + .75, (p.y - 1.75) / .9 + .5));
      c = mix(c, tx.rgb * .7, tx.a);
    }
    // bloody handprint smear on the left wall near the drag
    if (p.x < 0. && abs(p.z - 9.4) < .8) c = mix(c, vec3(.13, .012, .012), bloodSplat(vec2(p.z - 9.3, p.y - 1.1), 3.7) * .9);
    return c;
  }
  if (m == MW_FLOOR){
    vec2 tq = p.xz / .5;
    float tile = step(.5, fract((floor(tq.x) + floor(tq.y)) * .5));
    vec3 c = mix(vec3(.05, .05, .048), vec3(.07, .065, .058), tile) * (.7 + .5 * fbm2(p.xz * 2.));
    float fr = smoothstep(.55, .75, fbm2(p.xz * 1.3 + 4.));
    c = mix(c, vec3(.5, .56, .62), fr * .6);
    rough = mix(.5, .2, fr);
    // blood drag: from the middle of the floor into the right-hand door at z ~ 11
    float along = clamp((p.z - 7.8) / 3.4, 0., 1.);
    float cx = mix(-.1, 1.15, along * along);
    float drag = smoothstep(.2, .05, abs(p.x - cx) + (fbm2(p.xz * 9.) - .5) * .14) * step(7.8, p.z) * step(p.z, 11.3);
    drag *= .6 + .4 * noise2(p.xz * 30.);
    float pool = bloodSplat(p.xz - vec2(-.2, 7.6), 1.9);
    c = mix(c, vec3(.1, .008, .008), max(drag, pool) * .95);
    rough = mix(rough, .08, max(drag, pool));
    // papers scattered
    vec2 pp = p.xz * vec2(2.2, 1.3);
    vec2 pid = floor(pp);
    if (hash21(pid) > .86){
      vec2 f = fract(pp) - .5;
      f *= rot2(hash21(pid + 3.) * 3.);
      if (abs(f.x) < .2 && abs(f.y) < .26) c = vec3(.45, .43, .38) * (.7 + .3 * noise2(p.xz * 40.));
    }
    return c;
  }
  if (m == MW_CEIL) return vec3(.05, .05, .05) * (.7 + .5 * fbm2(p.xz));
  if (m == MW_FIX) return vec3(.12, .12, .11);
  if (m == MW_DOOR){ rough = .5; return mix(vec3(.05, .08, .065), vec3(.09, .1, .09), fbm3lo(p * 6.)) * (1. - .5 * smoothstep(.6, .8, fbm3lo(p * 14.))); }
  if (m == MW_PIPE){ rough = .45; return vec3(.08, .08, .075) * (.7 + .6 * fbm3lo(p * 8.)); }
  if (m == MW_CHAIR){ rough = .5; return vec3(.1, .06, .04); }
  if (m <= 4.){ rough = m == M_GORE ? .1 : .55; return monsterAlbedo(m, p); }
  return vec3(.2);
}

// ---------------------------------------------------------------- lighting
vec3 tubeLight(vec3 p, vec3 n, vec3 v, float rough, out vec3 specOut){
  vec3 dif = vec3(0.); specOut = vec3(0.);
  float k0 = floor((p.z - 2.) / FIX_SPACING + .5);
  for (int j = -1; j <= 1; j++){
    float k = k0 + float(j);
    float I = fixtureI(k);
    if (I <= 0.) continue;
    vec3 a = vec3(0., 2.4, fixZ(k) - .6), b = vec3(0., 2.4, fixZ(k) + .6);
    vec3 ba = b - a;
    float hq = clamp(dot(p - a, ba) / dot(ba, ba), 0., 1.);
    vec3 L = a + ba * hq - p; float d = length(L); L /= d;
    float att = I / (1. + d * d * 1.1) * smoothstep(-.2, .25, L.y);
    vec3 col = vec3(.78, .92, 1.) * 1.3;
    dif += col * att * max(dot(n, L), 0.);
    vec3 h = normalize(L + v);
    specOut += col * att * pow(max(dot(n, h), 0.), mix(120., 12., rough)) * (1. - rough);
  }
  return dif;
}
vec3 flashLight(vec3 p, vec3 n, vec3 v, float rough, out vec3 specOut){
  vec3 L = gFlashPos - p; float d = length(L); L /= d;
  float s = spotLight(p, gFlashPos, gFlashDir, .9, .975) * mix(1., flashCookie(p, gFlashPos, gFlashDir), .5) * uP[5] * 2.4;
  vec3 col = vec3(1., .96, .88);
  vec3 h = normalize(L + v);
  specOut = col * s * pow(max(dot(n, h), 0.), mix(90., 10., rough)) * (1. - rough) * 1.5;
  return col * s * max(dot(n, L), 0.);
}

vec3 render(vec2 fc){
  float t = iTime;
  gMonZ = uP[1];
  float cz = uP[4];
  float scare = uP[6];
  vec3 ro = vec3(.05 * sin(t * .9) + .02 * noise2(vec2(t * 2., 1.)), 1.62 + .02 * sin(t * 4.4), cz);
  vec3 ta = ro + vec3(.06 * (noise2(vec2(t * .7, 3.)) - .5), -.03 + .05 * (noise2(vec2(t * .6, 7.)) - .5), 1.);
  if (scare > .5){ ro.z -= .05; ta = vec3(.08, 1.66, gMonZ - .2); }
  gCam = ro;
  vec3 rd = camRay(fc, ro, ta, 1.45, .02 * sin(t * .5));
  vec3 fw = normalize(ta - ro);
  vec3 rt = normalize(cross(vec3(0., 1., 0.), fw));
  gFlashPos = ro + rt * .18 - vec3(0., .28, 0.) + fw * .1;
  vec3 aim = ro + fw * 6. + vec3(.25 * (noise2(vec2(t * .9, 11.)) - .5), -.35 + .15 * (noise2(vec2(t * .8, 13.)) - .5), 0.);
  if (scare > .5) aim = vec3(.08, 1.62, gMonZ - .2);
  gFlashDir = normalize(aim - gFlashPos);

  // march
  float d = 0.; vec2 h = vec2(0.);
  bool hit = false;
  for (int i = 0; i < 110; i++){
    h = map(ro + rd * d);
    if (h.x < .001 * (1. + d)){ hit = true; break; }
    d += h.x * .9;
    if (d > 45.) break;
  }
  vec3 col = vec3(0.);
  if (hit){
    vec3 p = ro + rd * d;
    vec3 n = calcNormal(p);
    vec3 v = -rd;
    float rough;
    vec3 alb = albedo(h.y, p, n, rough);
    if (h.y >= MW_TUBE && h.y < MW_TUBE + .5){
      float k = floor((h.y - MW_TUBE) * 100. + .5);
      col = vec3(.8, .95, 1.) * fixtureI(k) * 9. + vec3(.03);
    } else {
      vec3 s1, s2;
      vec3 dl = tubeLight(p, n, v, rough, s1) + flashLight(p, n, v, rough, s2);
      float ao = calcAO(p, n);
      col = alb * (dl + vec3(.004, .005, .007)) * mix(.3, 1., ao) + (s1 + s2) * ao;
      // monster: faint wet sheen and subsurface-ish rim from the tubes behind
      if (h.y <= 4.){
        float fres = pow(1. - max(dot(n, v), 0.), 3.);
        col += fres * (s1 + s2) * .5;
      }
    }
  }
  // volumetric: cold haze lit by the tubes and the torch (dithered, 7 samples)
  float dith = hash21(fc + fract(t) * 17.);
  vec3 fog = vec3(0.);
  float maxD = min(hit ? d : 45., 34.);
  for (int i = 0; i < 7; i++){
    float s = (float(i) + dith) / 7.;
    s = s * s * maxD;
    vec3 q = ro + rd * s;
    float k = floor((q.z - 2.) / FIX_SPACING + .5);
    float I = fixtureI(k);
    vec3 fp = vec3(0., 2.35, fixZ(k));
    vec3 dq = q - fp;
    float tube = I / (1. + dot(dq * vec3(1., 1., .55), dq * vec3(1., 1., .55)) * 2.2) * smoothstep(.1, -.4, dq.y);
    float torch = spotLight(q, gFlashPos, gFlashDir, .9, .975) * uP[5];
    float dens = .55 + .45 * noise3(q * .8 + vec3(0., 0., t * .15));
    fog += (vec3(.6, .75, .9) * tube * .5 + vec3(1., .96, .9) * torch * .9) * dens;
  }
  col += fog * maxD / 7. * .018;
  return col;
}
