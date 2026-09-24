// s04_airlock — 10s. Blast door slams shut behind the team, power dies, red beacon kicks in.
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const mix = (a, b, t) => a + (b - a) * t;

function doorAngle(t) {
  const OPEN = 1.3;
  if (t < 4.0) return OPEN + Math.sin(t * 3.1) * 0.01; // resting open, tiny sway
  if (t < 6.0) {
    const e = smooth(4.0, 5.85, t);
    let a = mix(OPEN, 0.0, e);
    a += Math.sin(t * 45.0) * 0.02 * (1 - e); // grinding judder
    return Math.max(0, a);
  }
  return 0.0;
}

function lockBar(t) {
  const s0 = smooth(6.05, 6.15, t);
  const s1 = smooth(6.25, 6.35, t);
  const s2 = smooth(6.45, 6.58, t);
  return clamp(s0 * 0.34 + s1 * 0.34 + s2 * 0.34, 0, 1);
}

function powerOn(t) {
  if (t < 6.75) return 1.0;
  if (t < 7.0) return mix(1.0, 0.0, smooth(6.75, 6.95, t)) * (0.6 + 0.4 * Math.sin(t * 60.0));
  if (t < 8.0) return 0.0;
  if (t < 8.15) return 0.35 * (0.5 + 0.5 * Math.sin(t * 70.0)); // failed fluorescent stab
  return 0.0;
}

function beaconOn(t) {
  return smooth(8.0, 8.25, t);
}

function dustOpacity(t) {
  if (t < 4.0) return 0;
  if (t < 6.0) return 0.1 * smooth(4.0, 4.5, t);
  const e = t - 6.0;
  return clamp(1.0 * Math.exp(-e * 3.2), 0, 1);
}

export default {
  duration: 10,
  fps: 24,
  sceneScale: 0.5,

  params(t) {
    return [doorAngle(t), lockBar(t), powerOn(t), beaconOn(t), dustOpacity(t)];
  },

  post(t) {
    let shake = 0.035;
    if (t >= 4.0 && t < 6.0) shake = 0.16;
    if (t >= 6.0) shake = Math.max(0.035, 1.15 * Math.exp(-(t - 6.0) * 7.5));
    const dark = t >= 7.0 && t < 8.0;
    const beacon = beaconOn(t);
    const temp = mix(-0.6, 2.0, beacon);
    const flash = (t >= 5.98 && t < 6.1) ? mix(0, 0.16, 1 - Math.abs(t - 6.02) / 0.07) : 0;
    return {
      bar: 0.12,
      grain: 0.08,
      vignette: 1.1,
      shake,
      exposure: dark ? 0.85 : 1.05,
      temp,
      flash,
      flashColor: [1, 0.9, 0.75],
      bloom: 0.32,
      contrast: 1.16,
      sat: beacon > 0.5 ? 0.8 : 0.92,
    };
  },

  textures: [
    {
      w: 1024, h: 320,
      draw(ctx, w, h) {
        ctx.fillStyle = '#141310';
        ctx.fillRect(0, 0, w, h);
        // worn stencil plate grime
        for (let i = 0; i < 900; i++) {
          const x = Math.random() * w, y = Math.random() * h;
          ctx.fillStyle = `rgba(${Math.random()>.5?255:0},${Math.random()>.5?255:0},${Math.random()>.5?255:0},${Math.random()*0.04})`;
          ctx.fillRect(x, y, 2, 2);
        }
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#d8cfa8';
        ctx.font = 'bold 92px "Russo One"';
        ctx.fillText('ВЫХОД ЗАПРЕЩЁН', w / 2, h / 2 + 8);
        // stencil break gaps
        ctx.globalCompositeOperation = 'destination-out';
        for (let i = 0; i < 40; i++) {
          ctx.fillStyle = 'rgba(0,0,0,1)';
          ctx.fillRect(Math.random() * w, h * 0.25 + Math.random() * h * 0.5, 3, 10);
        }
        ctx.globalCompositeOperation = 'source-over';
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
