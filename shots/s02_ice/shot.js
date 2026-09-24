export default {
  duration: 12,
  fps: 24,
  sceneScale: 0.6,
  post(t) {
    const gust = Math.exp(-(((t - 2.2) / 0.9) ** 2)) + Math.exp(-(((t - 6.0) / 1.0) ** 2)) + Math.exp(-(((t - 9.7) / 0.8) ** 2));
    return {
      bar: 0.12,
      grain: 0.07,
      aberr: 0.0018,
      vignette: 1.05,
      bloom: 0.55,
      exposure: 1.05,
      contrast: 1.08,
      sat: 0.92,
      temp: -0.35,
      shake: 0.15 + Math.min(gust, 1) * 0.35,
      fade: t < 0.4 ? 1 - t / 0.4 : (t > 11.6 ? (t - 11.6) / 0.4 : 0),
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
