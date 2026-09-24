// s04_airlock — the airlock, the blast door, the slam.
// World: entrance wall is the plane z = 0 (concrete, 0.6 m thick toward -z); doorway x in [-.8,.8], y in [0,2.1].
// Outside (z < -.6): a snow trench under the aurora. Camera inside at z ~ 4.3 looking back toward -z.
// uP: 0 door open (1 open .. 0 closed), 1-3 bolts, 4 bulkhead lamp, 5 beacon, 6 time since slam (-1 before), 7 t

#define MA_CONC 60.
#define MA_FLOOR 61.
#define MA_DOOR 62.
#define MA_METAL 63.
#define MA_SNOW 64.
#define MA_PARKA 65.
#define MA_FUR 66.
#define MA_LAMP 67.
#define MA_BEACON 68.
#define MA_PIPE 69.

const vec3 HINGE = vec3(.8, 0., .02);        // hinge on the +x jamb (screen-left)
vec3 gFl1p, gFl1d, gFl2p, gFl2d;

// ---------------------------------------------------------------- door (local: hinge at origin, slab toward -x)
vec2 sdDoor(vec3 q){
  // slab 1.62 x 2.12 x .26, rounded
  vec3 c = q - vec3(-.81, 1.06, .0);
  float slab = sdRoundBox(c, vec3(.8, 1.05, .12), .06);
  if (slab > .4) return vec2(slab, MA_DOOR);
  // raised rim frame on the inner face (+z side)
  float rim = max(sdRoundBox(c - vec3(0., 0., .13), vec3(.74, .99, .03), .03), -sdRoundBox(c - vec3(0., 0., .13), vec3(.64, .89, .06), .02));
  vec2 r = vec2(min(slab, rim), MA_DOOR);
  // stiffener ribs (horizontal)
  vec3 rq = c; rq.y = mod(rq.y + .3, .6) - .3;
  r = opU(r, vec2(sdBox(rq - vec3(0., 0., .14), vec3(.62, .025, .025)), MA_DOOR));
  // central wheel with spokes
  vec3 wq = c - vec3(-.05, .05, .27);
  float wheel = sdTorus(wq.xzy, vec2(.24, .032));
  float ang = atan(wq.y, wq.x);
  float sector = mod(ang + PI / 6., PI / 3.) - PI / 6.;
  vec2 sp = length(wq.xy) * vec2(cos(sector), sin(sector));
  wheel = min(wheel, max(sdBox(vec3(sp.x - .12, sp.y, wq.z), vec3(.12, .022, .022)), -1.));
  wheel = min(wheel, sdCylZ(wq, .05, .03));
  wheel = min(wheel, sdCylZ(wq + vec3(0., 0., .13), .03, .12));    // spindle
  r = opU(r, vec2(wheel, MA_METAL));
  // locking dogs on the free edge (slide out along -x when bolted)
  for (int i = 0; i < 3; i++){
    float fi = float(i);
    float out1 = uP[1 + i] * .16;
    vec3 dq = q - vec3(-1.62 - out1 + .08, .45 + fi * .6, .04);
    r = opU(r, vec2(sdRoundBox(dq, vec3(.1, .045, .045), .01), MA_METAL));
  }
  // hinge knuckles
  for (int i = 0; i < 2; i++){
    vec3 hq = q - vec3(.02, .4 + float(i) * 1.3, .0);
    r = opU(r, vec2(sdCylY(hq, .07, .17), MA_METAL));
  }
  return r;
}

