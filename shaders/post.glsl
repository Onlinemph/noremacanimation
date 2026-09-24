// Post-processing: camera shake, chromatic aberration, bloom, exposure/tonemap,
// grade, flash, grain, scanlines, vignette, letterbox, fade.
// Uniforms are declared in engine.js POST_HEADER; values come from shot.js post(t).

float ph(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float ph3(vec3 p){ p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }

vec3 aces(vec3 x){
  const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0., 1.);
}

vec3 sampleScene(vec2 uv){
  vec2 c = uv - 0.5;
  float r2 = dot(c, c);
  vec2 off = c * pAberr * (1.0 + 4.0 * r2);
  vec3 col;
  col.r = texture(iScene, uv + off).r;
  col.g = texture(iScene, uv).g;
  col.b = texture(iScene, uv - off).b;
  return col;
}

void main(){
  vec2 fc = gl_FragCoord.xy;
  vec2 uv = fc / iResolution;

  // shake: smooth-ish jitter
  float ft = floor(iTime * 24.0);
  vec2 sh = vec2(ph(vec2(ft, 1.3)) - 0.5, ph(vec2(ft, 7.1)) - 0.5) * pShake * 0.03;
  uv += sh;

  vec3 col = sampleScene(uv);

  // bloom from mip chain
  vec3 bl = vec3(0.);
  bl += textureLod(iScene, uv, 2.0).rgb * 0.30;
  bl += textureLod(iScene, uv, 3.5).rgb * 0.30;
  bl += textureLod(iScene, uv, 5.0).rgb * 0.25;
  bl += textureLod(iScene, uv, 6.5).rgb * 0.15;
  bl = max(bl - 0.35, 0.0);
  col += bl * pBloom;

  col *= pExposure;
  col += pFlashColor * pFlash;

  // white balance shift: +temp = warmer, -temp = colder
  col *= vec3(1.0 + 0.12 * pTemp, 1.0, 1.0 - 0.12 * pTemp);
  col += pLift * 0.05;

  col = aces(col);

  // grade
  float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(l), col, pSat);
  col = (col - 0.5) * pContrast + 0.5;
  col = clamp(col, 0., 1.);
  col = pow(col, vec3(1.0 / 2.2));

  // vignette
  vec2 q = fc / iResolution - 0.5;
  float v = 1.0 - dot(q * vec2(1.15, 1.6), q * vec2(1.15, 1.6)) * pVignette;
  col *= clamp(v, 0.0, 1.0);

  // scanlines / VHS
  if (pScan > 0.0) {
    col *= 1.0 - pScan * 0.35 * (0.5 + 0.5 * sin(fc.y * 3.14159));
    float band = smoothstep(0.995, 1.0, sin(uv.y * 8.0 - iTime * 3.0));
    col += pScan * band * 0.08;
  }

  // film grain (luma-weighted, stronger in shadows)
  float g = ph3(vec3(fc, float(iFrame) * 17.0)) - 0.5;
  col += g * pGrain * (1.2 - l);

  // flicker-safe fade to black
  col *= 1.0 - pFade;

  // letterbox
  float bar = pBar * iResolution.y;
  if (fc.y < bar || fc.y > iResolution.y - bar) col = vec3(0.0);

  fragColor = vec4(clamp(col, 0., 1.), 1.0);
}
