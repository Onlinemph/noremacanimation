// Browser-side renderer. Loaded by page.html, driven from render.mjs via window.ENGINE.
// Pipeline per frame:
//   scene pass  (shot.glsl, HDR, RGBA16F, optionally at reduced scale)
//   post pass   (shaders/post.glsl: shake, aberration, bloom, grade, grain, vignette, letterbox, tonemap)
//   overlay     (shot.js overlay(ctx, t, W, H) drawn with Canvas2D on top)

const VS = `#version 300 es
in vec2 aPos; void main(){ gl_Position = vec4(aPos,0.,1.); }`;

const SCENE_HEADER = `#version 300 es
precision highp float;
precision highp int;
uniform vec2  iResolution;   // scene buffer size in pixels
uniform float iTime;         // shot-local time in seconds
uniform int   iFrame;
uniform float uP[16];        // free params from shot.js params(t)
uniform sampler2D iPrev;     // previous scene frame (HDR), for trails
uniform float uAspectBar;    // letterbox: fraction of height covered by each bar (0 = none)
uniform sampler2D iTex0, iTex1, iTex2, iTex3; // canvas-drawn textures from shot.js textures[]
out vec4 fragColor;
`;

const POST_HEADER = `#version 300 es
precision highp float;
uniform vec2  iResolution;
uniform float iTime;
uniform int   iFrame;
uniform sampler2D iScene;
uniform float pGrain, pAberr, pVignette, pFlash, pShake, pExposure, pFade, pBloom, pBar, pScan, pSat, pContrast, pTemp;
uniform vec3  pFlashColor;
uniform vec3  pLift;
out vec4 fragColor;
`;

let gl, glc, outc, octx, W, H, SW, SH;
let sceneProg, postProg, quad;
let sceneTex = [], sceneFbo = [], cur = 0;
let shot, frame = 0, userTex = [];

function compile(type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(s);
    // annotate with line numbers for easier debugging
    const lines = src.split('\n');
    const m = /0:(\d+)/.exec(log || '');
    let ctx = '';
    if (m) { const n = +m[1]; ctx = lines.slice(Math.max(0, n - 4), n + 2).map((l, i) => (Math.max(0, n - 4) + i + 1) + ': ' + l).join('\n'); }
    throw new Error('Shader compile error:\n' + log + '\n' + ctx);
  }
  return s;
}
function program(fsrc) {
  const p = gl.createProgram();
  gl.attachShader(p, compile(gl.VERTEX_SHADER, VS));
  gl.attachShader(p, compile(gl.FRAGMENT_SHADER, fsrc));
  gl.bindAttribLocation(p, 0, 'aPos');
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error('Link error: ' + gl.getProgramInfoLog(p));
  p.loc = {};
  return p;
}
function U(p, name) { if (!(name in p.loc)) p.loc[name] = gl.getUniformLocation(p, name); return p.loc[name]; }

function makeTarget(w, h) {
  const t = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, t);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, w, h, 0, gl.RGBA, gl.HALF_FLOAT, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  const f = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, f);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, t, 0);
  const st = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
  if (st !== gl.FRAMEBUFFER_COMPLETE) throw new Error('FBO incomplete ' + st);
  return [t, f];
}

const POST_DEFAULTS = {
  grain: 0.06, aberr: 0.0015, vignette: 0.9, flash: 0, flashColor: [1, 0.85, 0.6], shake: 0,
  exposure: 1, fade: 0, bloom: 0.35, bar: 0.12, scan: 0, sat: 1, contrast: 1.05, temp: 0, lift: [0, 0, 0],
};

async function init(opts) {
  W = opts.W; H = opts.H;
  const scale = opts.sceneScale ?? 1;
  SW = Math.round(W * scale); SH = Math.round(H * scale);
  glc = document.getElementById('gl'); glc.width = W; glc.height = H;
  outc = document.getElementById('out'); outc.width = W; outc.height = H;
  gl = glc.getContext('webgl2', { preserveDrawingBuffer: true, antialias: false });
  if (!gl) throw new Error('no webgl2');
  if (!gl.getExtension('EXT_color_buffer_float')) throw new Error('no float fbo');
  gl.getExtension('OES_texture_float_linear');
  octx = outc.getContext('2d', { willReadFrequently: true });

  shot = (await import(opts.shotUrl + '?v=' + Date.now())).default;
  await document.fonts.ready;
  // force-load all font faces so overlays never draw with fallback fonts
  await Promise.all([...document.fonts].map(f => f.load().catch(() => null)));

  sceneProg = program(SCENE_HEADER + opts.common + '\n#line 1\n' + opts.glsl + `
void main(){
  vec2 fc = gl_FragCoord.xy;
  float bar = uAspectBar * iResolution.y;
  if (fc.y < bar - 2. || fc.y > iResolution.y - bar + 2.) { fragColor = vec4(0.); return; }
  fragColor = vec4(max(render(fc), 0.), 1.);
}`);
  postProg = program(POST_HEADER + opts.post);

  quad = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, quad);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

  for (let i = 0; i < 2; i++) { const [t, f] = makeTarget(SW, SH); sceneTex.push(t); sceneFbo.push(f); }

  // static textures drawn by shot.js: textures: [{w, h, draw(ctx, w, h)}]
  userTex = [];
  for (let i = 0; i < 4; i++) {
    const spec = (shot.textures || [])[i];
    const c = document.createElement('canvas');
    c.width = spec ? spec.w : 4; c.height = spec ? spec.h : 4;
    const cx = c.getContext('2d');
    if (spec) spec.draw(cx, c.width, c.height);
    const t = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, c);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    gl.generateMipmap(gl.TEXTURE_2D);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    userTex.push(t);
  }
  return { duration: shot.duration, fps: shot.fps || 24 };
}