// parka survivor silhouette (foreground right), facing the door
vec2 sdSurvivor(vec3 p){
  vec3 q = p - vec3(-.55, 0., 2.9);
  float b = sdCapsule(q, vec3(0., .2, 0.), vec3(0., 1.7, 0.), .55);
  if (b > .3) return vec2(b, MA_PARKA);
  float sway = .03 * sin(uP[7] * 1.3);
  float torso = sdRoundBox(q - vec3(sway, 1.18, 0.), vec3(.23, .3, .14), .11);
  torso = smin(torso, sdTaper(q, vec3(sway * .5, .8, 0.), vec3(sway, 1.1, 0.), .2, .22), .08);   // parka skirt
  float legs = min(sdTaper(q, vec3(.1, .8, 0.), vec3(.13, .06, .03), .1, .08), sdTaper(q, vec3(-.1, .8, 0.), vec3(-.14, .06, -.05), .1, .08));
  float body = smin(torso, legs, .04);
  float hood = sdSphere(q - vec3(sway * 1.3, 1.64, .02), .15);
  float fur = sdTorus((q - vec3(sway * 1.3, 1.64, -.09)).xzy, vec2(.12, .045)) + .006 * sin(atan(q.x, q.y) * 40.);
  // arm raised holding the torch forward (toward -z)
  float arm = sdTaper(q, vec3(.24, 1.36, 0.), vec3(.18, 1.22, -.42), .08, .065);
  vec2 r = vec2(smin(smin(body, hood, .05), arm, .06), MA_PARKA);
  r = opU(r, vec2(fur, MA_FUR));
  r = opU(r, vec2(sdCylZ(q - vec3(.17, 1.22, -.55), .035, .1), MA_METAL));      // torch body
  return r;
}

vec2 map(vec3 p){
  // interior room: x in [-1.9, 1.9], y in [0, 3.0], z in [0, 7]
  vec2 r = vec2(p.y, MA_FLOOR);
  r = opU(r, vec2(3. - p.y, MA_CONC));
  r = opU(r, vec2(1.9 - abs(p.x), MA_CONC));
  // entrance wall with the doorway (wall occupies z in [-.6, 0])
  float wall = sdBox(p - vec3(0., 1.5, -.3), vec3(3., 1.6, .3));
  float hole = sdBox(p - vec3(0., 1.05, -.3), vec3(.8, 1.05, .5));
  wall = max(wall, -hole);
  r = opU(r, vec2(wall, MA_CONC));
  // heavy steel frame around the doorway, proud of the wall
  float frame = max(sdBox(p - vec3(0., 1.1, .05), vec3(.98, 1.25, .07)), -sdBox(p - vec3(0., 1.05, .05), vec3(.8, 1.05, .2)));
  r = opU(r, vec2(frame, MA_METAL));
  // pipes along the right wall and ceiling
  r = opU(r, vec2(length(vec2(p.x + 1.75, p.y - 2.7)) - .08, MA_PIPE));
  r = opU(r, vec2(length(vec2(p.x + 1.55, p.y - 2.82)) - .05, MA_PIPE));
  r = opU(r, vec2(length(vec2(p.x - 1.78, p.z - 1.2)) - .06, MA_PIPE));
  // caged bulkhead lamp above the door, red beacon beside it
  r = opU(r, vec2(sdCylZ(p - vec3(-1.4, 2.55, .09), .1, .08), MA_LAMP));
  r = opU(r, vec2(sdCylY(p - vec3(1.4, 2.6, .12), .07, .08), MA_BEACON));
  // bench along the left wall
  r = opU(r, vec2(sdBox(p - vec3(1.6, .45, 3.), vec3(.22, .04, 1.2)), MA_METAL));
  // the door
  vec3 dq = p - HINGE;
  float ang = uP[0] * 1.5;                   // swings into the room
  dq.xz *= rot2(-ang);
  r = opU(r, sdDoor(dq));
  // outside: trench floor and snow walls
  if (p.z < -.55){
    float sn = p.y + .05 - .25 * smoothstep(-1., -5., p.z) - .08 * fbm2(p.xz * .7);
    sn = min(sn, 2.3 - abs(p.x) + .4 * fbm2(p.yz * .8));
    r = opU(r, vec2(sn, MA_SNOW));
  }
  r = opU(r, sdSurvivor(p));
  return r;
}

