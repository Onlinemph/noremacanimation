// s01_signal — black typewriter slate, then a green phosphor CRT oscilloscope / radio
// receiver decoding the distress call. No raymarching: pure 2D screen-space shader, cheap.

// ---- shared "signal" pulse pattern (also copied into s10_end; keep identical) ----
// A 2.4s loop, six pulses (short-short-short / pause / long-long), matches cues.json.
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

vec3 crtReceiver(vec2 fc, vec2 uv){
  float onT = smoothstep(4.3, 4.9, iTime);
  float flicker = onT * (0.86 + 0.14 * hash11(floor(iTime * 41.0) + 3.0));

  float zoom = mix(1.0, 1.24, smoothstep(4.6, 12.0, iTime));
  vec2 su = uv / zoom;

  // barrel distortion: slightly curved glass
  float r2 = dot(su, su);
  vec2 cuv = su * (1.0 + 0.20 * r2);

  vec2 scr = cuv / vec2(0.60, 0.40); // -1..1 across the scope's visible screen

  float inScreen = step(max(abs(scr.x), abs(scr.y)), 1.0);

  vec3 phosphor = vec3(0.30, 1.0, 0.42);

  // bezel / receiver panel
  vec3 panel = vec3(0.018, 0.02, 0.019) * (0.65 + 0.35 * fbm2(uv * 5.0 + 4.0));
  panel += vec3(0.03, 0.10, 0.045) * smoothstep(1.4, 1.0, max(abs(scr.x), abs(scr.y))) * flicker;

  // graticule
  vec2 gcell = scr * vec2(5.0, 4.0);
  vec2 gf = abs(fract(gcell) - 0.5);
  float grid = 1.0 - smoothstep(0.02, 0.04, min(gf.x, gf.y));
  float axis = 1.0 - smoothstep(0.01, 0.025, min(abs(scr.x), abs(scr.y)));

  // waveform trace with a light left->right time skew (signal arriving)
  float wx = scr.x;
  float wy = waveform(wx * 3.0, iTime) * 1.7;
  float distL = abs(scr.y * 0.82 - wy);
  float trace = exp(-distL * 60.0) * 1.7 + exp(-distL * 14.0) * 0.32;

  // spectrogram strip along the bottom of the screen
  float stripT = smoothstep(0.62, 0.72, scr.y) * (1.0 - smoothstep(0.9, 0.98, scr.y));
  float col_i = floor((scr.x * 0.5 + 0.5) * 44.0);
  float barH = hash21(vec2(col_i, floor(iTime * 5.0))) * 0.5 + 0.5 * pulsePattern(iTime - col_i * 0.015);
  float withinBar = step(1.0 - barH, (scr.y - 0.62) / 0.36 * -1.0 + 1.0);
  float spectro = stripT * withinBar * (0.5 + 0.5 * hash21(vec2(col_i, floor(iTime * 20.0))));

  vec3 screenCol = vec3(0.0);
  screenCol += grid * 0.05 * phosphor;
  screenCol += axis * 0.08 * phosphor;
  screenCol += trace * phosphor;
  screenCol += spectro * phosphor * 0.7;
  screenCol += phosphor * 0.012; // base tube glow

  // faint diagonal glass reflection streak
  float streak = smoothstep(0.06, 0.0, abs(scr.x + scr.y * 0.35 - 0.65)) * 0.05;
  screenCol += streak;

  float tubeVig = clamp(1.0 - 0.35 * dot(scr, scr), 0.0, 1.0);
  screenCol *= tubeVig * flicker;

  vec3 col = mix(panel, screenCol, inScreen);

  // phosphor persistence: decayed trail from previous frame
  vec3 prevCol = texture(iPrev, fc / iResolution).rgb;
  col = max(col, prevCol * 0.80 - 0.004);

  return col;
}

vec3 render(vec2 fc){
  vec2 uv = screenUV(fc);

  if (iTime < 4.35){
    // black slate: only the faintest drifting noise, everything else is post grain
    float n = fbm2(uv * 2.2 + iTime * 0.02);
    return vec3(0.004, 0.0042, 0.0048) * n;
  }
  return crtReceiver(fc, uv);
}
