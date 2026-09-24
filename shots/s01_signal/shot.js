// s01_signal (0-12s) — black typewriter slate, then a green CRT decoding the distress call.

function hash(n) { const s = Math.sin(n) * 43758.5453; return s - Math.floor(s); }

// ---- typewriter slate --------------------------------------------------
const SLATE_LINES = [
  'AMUNDSEN–SCOTT SOUTH POLE STATION',
  '21 JUNE 1989 — MIDWINTER',
  '02:47 LOCAL',
];
// per-character reveal times, irregular rhythm (precomputed, deterministic)
const CHAR_T = (() => {
  let t = 0.25, times = [], gi = 0;
  for (const line of SLATE_LINES) {
    for (let ci = 0; ci < line.length; ci++) {
      t += 0.022 + hash(gi * 3.7 + 1.1) * 0.045;
      times.push(t);
      gi++;
    }
    t += 0.18;
  }
  return times;
})();
const SLATE_END = CHAR_T[CHAR_T.length - 1]; // ~3.74

// ---- decoded radio lines -------------------------------------------------
const LINES = [
  { ru: 'ЭТО ОБЪЕКТ 9...', en: 'THIS IS OBJECT 9', start: 5.0, glitch: 0.6 },
  { ru: 'ПОМОГИТЕ НАМ', en: 'HELP US', start: 6.9, glitch: 0.55 },
  { ru: 'НЕ ОТКРЫВАЙТЕ ДВЕРЬ', en: 'DO NOT OPEN THE DOOR', start: 8.8, glitch: 0.6, stinger: 9.4 },
  { ru: null, en: 'BEARING 212° — 340 KM. NOTHING ON ANY MAP.', start: 10.7, glitch: 0.5 },
];
const GLYPHS = '01#%&*■□▓▒░ЯЖФЩЪЫЭЮАБВГДЕЁЖЗИЙabcdefghijklmnopqrstuvwxyz';
function glitchChar(seed) { return GLYPHS[Math.floor(hash(seed) * GLYPHS.length)] || '#'; }

function lineActiveInfo(t) {
  let active = null, idx = -1;
  for (let i = 0; i < LINES.length; i++) {
    const L = LINES[i];
    const nextStart = LINES[i + 1] ? LINES[i + 1].start : 11.6;
    if (t >= L.start - 0.02 && t < nextStart) { active = L; idx = i; break; }
  }
  return { active, idx };
}

function drawMonoLine(ctx, text, x, y, size, revealProgress, tSeed, resolvedColor) {
  ctx.font = `${size}px "Share Tech Mono"`;
  ctx.textBaseline = 'alphabetic';
  const adv = size * 0.62;
  const n = text.length;
  for (let i = 0; i < n; i++) {
    const ch = text[i];
    const thresh = (i / n) * 0.8 + hash(i * 12.9 + 1) * 0.2;
    let out = ch;
    let resolved = true;
    if (ch !== ' ' && revealProgress < thresh) {
      out = glitchChar(tSeed + i * 7.7);
      resolved = false;
    }
    ctx.fillStyle = resolved ? resolvedColor : 'rgba(120,255,150,0.55)';
    if (!resolved) { ctx.font = `${size}px "Share Tech Mono"`; }
    ctx.fillText(out, x + i * adv, y);
  }
  return x + n * adv;
}

export default {
  duration: 12,
  fps: 24,

  post(t) {
    const p = { bar: 0.12 };
    if (t < 4.4) {
      Object.assign(p, { grain: 0.055, vignette: 0.95, bloom: 0.12, scan: 0, aberr: 0.0008 });
      let fade = 0;
      if (t > 3.9 && t < 4.3) fade = (t - 3.9) / 0.4;
      else if (t >= 4.3) fade = Math.max(0, 1 - (t - 4.3) / 0.3);
      p.fade = fade;
    } else {
      Object.assign(p, { grain: 0.07, vignette: 1.0, bloom: 0.55, scan: 0.5, aberr: 0.0018, temp: -0.12, contrast: 1.08 });
      let fade = 0;
      if (t < 4.7) fade = Math.max(0, 1 - (t - 4.35) / 0.35);
      if (t > 11.5) fade = Math.min(1, (t - 11.5) / 0.5);
      p.fade = fade;
    }
    return p;
  },

  overlay(ctx, t, W, H) {
    const s = W / 1280;

    if (t < 4.4) {
      // typewriter slate, lower-left third
      const x0 = 92 * s, y0 = H * 0.60, lh = 36 * s, size = 24 * s;
      ctx.textBaseline = 'alphabetic';
      ctx.fillStyle = 'rgba(226,222,210,0.92)';
      ctx.font = `${size}px "Special Elite"`;
      let gi = 0, cursorX = x0, cursorY = y0;
      for (let li = 0; li < SLATE_LINES.length; li++) {
        const line = SLATE_LINES[li];
        let shown = '';
        for (let ci = 0; ci < line.length; ci++) {
          if (t >= CHAR_T[gi]) shown += line[ci];
          gi++;
        }
        const y = y0 + li * lh;
        ctx.fillStyle = 'rgba(226,222,210,0.92)';
        ctx.fillText(shown, x0, y);
        if (shown.length === line.length) { cursorY = y; cursorX = x0 + ctx.measureText(line).width; }
        else { cursorY = y; cursorX = x0 + ctx.measureText(shown).width; break; }
      }
      // blinking cursor at the current typing position
      if (Math.floor(t * 2.2) % 2 === 0) {
        ctx.fillStyle = 'rgba(226,222,210,0.85)';
        ctx.fillRect(cursorX + 3 * s, cursorY - size * 0.78, size * 0.5, size * 0.85);
      }
      return;
    }

    // decoded transmission text over the CRT
    const { active, idx } = lineActiveInfo(t);
    if (!active) return;
    const size = 22 * s;
    const xBase = W * 0.09;
    const yEn = H * 0.83;
    const yRu = H * 0.765;
    const local = t - active.start;
    const progress = Math.min(1, Math.max(0, local / active.glitch));
    const tSeed = Math.floor(t * 12) * 0.31 + idx * 91.7;

    if (active.ru) {
      const ruAlpha = 0.45 * (1 - progress) + 0.06;
      ctx.font = `${size * 0.82}px "PT Mono"`;
      ctx.fillStyle = `rgba(150,255,180,${ruAlpha.toFixed(3)})`;
      ctx.fillText(active.ru, xBase, yRu);
    }
    drawMonoLine(ctx, active.en, xBase, yEn, size, progress, tSeed, 'rgba(180,255,190,0.95)');

    // faint scanning cursor after the line has resolved
    if (progress >= 1 && Math.floor(t * 2.2) % 2 === 0) {
      const w = active.en.length * size * 0.62;
      ctx.fillStyle = 'rgba(180,255,190,0.7)';
      ctx.fillRect(xBase + w + 4 * s, yEn - size * 0.78, size * 0.5, size * 0.85);
    }
  },
};
