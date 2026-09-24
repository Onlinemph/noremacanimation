// s10_end (0-15s)
//  0-7s   exterior: Object 9 burning in the distance under aurora, Kharkovchanka receding
//  7-13s  black, then the same green CRT from s01 (code copied verbatim), new decoded lines
//  13-15s hard cut to black, title card (drawn entirely in overlay)

// ============================================================ camera / projection ===
const float FOCAL = 1.55;
vec3 gCamRo, gCamFwd, gCamRight, gCamUp;
void setupCam(){
  gCamRo = vec3(0.0, 1.7, 0.0);
  vec3 ta = vec3(0.0, 2.0, 5.0);
  gCamFwd = normalize(ta - gCamRo);
  gCamRight = normalize(cross(gCamFwd, vec3(0.0, 1.0, 0.0)));
  gCamUp = cross(gCamRight, gCamFwd);
}
// returns (screenUV.x, screenUV.y, camera-space depth)
vec3 projectPoint(vec3 wp){
  vec3 rel = wp - gCamRo;
  float cz = dot(rel, gCamFwd);
  float cx = dot(rel, gCamRight);
  float cy = dot(rel, gCamUp);
  return vec3(vec2(cx, cy) / max(cz, 0.001) * FOCAL, cz);
}

// ============================================================ exterior: fire + smoke ===
float fireFlicker(float t){ return 0.75 + 0.25 * noise2(vec2(t * 9.0, 3.0)) + 0.12 * noise2(vec2(t * 27.0, 7.0)); }

// procedural plume (smoke+fire column) in local coords lp (screen units, origin at base)
vec3 plumeColor(vec2 lp, float t, float flick){
  vec3 col = vec3(0.0);
  float h = clamp(lp.y, 0.0, 3.0);
  // smoke: wide, billowing, tapers as it rises, drifts sideways with altitude
  float drift = h * h * 0.12 + sin(t * 0.2 + h) * 0.05;
  vec2 sp = vec2(lp.x - drift, lp.y * 0.9) ;
  float smokeN = fbm2(sp * vec2(2.2, 1.6) + vec2(t * 0.1, -t * 0.5));
  float width = 0.10 + h * 0.30 + 0.10 * smokeN;
  float smokeMask = smoothstep(width, width * 0.4, abs(lp.x - drift)) * smoothstep(2.6, 0.15, h) * (0.3 + 0.55 * smokeN);
  vec3 smokeCol = mix(vec3(0.10, 0.05, 0.035), vec3(0.03, 0.028, 0.03), smoothstep(0.1, 1.6, h));
  col += smokeCol * smokeMask;
  // fireball glow at the base, orange-white, flickering, small and hot
  float fireN = fbm2(lp * vec2(7.0, 9.0) + vec2(0.0, -t * 2.4));
  float fireMask = smoothstep(0.16, 0.0, length(lp * vec2(1.1, 1.9)) - 0.04 * fireN);
  vec3 fireCol = mix(vec3(2.8, 1.0, 0.18), vec3(4.5, 2.4, 0.7), fireN) * flick;
  col += fireCol * fireMask;
  return col;
}

// sparks / embers rising from the fire (screen space, additive)
vec3 embers(vec2 uv, vec2 anchor, float t){
  vec3 col = vec3(0.0);
  for (int i = 0; i < 22; i++){
    float fi = float(i);
    vec2 seed = vec2(fi * 12.9, fi * 3.7);
    float life = fract(t * 0.22 + hash21(seed));
    vec2 start = anchor + (hash22(seed) - 0.5) * vec2(0.10, 0.02);
    vec2 p = start + vec2((hash21(seed + 5.0) - 0.5) * 0.25, 0.0) * life
                    + vec2(0.0, life * (0.35 + 0.25 * hash21(seed + 9.0)));
    float d = length(uv - p);
    float tw = 0.5 + 0.5 * sin(t * 30.0 + fi * 7.0);
    float b = smoothstep(0.006, 0.0, d) * (1.0 - life) * tw;
    col += vec3(3.0, 1.2, 0.3) * b;
  }
  return col;
}

