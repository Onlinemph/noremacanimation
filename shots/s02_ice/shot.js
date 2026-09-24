// s02_ice (12 s) — blizzard on the polar plateau; a Tucker Sno-Cat emerges from the spindrift and
// passes close by the low camera at ~9.8 s. Camera pans to follow and lets it go.

// wind gusts (shared with the shader via uP[0] so snow density, fog and camera shake agree)
function gust(t) {
  const g = (c, w) => Math.exp(-(((t - c) / w) ** 2));
  return Math.min(1, 0.15 + 0.85 * g(2.4, 0.9) + 0.7 * g(6.1, 1.0) + 0.9 * g(9.9, 0.7));
}

export default {
  duration: 12,
  fps: 24,
  sceneScale: 0.66,
  params(t) { return [gust(t)]; },
  post(t) {
    const gu = gust(t);
    // the pass-by rattles the camera
    const pass = Math.exp(-(((t - 9.8) / 0.6) ** 2));
    return {
      bar: 0.12,
      grain: 0.05,
      aberr: 0.0016,
      vignette: 1.05,
      bloom: 0.45,
      exposure: 1.15,
      contrast: 1.08,
      sat: 0.9,
      temp: -0.12,
      shake: 0.05 + gu * 0.12 + pass * 0.25,
      fade: t < 0.5 ? 1 - t / 0.5 : (t > 11.5 ? (t - 11.5) / 0.5 : 0),
    };
  },
  overlay(ctx, t, W, H) {
    const s = W / 1280;
    const a0 = 1.5, a1 = 2.3, a2 = 4.2, a3 = 5.0;
    let alpha = 0;
    if (t >= a0 && t < a1) alpha = (t - a0) / (a1 - a0);
    else if (t >= a1 && t < a2) alpha = 1;
    else if (t >= a2 && t < a3) alpha = 1 - (t - a2) / (a3 - a2);
    if (alpha > 0) {
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.textAlign = 'left';
      ctx.fillStyle = 'rgba(225,230,238,0.92)';
      ctx.font = `${Math.round(22 * s)}px "Special Elite"`;
      ctx.shadowColor = 'rgba(0,0,0,0.85)';
      ctx.shadowBlur = 4 * s;
      ctx.fillText('340 KM INTO THE PLATEAU. −71 °C.', 64 * s, H - 72 * s);
      ctx.restore();
    }
  },
};
