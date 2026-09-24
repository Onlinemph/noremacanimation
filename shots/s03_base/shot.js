export default {
  duration: 10,
  fps: 24,
  sceneScale: 0.28,
  post(t) {
    const gust = Math.exp(-(((t - 2.0) / 1.4) ** 2)) + Math.exp(-(((t - 6.5) / 1.6) ** 2));
    return {
      bar: 0.12,
      grain: 0.07,
      aberr: 0.0016,
      vignette: 1.05,
      bloom: 0.4,
      exposure: 1.0,
      contrast: 1.1,
      sat: 0.72,
      temp: -0.15,
      shake: 0.1 + Math.min(gust, 1) * 0.25,
      fade: t < 0.4 ? 1 - t / 0.4 : (t > 9.6 ? (t - 9.6) / 0.4 : 0),
    };
  },
  textures: [
    {
      w: 1024, h: 704,
      draw(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        // faded red star, upper-left
        const cx = w * 0.16, cy = h * 0.28, R = h * 0.16;
        ctx.save();
        ctx.globalAlpha = 0.4;
        ctx.fillStyle = '#8a1a12';
        ctx.beginPath();
        for (let i = 0; i < 5; i++) {
          const a0 = -Math.PI / 2 + i * (Math.PI * 2 / 5);
          const a1 = a0 + Math.PI / 5;
          const x0 = cx + Math.cos(a0) * R, y0 = cy + Math.sin(a0) * R;
          const x1 = cx + Math.cos(a1) * R * 0.42, y1 = cy + Math.sin(a1) * R * 0.42;
          if (i === 0) ctx.moveTo(x0, y0); else ctx.lineTo(x0, y0);
          ctx.lineTo(x1, y1);
        }
        ctx.closePath();
        ctx.fill();
        ctx.restore();
        // stencilled Cyrillic "ОБЪЕКТ 9", worn paint
        ctx.save();
        ctx.globalAlpha = 0.5;
        ctx.fillStyle = '#c8c6bc';
        ctx.font = `bold ${Math.round(h * 0.15)}px "Russo One"`;
        ctx.textBaseline = 'middle';
        ctx.textAlign = 'left';
        ctx.translate(w * 0.06, h * 0.62);
        ctx.fillText('ОБЪЕКТ 9', 0, 0);
        ctx.restore();
        // weathering: sparse dark speckle over the whole panel
        ctx.save();
        ctx.globalAlpha = 0.35;
        let seed = 7;
        const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
        for (let i = 0; i < 400; i++) {
          const x = rnd() * w, y = rnd() * h, r = rnd() * 2.5 + 0.5;
          ctx.fillStyle = rnd() > 0.5 ? '#000000' : '#3a3a38';
          ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        }
        ctx.restore();
      },
    },
  ],
  overlay(ctx, t, W, H) {
    const s = W / 1280;
    const a0 = 6.3, a1 = 6.9, a2 = 8.9, a3 = 9.5;
    let alpha = 0;
    if (t >= a0 && t < a1) alpha = (t - a0) / (a1 - a0);
    else if (t >= a1 && t < a2) alpha = 1;
    else if (t >= a2 && t < a3) alpha = 1 - (t - a2) / (a3 - a2);
    if (alpha <= 0) return;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.textAlign = 'center';
    const cx = W / 2;
    ctx.save();
    ctx.shadowColor = 'rgba(200,20,10,0.55)';
    ctx.shadowBlur = 22 * s;
    ctx.fillStyle = 'rgba(230,224,212,0.95)';
    ctx.font = `${Math.round(78 * s)}px "Russo One"`;
    ctx.fillText('ОБЪЕКТ 9', cx, H * 0.46);
    ctx.restore();
    ctx.shadowColor = 'rgba(0,0,0,0.7)';
    ctx.shadowBlur = 4 * s;
    ctx.fillStyle = 'rgba(210,214,220,0.85)';
    ctx.font = `${Math.round(20 * s)}px "Oswald"`;
    ctx.fillText('O B J E C T   9', cx, H * 0.46 + 44 * s);
    ctx.restore();
  },
};