vec3 calcNormal(vec3 p){
  const vec2 k = vec2(1., -1.); const float e = .0015;
  return normalize(k.xyy * map(p + k.xyy * e).x + k.yyx * map(p + k.yyx * e).x + k.yxy * map(p + k.yxy * e).x + k.xxx * map(p + k.xxx * e).x);
}
float calcAO(vec3 p, vec3 n){
  float o = 0., s = 1.;
  for (int i = 0; i < 3; i++){ float h = .04 + .12 * float(i); o += (h - map(p + n * h).x) * s; s *= .7; }
  return clamp(1. - 2.2 * o, 0., 1.);
}

vec3 albedo(float m, vec3 p, out float rough){
  rough = .8;
  if (m == MA_CONC){
    float n = fbm3lo(p * 2.5);
    vec3 c = mix(vec3(.2, .2, .19), vec3(.13, .13, .125), n);
    c *= 1. - .4 * smoothstep(.6, .8, fbm2(vec2(p.x * 5. + p.z * 5., p.y * .5)));  // streaks
    float fr = smoothstep(.5, .7, fbm3lo(p * 3. + 5.)) * (1. - smoothstep(.2, 1.5, p.y) + smoothstep(-.1, 0., -p.z) * .6);
    c = mix(c, vec3(.6, .66, .74), clamp(fr, 0., 1.) * .8);
    rough = mix(.85, .3, fr);
    // stencilled sign above the door
    if (p.z > -.05 && abs(p.x) < 1.1 && abs(p.y - 2.62) < .27 && p.z < .01){
      vec4 tx = texture(iTex0, vec2((p.x + 1.1) / 2.2, (p.y - 2.35) / .54));
      c = mix(c, tx.rgb * .6, tx.a);
    }
    return c;
  }
  if (m == MA_FLOOR){
    vec3 c = vec3(.1, .1, .1) * (.6 + .6 * fbm2(p.xz * 2.));
    float ice = smoothstep(.45, .7, fbm2(p.xz * 1.1 + 3.)) + smoothstep(1.5, 0., p.z) * .7;
    c = mix(c, vec3(.55, .62, .7), clamp(ice, 0., 1.) * .7);
    rough = mix(.8, .15, clamp(ice, 0., 1.));
    return c;
  }
  if (m == MA_DOOR){
    float n = fbm3lo(p * 4.);
    vec3 c = mix(vec3(.09, .13, .1), vec3(.06, .085, .07), n);
    c = mix(c, vec3(.2, .09, .04), smoothstep(.62, .78, fbm3lo(p * 9. + 1.)));   // rust
    c = mix(c, vec3(.55, .6, .66), smoothstep(.6, .75, fbm3lo(p * 6. + 7.)) * .5); // frost
    rough = .55; return c;
  }
  if (m == MA_METAL){ rough = .35; return vec3(.08, .08, .085) * (.7 + .6 * fbm3lo(p * 10.)); }
  if (m == MA_PIPE){ rough = .5; return vec3(.1, .09, .08) * (.7 + .6 * fbm3lo(p * 6.)); }
  if (m == MA_SNOW){ rough = .6; return vec3(.75, .8, .88); }
  if (m == MA_PARKA){ rough = .9; return vec3(.03, .035, .03); }
  if (m == MA_FUR){ rough = 1.; return vec3(.12, .1, .08); }
  if (m == MA_LAMP || m == MA_BEACON){ rough = .3; return vec3(.1); }
  return vec3(.2);
}

