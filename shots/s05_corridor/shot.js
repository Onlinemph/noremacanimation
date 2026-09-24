// s05_corridor — 14s. Flickering fluorescent corridor, slow push, the figure gets closer every
// blackout. Final flicker: it's in the camera's face. Hard cut to black.
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const mix = (a, b, t) => a + (b - a) * t;

// deterministic pseudo-random in [0,1), pure function of an integer seed (no Math.random)
function h1(n) { const x = Math.sin(n * 12.9898) * 43758.5453; return x - Math.floor(x); }

// Reveal/blackout schedule. Each entry: [tBlackoutStart, tBlackoutEnd, monsterDistanceAtReturn]
const STAGES = [
  { revealAt: 0.0, dist: 30 },
  { blackout: [2.9, 3.35], revealAt: 3.35, dist: 15 },
  { blackout: [7.05, 7.5], revealAt: 7.5, dist: 8 },
  { blackout: [9.55, 9.95], revealAt: 9.95, dist: 4 },
  { blackout: [11.75, 12.2], revealAt: 12.2, dist: 2.3 }, // final: right in the face
];

function camZ(t) {
  const tc = Math.min(t, 12.2);
  return 0.30 * tc + 0.05 * Math.sin(tc * 0.7);
}

function monsterZ(t) {
  // find current stage (last one whose reveal/blackout-start has passed)
  let stage = STAGES[0];
  for (const s of STAGES) {
    const trigger = s.blackout ? s.blackout[0] : s.revealAt;
    if (t >= trigger) stage = s;
  }
  return camZ(stage.revealAt) + stage.dist;
}

// scripted, deterministic flicker: irregular but fully reproducible from t.
// Returns light intensity 0..1 for the whole corridor this frame.
function lightIntensity(t) {
  if (t >= 12.2 && t < 12.5) return 1.0; // the flash of the final reveal
  if (t >= 12.5) return 0.0;             // hard cut to black

  for (const s of STAGES) {
    if (s.blackout && t >= s.blackout[0] && t < s.blackout[1]) return 0.0;
  }
  // steady-ish base with an irregular flicker texture: sum of a few deterministic
  // "pulse" events, each a short dip, spaced using a hashed schedule.
  let base = 0.92;
  // scripted quick pre-blackout flicker bursts (announce each blackout)
  const preflicker = (start) => {
    if (t < start - 0.45 || t >= start) return 1;
    const local = (t - (start - 0.45)) / 0.45; // 0..1
    const n = Math.floor(local * 9);
    const on = h1(n + Math.floor(start * 100)) > 0.42;
    return on ? 1 : 0.12;
  };
  for (const s of STAGES) {
    if (s.blackout) base *= preflicker(s.blackout[0]);
  }
  // sparse irregular buzz-flicker dips through the "on" stretches (deterministic hash grid)
  const cell = Math.floor(t * 6.0);
  const cellT = t * 6.0 - cell;
  const dipRoll = h1(cell * 3.77 + 1.0);
  if (dipRoll > 0.86 && cellT < 0.35) base *= 0.25;
  else if (dipRoll > 0.7 && cellT < 0.12) base *= 0.55;
  return clamp(base, 0, 1);
}

function closeUpFactor(t) {
  if (t >= 12.15 && t < 12.5) return smooth(12.15, 12.25, t) * (1 - smooth(12.4, 12.5, t));
  return 0;
}

export default {
  duration: 14,
  fps: 24,
  sceneScale: 0.5,

  params(t) {
    return [lightIntensity(t), monsterZ(t), closeUpFactor(t), camZ(t)];
  },

  post(t) {
    const li = lightIntensity(t);
    const final = t >= 12.15 && t < 12.5;
    let fade = 0;
    if (t >= 12.5) fade = Math.min(1, (t - 12.5) / 0.15 + 0.85);
    if (t >= 12.65) fade = 1;
    const shake = final ? 0.5 : 0.03 + (li < 0.3 ? 0.05 : 0);
    return {
      bar: 0.12,
      grain: 0.075,
      vignette: 1.05,
      shake,
      exposure: final ? 1.1 : 0.98,
      contrast: final ? 1.15 : 1.15,
      sat: final ? 0.55 : 0.85,
      temp: -0.3,
      bloom: final ? 0.12 : 0.28,
      // a single sharp, small strobe right at the instant the lights snap back on
      flash: (t >= 12.2 && t < 12.22) ? 0.05 * (1 - (t - 12.2) / 0.02) : 0,
      flashColor: [1, 0.95, 0.9],
      fade,
    };
  },

  overlay() {},

  textures: [
    {
      w: 512, h: 640,
      draw(ctx, w, h) {
        ctx.fillStyle = '#7a1210';
        ctx.fillRect(0, 0, w, h);
        // faded/weathered paper texture
        for (let i = 0; i < 2500; i++) {
          const x = Math.random() * w, y = Math.random() * h;
          ctx.fillStyle = `rgba(0,0,0,${Math.random() * 0.12})`;
          ctx.fillRect(x, y, 2, 2);
        }
        ctx.strokeStyle = 'rgba(0,0,0,0.4)';
        ctx.lineWidth = 10;
        ctx.strokeRect(20, 20, w - 40, h - 40);
        ctx.textAlign = 'center';
        ctx.fillStyle = '#e8dcb0';
        ctx.font = 'bold 58px "Russo One"';
        ctx.fillText('СОВЕРШЕННО', w / 2, 220);
        ctx.fillText('СЕКРЕТНО', w / 2, 290);
        ctx.font = '30px "PT Mono"';
        ctx.fillStyle = '#d8c89a';
        ctx.fillText('ОБЪЕКТ 9', w / 2, 380);
        ctx.font = '22px "PT Mono"';
        wrapText(ctx, 'МИНИСТЕРСТВО СРЕДНЕГО', w / 2, 440, w - 80, 28);
        wrapText(ctx, 'МАШИНОСТРОЕНИЯ СССР', w / 2, 470, w - 80, 28);
        // water damage streak
        const grad = ctx.createLinearGradient(0, 0, 0, h);
        grad.addColorStop(0, 'rgba(0,0,0,0)');
        grad.addColorStop(1, 'rgba(0,0,0,0.35)');
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, w, h);

        function wrapText(c, text, x, y) { c.fillText(text, x, y); }
      },
    },
  ],
};
