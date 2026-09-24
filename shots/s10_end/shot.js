// s10_end (0-15s) — burning Object 9 recedes behind the Kharkovchanka, then black, then the
// signal again (now from the Pole, in English first), then the title card.

function hash(n) { const s = Math.sin(n) * 43758.5453; return s - Math.floor(s); }

const LINES = [
  { en: 'THIS IS AMUNDSEN–SCOTT SOUTH POLE STATION', start: 7.8, glitch: 0.7 },
  { en: 'HELP US', start: 9.3, glitch: 0.5 },
  { en: 'DO NOT OPEN THE DOOR', start: 10.6, glitch: 0.6, stinger: 11.2 },
];
const GLYPHS = '01#%&*■□▓▒░ЯЖФЩЪЫЭЮАБВГДЕЁЖЗИЙabcdefghijklmnopqrstuvwxyz';
function glitchChar(seed) { return GLYPHS[Math.floor(hash(seed) * GLYPHS.length)] || '#'; }

function lineActiveInfo(t) {
  let active = null, idx = -1;
  for (let i = 0; i < LINES.length; i++) {
    const L = LINES[i];
    const nextStart = LINES[i + 1] ? LINES[i + 1].start : 12.8;
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
    let out = ch, resolved = true;
    if (ch !== ' ' && revealProgress < thresh) { out = glitchChar(tSeed + i * 7.7); resolved = false; }
    ctx.fillStyle = resolved ? resolvedColor : 'rgba(120,255,150,0.55)';
    ctx.fillText(out, x + i * adv, y);
  }
}

export default {
  duration: 15,
  fps: 24,
  sceneScale: 0.75,

  post(t) {
    const p = { bar: 0.12 };
    if (t < 7.0) {
      // exterior: cold grade, gentle drift, fading to black at the end
      Object.assign(p, { grain: 0.05, vignette: 1.05, bloom: 0.4, aberr: 0.0012, temp: -0.15, contrast: 1.05, sat: 0.95 });
      p.fade = t > 6.3 ? Math.min(1, (t - 6.3) / 0.7) : 0;
    } else if (t < 13.0) {
      Object.assign(p, { grain: 0.07, vignette: 1.0, bloom: 0.55, scan: 0.5, aberr: 0.0018, temp: -0.12, contrast: 1.08 });
      let fade = 0;
      if (t < 7.5) fade = 1 - Math.min(1, (t - 7.0) / 0.5);
      if (t > 12.6) fade = Math.min(1, (t - 12.6) / 0.4);
      p.fade = Math.max(0, fade);
    } else {
      Object.assign(p, { grain: 0.06, vignette: 0.9, bloom: 0.3, scan: 0, aberr: 0.0008, fade: 0 });
    }
    return p;
  },

  overlay(ctx, t, W, H) {
    const s = W / 1280;

    if (t >= 7.0 && t < 13.0) {
      const { active, idx } = lineActiveInfo(t);
      if (active) {
        const size = 22 * s;
        const xBase = W * 0.09, yEn = H * 0.83;
        const local = t - active.start;
        const progress = Math.min(1, Math.max(0, local / active.glitch));
        const tSeed = Math.floor(t * 12) * 0.31 + idx * 91.7;
        drawMonoLine(ctx, active.en, xBase, yEn, size, progress, tSeed, 'rgba(180,255,190,0.95)');
        if (progress >= 1 && Math.floor(t * 2.2) % 2 === 0) {
          const w = active.en.length * size * 0.62;
          ctx.fillStyle = 'rgba(180,255,190,0.7)';
          ctx.fillRect(xBase + w + 4 * s, yEn - size * 0.78, size * 0.5, size * 0.85);
        }
      }
      return;
    }

    if (t >= 13.0) {
      const local = t - 13.0;
      const alpha = Math.min(1, local / 0.6);
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      const bigSize = 92 * s;
      ctx.font = `${bigSize}px "Russo One"`;
      ctx.shadowColor = `rgba(200,30,20,${(0.75 * alpha).toFixed(3)})`;
      ctx.shadowBlur = 34 * s;
      ctx.fillStyle = `rgba(232,228,220,${alpha.toFixed(3)})`;
      ctx.fillText('ОБЪЕКТ 9', W * 0.5, H * 0.46);

      ctx.shadowBlur = 0;
      const smallSize = 26 * s;
      ctx.font = `${smallSize}px "Oswald"`;
      ctx.fillStyle = `rgba(200,196,190,${(alpha * 0.85).toFixed(3)})`;
      ctx.letterSpacing = `${6 * s}px`;
      ctx.fillText('OBJECT 9', W * 0.5, H * 0.58);
      ctx.letterSpacing = '0px';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'alphabetic';
    }
  },
};