// light from the open doorway: an area light approximated by 3 points across the opening, cold
vec3 doorwayLight(vec3 p, vec3 n){
  float open = smoothstep(0., .25, uP[0]);
  if (open <= 0.) return vec3(0.);
  vec3 acc = vec3(0.);
  for (int i = 0; i < 3; i++){
    vec3 lp = vec3((float(i) - 1.) * .5, 1.2, -.5);
    vec3 L = lp - p; float d = length(L); L /= d;
    acc += max(dot(n, L), 0.) * max(-L.z, 0.) / (1. + d * d * .7);
  }
  return vec3(.35, .5, .8) * acc * .6 * open;
}
vec3 torch(vec3 p, vec3 n, vec3 v, float rough, vec3 lp, vec3 ld, float I, inout vec3 spec){
  vec3 L = lp - p; float d = length(L); L /= d;
  float s = spotLight(p, lp, ld, .88, .975) * mix(1., flashCookie(p, lp, ld), .25) * I;
  vec3 h = normalize(L + v);
  spec += vec3(1., .95, .85) * s * pow(max(dot(n, h), 0.), mix(90., 10., rough)) * (1. - rough);
  return vec3(1., .95, .85) * s * max(dot(n, L), 0.);
}
vec3 bulkhead(vec3 p, vec3 n){
  vec3 lp = vec3(-1.4, 2.5, .3);
  vec3 L = lp - p; float d = length(L); L /= d;
  return vec3(1., .75, .45) * uP[4] * 2.2 * max(dot(n, L), 0.) / (1. + d * d * .45);
}
vec3 beaconL(vec3 p, vec3 n){
  if (uP[5] <= 0.) return vec3(0.);
  vec3 lp = vec3(1.4, 2.6, .25);
  float a = uP[7] * 5.5;
  vec3 dir = normalize(vec3(cos(a), -.35, sin(a)));
  vec3 L = lp - p; float d = length(L); L /= d;
  float cone = smoothstep(.75, .95, dot(-L, dir));
  float pulse = .5 + .5 * pow(max(0., sin(uP[7] * 5.5)), 2.);
  return vec3(1., .08, .03) * uP[5] * (cone * 7. + .7 * pulse) * max(dot(n, L), 0.) / (1. + d * d * .25);
}

vec3 sky(vec3 rd){
  vec3 c = vec3(.004, .006, .012);
  c += stars(rd) * .8;
  c += aurora(rd, uP[7]) * .9;
  return c;
}

