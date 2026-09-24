// s03_base (10 s) — reveal of Object 9 over the Sno-Cat's shoulder; slow push-in; the mast beacon
// blinks every 1.6 s (first at 0.7 s); title card 6.5–9.5 s.

function gust(t) {
  const g = (c, w) => Math.exp(-(((t - c) / w) ** 2));
  return Math.min(1, 0.12 + 0.6 * g(2.0, 1.2) + 0.7 * g(6.6, 1.4));
}
export const BLINK0 = 0.7, BLINK_P = 1.6;
function beacon(t) {
  if (t < BLINK0 - 0.05) return 0;
  const ph = (t - BLINK0) % BLINK_P;
  if (ph < 0.06) return ph / 0.06;          // strobe-ish attack
  if (ph < 0.42) return 1;
  if (ph < 0.75) return Math.pow(1 - (ph - 0.42) / 0.33, 2);  // incandescent decay
  return 0;
}

export default {
  duration: 10,
  fps: 24,
  sceneScale: 0.6,
  params(t) { return [gust(t), beacon(t)]; },
  post(t) {
    const gu = gust(t);
    return {
      bar: 0.12,
      grain: 0.05,
      aberr: 0.0015,
      vignette: 1.1,
      bloom: 0.45,
      exposure: 1.2,
      contrast: 1.08,
      sat: 0.92,
      temp: -0.1,
      shake: 0.03 + gu * 0.08,
      fade: t < 0.4 ? 1 - t / 0.4 : (t > 9.6 ? (t - 9.6) / 0.4 : 0),
    };
  },
  textures: [
    {
      // portal face above the blast door: 9 m x 1.55 m of concrete, transparent where unpainted
      w: 1024, h: 176,
      draw(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        let seed = 11;
        const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
        // faded red star on the left
        const cx = w * 0.2, cy = h * 0.5, R = h * 0.4;
        ctx.save();
        ctx.fillStyle = 'rgba(150,26,18,0.85)';
        ctx.beginPath();
        for (let i = 0; i < 5; i++) {
          const a0 = -Math.PI / 2 + i * (Math.PI * 2 / 5), a1 = a0 + Math.PI / 5;
          ctx.lineTo(cx + Math.cos(a0) * R, cy + Math.sin(a0) * R);
          ctx.lineTo(cx + Math.cos(a1) * R * 0.4, cy + Math.sin(a1) * R * 0.4);
        }
        ctx.closePath(); ctx.fill();
        ctx.restore();
        // stencilled ОБЪЕКТ 9
        ctx.save();
        ctx.fillStyle = 'rgba(214,208,190,0.92)';
        ctx.font = `${Math.round(h * 0.62)}px "Russo One"`;
        ctx.textBaseline = 'middle';
        ctx.textAlign = 'left';
        ctx.fillText('ОБЪЕКТ 9', w * 0.3, h * 0.53);
        ctx.restore();
        // stencil bridges (thin vertical gaps) and weathering: paint flaked off
        ctx.save();
        ctx.globalCompositeOperation = 'destination-out';
        for (let i = 0; i < 700; i++) {
          const x = rnd() * w, y = rnd() * h, r = rnd() * rnd() * 7 + 0.6;
          ctx.globalAlpha = 0.5 + 0.5 * rnd();
          ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        }
        // drip-streak erosion
        for (let i = 0; i < 40; i++) {
          const x = rnd() * w, y0 = rnd() * h * 0.5, l = rnd() * h;
          ctx.globalAlpha = 0.35;
          ctx.fillRect(x, y0, 1 + rnd() * 3, l);
        }
        ctx.restore();
      },
    },
  ],
  overlay(ctx, t, W, H) {
    const s = W / 1280;
    const a0 = 6.5, a1 = 7.1, a2 = 8.9, a3 = 9.5;
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
    ctx.fillText('ОБЪЕКТ 9', cx, H * 0.27);
    ctx.restore();
    ctx.shadowColor = 'rgba(0,0,0,0.7)';
    ctx.shadowBlur = 4 * s;
    ctx.fillStyle = 'rgba(210,214,220,0.85)';
    ctx.font = `${Math.round(20 * s)}px "Oswald"`;
    ctx.fillText('O B J E C T   9', cx, H * 0.27 + 44 * s);
    ctx.restore();
  },
};