// ============================================================ exterior: vehicle ===
float sdRoundBox2(vec2 p, vec2 b, float r){ vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
// Kharkovchanka silhouette in local coords lp (meters, origin at ground under the vehicle)
float vehSil(vec2 lp){
  float track = sdRoundBox2(lp - vec2(0.0, 0.32), vec2(1.7, 0.30), 0.08);
  float body  = sdRoundBox2(lp - vec2(-0.05, 0.80), vec2(1.25, 0.42), 0.06);
  float cab   = sdRoundBox2(lp - vec2(0.55, 1.28), vec2(0.5, 0.30), 0.05);
  return min(min(track, body), cab);
}

// ============================================================ exterior scene ===
vec3 exteriorScene(vec2 fc, vec2 uv, float t){
  setupCam();
  vec3 rd = camRay(fc, gCamRo, vec3(0.0, 2.0, 5.0), FOCAL, 0.0);

  float flick = fireFlicker(t);
  vec3 fireWorld = vec3(2.6, 0.0, 42.0);
  vec3 fp = projectPoint(fireWorld);
  float fireScale = clamp(1.0 / max(fp.z, 1.0) * 9.0, 0.05, 0.4); // artistic scale, not literal

  // ---- sky: polar night, mostly black, aurora is the only real light ----
  vec3 sky = mix(vec3(0.0015, 0.002, 0.006), vec3(0.004, 0.006, 0.014), smoothstep(-0.1, 0.5, rd.y));
  sky += stars(rd) * vec3(0.8, 0.85, 1.0);
  sky += aurora(rd, t) * 2.2;
  // fire bleeding into the low sky near the horizon, angularly toward the fire, tight cone
  float angTo = 1.0 - clamp(distance(rd.xz / max(length(rd.xz), 1e-3), normalize(fireWorld.xz)), 0.0, 1.0);
  float horizonBand = exp(-abs(rd.y - 0.01) * 9.0);
  sky += vec3(1.4, 0.5, 0.14) * pow(max(angTo, 0.0), 40.0) * horizonBand * flick * 0.6;

  // ---- ground: dark blue-black snow, only the fire pool is warm ----
  vec3 col = sky;
  if (rd.y < -0.001){
    float dist = -gCamRo.y / rd.y;
    vec3 wp = gCamRo + rd * dist;
    float fog = 1.0 - exp(-dist * 0.035);
    float sn = fbm2(wp.xz * 0.35 + vec2(t * 0.6, 0.0));
    float sn2 = fbm2(wp.xz * 2.2 - vec2(t * 1.2, 0.0));
    vec3 snowCol = mix(vec3(0.014, 0.017, 0.028), vec3(0.03, 0.036, 0.055), sn) * (0.7 + 0.5 * sn2);
    snowCol += vec3(0.02, 0.035, 0.03) * clamp(aurora(vec3(0.0, 1.0, 0.0), t).g * 3.0, 0.0, 1.0); // faint reflected aurora
    // fire glow pooling on the snow near Object 9, falls off tightly (meters, not km)
    float dFire = distance(wp.xz, fireWorld.xz);
    snowCol += vec3(1.1, 0.42, 0.14) * flick * exp(-dFire * 0.7) * 1.1;
    col = mix(snowCol, sky, clamp(fog, 0.0, 1.0));
  }

  // ---- Object 9 plume (billboarded at fireWorld) ----
  vec2 lpFire = (uv - fp.xy) / fireScale;
  lpFire.y += 0.05;
  col += plumeColor(lpFire, t, flick) * fireScale * 2.0;
  col += embers(uv, fp.xy + vec2(0.0, 0.02), t) * fireScale;

  // ---- Kharkovchanka, receding across the plateau ----
  float vz = mix(12.0, 52.0, smoothstep(0.0, 7.0, t));
  vec3 vehWorld = vec3(-2.2, 0.0, vz);
  vec3 vp = projectPoint(vehWorld);
  float vScale = 1.0 / max(vp.z, 1.0) * FOCAL;
  vec2 lv = (uv - vp.xy) / vScale;
  float vd = vehSil(lv);
  float vMask = smoothstep(0.015, -0.008, vd);
  vec3 vehCol = vec3(0.0);
  col = mix(col, vehCol, vMask);
  // faint cool rim from the aurora/starlight catching the top edge, so the silhouette reads
  float rim = smoothstep(0.05, 0.0, abs(vd)) * (1.0 - vMask);
  col += vec3(0.10, 0.20, 0.20) * rim * 0.22;

  // tail lights at the rear-lower corners, + a faint warm exhaust glow underneath
  vec2 tl0 = vec2(-1.5, 0.34), tl1 = vec2(1.4, 0.34);
  float lampFlicker = 0.82 + 0.18 * noise2(vec2(t * 5.0, 1.0));
  float dl0 = length(lv - tl0), dl1 = length(lv - tl1);
  vec3 tail = vec3(3.2, 0.07, 0.04) * (exp(-dl0 * 55.0) + exp(-dl1 * 55.0)) * lampFlicker;
  tail += vec3(1.6, 0.08, 0.04) * (exp(-dl0 * 10.0) + exp(-dl1 * 10.0)) * 0.3;
  float dExh = length(lv - vec2(0.0, 0.15));
  vec3 headglow = vec3(0.7, 0.5, 0.3) * exp(-dExh * 9.0) * 0.15;
  col += (tail + headglow) * vScale * 2.2;

  // ---- blown snow, foreground drift (screen space, additive streaks) ----
  for (int i = 0; i < 3; i++){
    float fi = float(i);
    vec2 dir = normalize(vec2(0.85, -0.25));
    vec2 sc = uv * (18.0 + fi * 9.0) + dir * t * (2.2 + fi * 1.3) + fi * 31.7;
    vec2 cell = floor(sc), f = fract(sc) - 0.5;
    float h = hash21(cell + fi * 7.0);
    vec2 off = (hash22(cell + fi) - 0.5) * 0.6;
    float streak = smoothstep(0.05, 0.0, length((f - off) * vec2(1.0, 4.0))) * step(0.82, h);
    col += vec3(0.5, 0.55, 0.6) * streak * (0.5 - fi * 0.12);
  }

  return col;
}

// ============================================================ CRT (copied from s01) ===
float pulsePattern(float t){
  float loc = mod(t, 2.4);
  float offs[6] = float[6](0.10, 0.35, 0.55, 0.95, 1.45, 1.65);
  float p = 0.0;
  for (int i = 0; i < 6; i++){
    float d = loc - offs[i];
    p = max(p, exp(-d * d * 2200.0));
  }
  return p;
}
float waveform(float x, float t){
  float pulse = pulsePattern(t - x * 0.35);
  float carrier = sin(x * 9.0 - t * 5.0);
  float n = (noise2(vec2(x * 24.0, t * 14.0)) - 0.5);
  return carrier * (0.035 + 0.30 * pulse) + n * 0.05 * (0.3 + pulse);
}
vec3 crtReceiver(vec2 fc, vec2 uv, float tLocal){
  float onT = smoothstep(0.0, 0.55, tLocal);
  float flicker = onT * (0.86 + 0.14 * hash11(floor(tLocal * 41.0) + 3.0));

  float zoom = 1.0;
  vec2 su = uv / zoom;
  float r2 = dot(su, su);
  vec2 cuv = su * (1.0 + 0.20 * r2);
  vec2 scr = cuv / vec2(0.60, 0.40);

  float inScreen = step(max(abs(scr.x), abs(scr.y)), 1.0);
  vec3 phosphor = vec3(0.30, 1.0, 0.42);

  vec3 panel = vec3(0.018, 0.02, 0.019) * (0.65 + 0.35 * fbm2(uv * 5.0 + 4.0));
  panel += vec3(0.03, 0.10, 0.045) * smoothstep(1.4, 1.0, max(abs(scr.x), abs(scr.y))) * flicker;

  vec2 gcell = scr * vec2(5.0, 4.0);
  vec2 gf = abs(fract(gcell) - 0.5);
  float grid = 1.0 - smoothstep(0.02, 0.04, min(gf.x, gf.y));
  float axis = 1.0 - smoothstep(0.01, 0.025, min(abs(scr.x), abs(scr.y)));

  float wx = scr.x;
  float wy = waveform(wx * 3.0, tLocal) * 1.7;
  float distL = abs(scr.y * 0.82 - wy);
  float trace = exp(-distL * 60.0) * 1.7 + exp(-distL * 14.0) * 0.32;

  float stripT = smoothstep(0.62, 0.72, scr.y) * (1.0 - smoothstep(0.9, 0.98, scr.y));
  float col_i = floor((scr.x * 0.5 + 0.5) * 44.0);
  float barH = hash21(vec2(col_i, floor(tLocal * 5.0))) * 0.5 + 0.5 * pulsePattern(tLocal - col_i * 0.015);
  float withinBar = step(1.0 - barH, (scr.y - 0.62) / 0.36 * -1.0 + 1.0);
  float spectro = stripT * withinBar * (0.5 + 0.5 * hash21(vec2(col_i, floor(tLocal * 20.0))));

  vec3 screenCol = vec3(0.0);
  screenCol += grid * 0.05 * phosphor;
  screenCol += axis * 0.08 * phosphor;
  screenCol += trace * phosphor;
  screenCol += spectro * phosphor * 0.7;
  screenCol += phosphor * 0.012;

  float streak = smoothstep(0.06, 0.0, abs(scr.x + scr.y * 0.35 - 0.65)) * 0.05;
  screenCol += streak;

  float tubeVig = clamp(1.0 - 0.35 * dot(scr, scr), 0.0, 1.0);
  screenCol *= tubeVig * flicker;

  vec3 col = mix(panel, screenCol, inScreen);
  vec3 prevCol = texture(iPrev, fc / iResolution).rgb;
  col = max(col, prevCol * 0.80 - 0.004);
  return col;
}

// ============================================================ render ===
vec3 render(vec2 fc){
  vec2 uv = screenUV(fc);

  if (iTime < 7.0){
    return exteriorScene(fc, uv, iTime);
  }
  if (iTime < 13.0){
    if (iTime < 7.3) return vec3(0.0);
    return crtReceiver(fc, uv, iTime - 7.3);
  }
  // 13-15s: hard black, title drawn in overlay
  return vec3(0.0);
}
