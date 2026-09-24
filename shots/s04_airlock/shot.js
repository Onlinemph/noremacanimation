// s04_airlock — inside the entrance airlock looking back at the open blast door.
//  0-4    door open onto the snow trench, wind and snow pour in, two torches sweep
//  4-6    the door swings shut on its own, grinding
//  6.0    SLAM. three locking dogs shoot home at 6.1 / 6.3 / 6.5
//  7.0    the bulkhead lamp dies. torches only
//  8.0    red emergency beacon starts rotating
//  8.3-9.8  "THE DOOR SEALED BEHIND US."

const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
function hash(n) { const s = Math.sin(n * 91.7) * 43758.5453; return s - Math.floor(s); }

function doorAngle(t) {
  // 0 = closed, 1 = fully open (swung into the room)
  if (t < 4) return 1;
  const k = clamp((t - 4) / 2, 0, 1);
  const e = k * k * k;                                 // accelerating, hydraulic slam
  const judder = t < 6 ? 0.012 * Math.sin(t * 60) * k : 0;
  return clamp(1 - e + judder, 0, 1);
}
function bolt(t, t0) { return smooth(t0, t0 + 0.08, t); }
function lamp(t) {
  if (t < 6.9) return 1;
  if (t < 7.05) return hash(Math.floor(t * 70)) > 0.45 ? 0.8 : 0;
  return 0;
}
function beacon(t) { return t < 8 ? 0 : smooth(8, 8.15, t); }

export default {
  duration: 10,
  fps: 24,
  sceneScale: 0.72,

  params(t) {
    return [doorAngle(t), bolt(t, 6.1), bolt(t, 6.3), bolt(t, 6.5), lamp(t), beacon(t), t >= 6 ? t - 6 : -1, t];
  },

  post(t) {
    const p = { bar: 0.12, grain: 0.08, vignette: 1.1, bloom: 0.5, aberr: 0.0016, temp: -0.2, contrast: 1.1, sat: 0.85, exposure: 1.05 };
    if (t >= 6 && t < 6.7) {
      const k = 1 - (t - 6) / 0.7;
      p.shake = 1.2 * k * k;
      p.flash = t < 6.05 ? 0.15 : 0;
      p.flashColor = [0.9, 0.9, 1.0];
    }
    if (t >= 4 && t < 6) p.shake = 0.12 * (t - 4) / 2;
    if (t >= 8) { p.temp = 0.1; p.sat = 1.0; }
    return p;
  },

  textures: [
    {
      w: 1024, h: 256,
      draw(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        ctx.fillStyle = 'rgba(160,20,15,0.85)';
        ctx.fillRect(40, 30, w - 80, h - 60);
        ctx.fillStyle = 'rgba(235,225,200,0.92)';
        let fs = 120; ctx.font = `${fs}px "Russo One"`;
        const mw = ctx.measureText('ВЫХОД ЗАПРЕЩЁН').width;
        if (mw > w - 150) { fs *= (w - 150) / mw; ctx.font = `${fs}px "Russo One"`; }
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText('ВЫХОД ЗАПРЕЩЁН', w / 2, h / 2 + 6);
        // wear
        ctx.globalCompositeOperation = 'destination-out';
        for (let i = 0; i < 160; i++) {
          ctx.globalAlpha = 0.2 + 0.6 * hash(i);
          ctx.beginPath(); ctx.arc(hash(i + 1) * w, hash(i + 2) * h, 2 + hash(i + 3) * 10, 0, 7); ctx.fill();
        }
        ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
      },
    },
  ],

  overlay(ctx, t, W, H) {
    const s = W / 1280;
    if (t >= 8.3 && t < 9.8) {
      const a = t < 8.5 ? (t - 8.3) / 0.2 : (t > 9.6 ? (9.8 - t) / 0.2 : 1);
      ctx.globalAlpha = clamp(a, 0, 1);
      ctx.textAlign = 'center';
      ctx.fillStyle = '#e7e2d3';
      ctx.font = `${22 * s}px "Special Elite"`;
      ctx.fillText('THE DOOR SEALED BEHIND US.', W / 2, H - 64 * s);
      ctx.globalAlpha = 1;
    }
  },
};