vec3 render(vec2 fc){
  float t = uP[7];
  vec3 ro = vec3(-.15 + .05 * sin(t * .8), 1.75 + .015 * sin(t * 3.7), 6.2 - t * .06);
  vec3 ta = vec3(.05 + .08 * (noise2(vec2(t * .5, 2.)) - .5), 1.55 + .05 * (noise2(vec2(t * .6, 5.)) - .5), 0.);
  vec3 rd = camRay(fc, ro, ta, 1.25, .01 * sin(t * .4));

  // torches: one held by the survivor in frame, one from off-camera left
  float sw = sin(t * .9) * .35 + .15 * sin(t * 2.3);
  gFl1p = vec3(-.38, 1.22, 2.35);
  gFl1d = normalize(vec3(.3 * sw, 1.15 - 1.22 - .1, -2.3) + vec3(0., .05 * sin(t * 1.7), 0.));
  if (t > 6.) gFl1d = normalize(vec3(.1 + .05 * sin(t * 7.), -.1, -1.));
  gFl2p = vec3(1.3, 1.5, 5.4);
  gFl2d = normalize(vec3(-.35 + .9 * sin(t * .6 + 1.), -.12 + .1 * sin(t * .9), -1.));

  float d = 0.; vec2 h = vec2(0.); bool hit = false;
  for (int i = 0; i < 120; i++){
    h = map(ro + rd * d);
    if (h.x < .001 * (1. + d)){ hit = true; break; }
    d += h.x * .9;
    if (d > 30.) break;
  }
  vec3 col;
  if (!hit){
    col = sky(rd);
  } else {
    vec3 p = ro + rd * d, n = calcNormal(p), v = -rd;
    float rough; vec3 alb = albedo(h.y, p, rough);
    if (h.y == MA_SNOW){
      // outside: aurora/starlight on snow, plus torch spill
      vec3 spec = vec3(0.);
      col = alb * (vec3(.05, .09, .1) * (.5 + .5 * n.y) + torch(p, n, v, rough, gFl1p, gFl1d, 1.5, spec)) * (.8 + .2 * fbm2(p.xz * 4.));
    } else {
      vec3 spec = vec3(0.);
      vec3 li = doorwayLight(p, n) + bulkhead(p, n) + beaconL(p, n);
      li += torch(p, n, v, rough, gFl1p, gFl1d, 1.3, spec);
      li += torch(p, n, v, rough, gFl2p, gFl2d, .9, spec);
      float ao = calcAO(p, n);
      col = alb * (li + vec3(.004, .005, .007)) * mix(.3, 1., ao) + spec * ao;
      if (h.y == MA_LAMP) col += vec3(1., .75, .45) * uP[4] * 3.;
      if (h.y == MA_BEACON) col += vec3(1., .1, .04) * uP[5] * (1.5 + 3. * pow(max(0., sin(t * 5.5)), 8.));
    }
  }
  // volumetrics: torch beams, doorway glow, red beacon, snow blowing in
  float dith = hash21(fc + fract(t * 7.) * 31.);
  float maxD = min(hit ? d : 30., 12.);
  vec3 fog = vec3(0.);
  float open = smoothstep(0., .25, uP[0]);
  for (int i = 0; i < 8; i++){
    float s = (float(i) + dith) / 8. * maxD;
    vec3 q = ro + rd * s;
    float dens = .5 + .5 * noise3(q * 1.3 + vec3(t * .6, 0., -t * 1.4));
    fog += vec3(1., .95, .85) * (spotLight(q, gFl1p, gFl1d, .92, .98) * 1.4 + spotLight(q, gFl2p, gFl2d, .92, .98) * 1.2) * dens;
    // cold air and snow pouring through the doorway
    float shaft = open * smoothstep(1.1, .6, abs(q.x)) * smoothstep(2.3, 1.6, q.y) * exp(-max(q.z, 0.) * .6) * step(-.6, q.z);
    fog += vec3(.3, .45, .7) * shaft * dens * .5;
    if (uP[5] > 0.){
      float a = t * 5.5;
      vec3 bdir = normalize(vec3(cos(a), -.35, sin(a)));
      vec3 L = normalize(q - vec3(1.4, 2.6, .25));
      fog += vec3(1., .07, .03) * uP[5] * smoothstep(.8, .97, dot(L, bdir)) * 1.5 / (1. + dot(q, q) * .05) * dens;
    }
    // dust shaken loose by the slam
    if (uP[6] >= 0. && uP[6] < 2.5){
      float dust = smoothstep(1.2, 0., abs(q.x)) * smoothstep(.5, 0., q.z) * (1. - uP[6] / 2.5);
      fog += vec3(.2, .2, .2) * dust * dens;
    }
  }
  col += fog * maxD / 8. * .03;
  // snowflakes streaming in through the open door (screen space streak layers, only while open)
  if (open > 0.){
    vec2 uv = screenUV(fc);
    for (int L = 0; L < 3; L++){
      float fl = float(L);
      vec2 sp = uv * (14. + fl * 10.) + vec2(-t * (1.5 + fl), t * (.4 + fl * .3));
      vec2 id = floor(sp), fr = fract(sp) - .5;
      float hh = hash21(id + fl * 7.);
      if (hh > .8){
        vec2 o = (hash22(id) - .5) * .6;
        col += vec3(.7, .75, .85) * smoothstep(.06, 0., length((fr - o) * vec2(1., 2.5))) * .08 * open * (1. - fl * .25);
      }
    }
  }
  // falling ice and dust particles after the slam
  if (uP[6] >= 0. && uP[6] < 1.8){
    vec2 uv = screenUV(fc);
    vec2 sp = uv * 26. + vec2(0., uP[6] * uP[6] * 18.);
    vec2 id = floor(sp), fr = fract(sp) - .5;
    if (hash21(id) > .9 && abs(uv.x) < .5) col += vec3(.5) * smoothstep(.08, 0., length(fr * vec2(1., .5))) * (1. - uP[6] / 1.8);
  }
  return col;
}
