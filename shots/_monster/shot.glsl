float RUN;
vec2 map(vec3 p){
  vec2 r = vec2(p.y, M_CONCRETE);
  r = opU(r, vec2(-p.z + 4., M_CONCRETE));
  vec3 mp = p;
  mp.xz *= rot2(uP[1]);
  float b = sdCapsule(mp, vec3(0,.2,0), vec3(0,2.,0), 1.);
  r = opU(r, b > .2 ? vec2(b, 0.) : sdMonster(mp, iTime, uP[2], RUN));
  return r;
}
vec3 nrm(vec3 p){ vec2 e = vec2(.0007, 0); return normalize(vec3(map(p+e.xyy).x-map(p-e.xyy).x, map(p+e.yxy).x-map(p-e.yxy).x, map(p+e.yyx).x-map(p-e.yyx).x)); }
float shadow(vec3 ro, vec3 rd, float mx){ float res = 1., t = .02; for (int i = 0; i < 40; i++){ float h = map(ro + rd * t).x; res = min(res, 10. * h / t); t += clamp(h, .01, .2); if (res < .01 || t > mx) break; } return clamp(res, 0., 1.); }
vec3 render(vec2 fc){
  RUN = uP[3];
  int cam = int(uP[0]);
  vec3 ro, ta;
  if (cam == 0){ ro = vec3(.05, 1.4, .95); ta = vec3(0., 1.47, .25); }
  else if (cam == 1){ ro = vec3(1.6, 1.3, 3.2); ta = vec3(0., 1.05, 0.); }
  else { ro = vec3(-2.5, 1.0, 1.5); ta = vec3(0., 1.0, 0.); }
  vec3 rd = camRay(fc, ro, ta, 1.7, 0.);
  float d = 0.; vec2 h;
  for (int i = 0; i < 180; i++){ h = map(ro + rd * d); if (abs(h.x) < .0005 * d || d > 20.) break; d += h.x * .7; }
  vec3 col = vec3(0.);
  if (d < 20.){
    vec3 p = ro + rd * d, n = nrm(p);
    vec3 alb = h.y <= 4. ? monsterAlbedo(h.y, p) : vec3(.2);
    // key: flashlight from camera-ish, rim: cold light behind
    vec3 kp = ro + vec3(.3, -.2, 0.);
    vec3 L = normalize(kp - p);
    float k = max(dot(n, L), 0.) * spotLight(p, kp, normalize(ta - kp), .85, .97) * 2.;
    vec3 rp = vec3(-1., 2.8, -2.5);
    vec3 R = normalize(rp - p);
    float rim = max(dot(n, R), 0.) * shadow(p + n * .01, R, 5.);
    float sp = pow(max(dot(reflect(-L, n), -rd), 0.), 60.) * (h.y <= 4. ? monsterSpec(h.y) : .1);
    float fres = pow(1. - max(dot(n, -rd), 0.), 3.);
    col = alb * (k * vec3(1., .95, .85) + rim * vec3(.35, .5, .9) * 1.5 + .01) + sp * k * .8 + fres * rim * .2;
  }
  return col;
}