function renderFrame(t, frameIndex) {
  frame = frameIndex;
  const post = Object.assign({}, POST_DEFAULTS, shot.post ? shot.post(t) : {});
  const params = new Float32Array(16);
  if (shot.params) { const p = shot.params(t); for (let i = 0; i < Math.min(16, p.length); i++) params[i] = p[i]; }

  // scene
  const prev = cur; cur = 1 - cur;
  gl.bindFramebuffer(gl.FRAMEBUFFER, sceneFbo[cur]);
  gl.viewport(0, 0, SW, SH);
  gl.useProgram(sceneProg);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, sceneTex[prev]);
  gl.uniform1i(U(sceneProg, 'iPrev'), 0);
  for (let i = 0; i < 4; i++) {
    gl.activeTexture(gl.TEXTURE1 + i); gl.bindTexture(gl.TEXTURE_2D, userTex[i]);
    gl.uniform1i(U(sceneProg, 'iTex' + i), 1 + i);
  }
  gl.activeTexture(gl.TEXTURE0);
  gl.uniform2f(U(sceneProg, 'iResolution'), SW, SH);
  gl.uniform1f(U(sceneProg, 'iTime'), t);
  gl.uniform1i(U(sceneProg, 'iFrame'), frameIndex);
  gl.uniform1fv(U(sceneProg, 'uP[0]'), params);
  gl.uniform1f(U(sceneProg, 'uAspectBar'), post.bar);
  gl.drawArrays(gl.TRIANGLES, 0, 3);

  gl.bindTexture(gl.TEXTURE_2D, sceneTex[cur]);
  gl.generateMipmap(gl.TEXTURE_2D);

  // post
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  gl.viewport(0, 0, W, H);
  gl.useProgram(postProg);
  gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, sceneTex[cur]);
  gl.uniform1i(U(postProg, 'iScene'), 0);
  gl.uniform2f(U(postProg, 'iResolution'), W, H);
  gl.uniform1f(U(postProg, 'iTime'), t);
  gl.uniform1i(U(postProg, 'iFrame'), frameIndex);
  const f1 = (n, v) => gl.uniform1f(U(postProg, n), v);
  f1('pGrain', post.grain); f1('pAberr', post.aberr); f1('pVignette', post.vignette);
  f1('pFlash', post.flash); f1('pShake', post.shake); f1('pExposure', post.exposure);
  f1('pFade', post.fade); f1('pBloom', post.bloom); f1('pBar', post.bar); f1('pScan', post.scan);
  f1('pSat', post.sat); f1('pContrast', post.contrast); f1('pTemp', post.temp);
  gl.uniform3fv(U(postProg, 'pFlashColor'), post.flashColor);
  gl.uniform3fv(U(postProg, 'pLift'), post.lift);
  gl.drawArrays(gl.TRIANGLES, 0, 3);
  gl.finish();

  // composite + overlay
  octx.setTransform(1, 0, 0, 1, 0, 0);
  octx.globalAlpha = 1; octx.globalCompositeOperation = 'source-over'; octx.filter = 'none';
  octx.drawImage(glc, 0, 0);
  if (shot.overlay) { octx.save(); shot.overlay(octx, t, W, H, post); octx.restore(); }
  return octx.getImageData(0, 0, W, H).data;
}

// Returns frame as base64 of raw RGBA
function b64(u8) {
  let s = '';
  const CH = 0x8000;
  for (let i = 0; i < u8.length; i += CH) s += String.fromCharCode.apply(null, u8.subarray(i, i + CH));
  return btoa(s);
}

window.ENGINE = {
  init,
  frameRaw: (t, i) => b64(new Uint8Array(renderFrame(t, i).buffer)),
  framePng: (t, i) => { renderFrame(t, i); return outc.toDataURL('image/png'); },
};
window.ENGINE_READY = true;
