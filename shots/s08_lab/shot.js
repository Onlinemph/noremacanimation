// s08_lab — the discovery. Specimen tanks, a Soviet report, a tank bursts.
export default {
  duration: 13,
  fps: 24,
  sceneScale: 0.7,

  // uP[0] = 1 after the hard cut: skip the scene entirely
  params(t) { return [t >= 11.2 ? 1 : 0]; },

  post(t) {
    const B = 10.2;
    const b = t - B;
    const burst = t >= B && t < 11.2;
    return {
      bar: 0.12,
      grain: 0.075,
      aberr: burst ? 0.004 : 0.0017,
      vignette: 1.15,
      bloom: burst ? 0.5 : 0.4,
      exposure: 1.0 + (burst ? 0.35 * Math.exp(-b * 7) : 0),   // multiplicative pop: blacks stay black
      temp: -0.15,
      contrast: 1.1,
      sat: 0.95,
      shake: burst ? 2.2 * Math.exp(-b * 2.5) + 0.4 : (t > 8.9 && t < B ? 0.25 : 0.12),
      flash: 0,
      flashColor: [0.55, 1.0, 0.6],
      fade: t >= 11.2 ? 1 : 0,
      lift: [0, 0.01, 0.005],
    };
  },

  textures: [
    // iTex0: green CRT terminal text
    {
      w: 512, h: 512,
      draw(ctx, w, h) {
        ctx.fillStyle = '#000'; ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#3fe06a';
        ctx.font = '22px "Share Tech Mono"';
        const lines = [
          'ОБЪЕКТ 9 — ЛАБ. КОМПЛЕКС', '', '> ЖУРНАЛ НАБЛЮДЕНИЙ', '> ОБРАЗЕЦ 9-А .... АКТИВЕН',
          '> Т ВОДЫ ..... +2.1 C', '> ПУЛЬС ...... 118', '> ПОДЛЁДНОЕ ОЗЕРО', '> ГЛУБИНА 3700 М',
          '', '> ВНИМАНИЕ', '> ОБРАЗЕЦ РЕАГИРУЕТ', '> НА СВЕТ_', '_',
        ];
        let y = 50;
        for (const l of lines) { ctx.fillText(l, 24, y); y += 34; }
        ctx.globalAlpha = 0.15;
        for (let i = 0; i < h; i += 3) { ctx.fillRect(0, i, w, 1); }
      },
    },
    // iTex1: clipboard document (also the base for the close-up overlay art)
    {
      w: 512, h: 512,
      draw(ctx, w, h) {
        ctx.fillStyle = '#cfc7ad'; ctx.fillRect(0, 0, w, h);
        for (let i = 0; i < 4000; i++) {
          ctx.fillStyle = `rgba(90,80,60,${Math.random() * 0.08})`;
          ctx.fillRect(Math.random() * w, Math.random() * h, 1, 1);
        }
        ctx.fillStyle = '#1a1a1a';
        ctx.font = 'bold 20px "PT Mono"';
        ctx.fillText('ОБРАЗЕЦ 9-А', 24, 60);
        ctx.font = '14px "PT Mono"';
        ctx.fillText('ПОДЛЁДНОЕ ОЗЕРО', 24, 90);
        ctx.fillText('ГЛУБИНА 3700 М', 24, 110);
        ctx.strokeStyle = '#7a1414'; ctx.lineWidth = 3;
        ctx.save(); ctx.translate(380, 160); ctx.rotate(-0.25);
        ctx.strokeRect(-70, -22, 140, 44);
        ctx.fillStyle = 'rgba(122,20,20,0.85)'; ctx.font = 'bold 13px "Oswald"';
        ctx.fillText('СЕКРЕТНО', -58, -2); ctx.fillText('СЕКРЕТНО', -58, 16);
        ctx.restore();
        ctx.fillStyle = '#333'; ctx.fillRect(24, 200, 200, 140);
        ctx.fillStyle = '#111';
        for (let i = 0; i < 400; i++) ctx.fillRect(24 + Math.random() * 200, 200 + Math.random() * 140, 2, 2);
      },
    },
    // iTex2: stopped clock face
    {
      w: 256, h: 256,
      draw(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        ctx.strokeStyle = '#ddd'; ctx.lineWidth = 6;
        ctx.beginPath(); ctx.arc(w / 2, h / 2, 100, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = '#eee'; ctx.font = '18px "PT Mono"';
        for (let i = 1; i <= 12; i++) {
          const a = (i / 12) * Math.PI * 2 - Math.PI / 2;
          ctx.fillText(String(i), w / 2 + Math.cos(a) * 78 - 6, h / 2 + Math.sin(a) * 78 + 6);
        }
        ctx.strokeStyle = '#eee'; ctx.lineWidth = 4;
        ctx.beginPath(); ctx.moveTo(w / 2, h / 2); ctx.lineTo(w / 2 + 40, h / 2 - 20); ctx.stroke();
        ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(w / 2, h / 2); ctx.lineTo(w / 2 - 10, h / 2 + 55); ctx.stroke();
      },
    },
  ],

  overlay(ctx, t, W, H) {
    if (t >= 11.2) return;
    const s = W / 1280;
    // document insert, ~3.0-6.2 s, kept inside the letterbox
    const t0 = 2.9, t1 = 6.3;
    if (t < t0 || t > t1) return;
    const a = Math.min(1, (t - t0) / 0.45, (t1 - t) / 0.45);
    if (a <= 0.01) return;
    const bar = 0.12 * H;
    ctx.save();
    ctx.beginPath(); ctx.rect(0, bar, W, H - 2 * bar); ctx.clip();
    ctx.globalAlpha = a;
    ctx.fillStyle = 'rgba(0,0,0,0.62)';
    ctx.fillRect(0, bar, W, H - 2 * bar);
    // slow drift of the page under the torch
    const k = (t - t0) / (t1 - t0);
    const w = 520 * s, h = 470 * s;
    ctx.translate(W / 2 + (8 - 16 * k) * s, H / 2 + (12 - 10 * k) * s);
    ctx.rotate(-0.035 + 0.012 * k);
    ctx.scale(1 + 0.04 * k, 1 + 0.04 * k);
    const x = -w / 2, y = -h / 2;
    ctx.fillStyle = '#cfc6a8';
    ctx.fillRect(x, y, w, h);
    // grime, fold, coffee ring
    let seed = 7;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
    for (let i = 0; i < 1100; i++) {
      ctx.fillStyle = `rgba(70,60,40,${rnd() * 0.07})`;
      ctx.fillRect(x + rnd() * w, y + rnd() * h, 2 * s, 2 * s);
    }
    ctx.strokeStyle = 'rgba(90,70,40,0.18)'; ctx.lineWidth = 6 * s;
    ctx.beginPath(); ctx.arc(x + w * 0.82, y + h * 0.86, 34 * s, 0.3, 5.6); ctx.stroke();
    ctx.fillStyle = 'rgba(0,0,0,0.06)'; ctx.fillRect(x, y + h * 0.5, w, 2 * s);
    ctx.fillStyle = '#1a1a16';
    ctx.font = `${11 * s}px "PT Mono"`;
    ctx.fillText('МИНИСТЕРСТВО СРЕДНЕГО МАШИНОСТРОЕНИЯ СССР', x + 22 * s, y + 24 * s);
    ctx.fillText('ОБЪЕКТ 9 · ЛАБОРАТОРИЯ 3 · ПРОТОКОЛ № 41', x + 22 * s, y + 38 * s);
    ctx.fillRect(x + 22 * s, y + 46 * s, w - 44 * s, 1.2 * s);
    ctx.font = `bold ${21 * s}px "PT Mono"`;
    ctx.fillText('ОБРАЗЕЦ 9-А. ПОДЛЁДНОЕ ОЗЕРО.', x + 22 * s, y + 76 * s);
    ctx.fillText('ГЛУБИНА 3700 М', x + 22 * s, y + 101 * s);
    ctx.font = `italic ${13 * s}px "PT Mono"`;
    ctx.fillStyle = '#4a4436';
    ctx.fillText('Sample 9-A. Subglacial lake. Depth 3,700 m.', x + 22 * s, y + 122 * s);
    // stamp
    ctx.save();
    ctx.translate(x + w * 0.76, y + h * 0.2);
    ctx.rotate(-0.22);
    ctx.strokeStyle = 'rgba(138,28,28,0.85)'; ctx.lineWidth = 2.5 * s;
    ctx.strokeRect(-80 * s, -20 * s, 160 * s, 40 * s);
    ctx.fillStyle = 'rgba(138,28,28,0.85)';
    ctx.font = `bold ${16 * s}px "Oswald"`;
    ctx.textAlign = 'center';
    ctx.fillText('СОВЕРШЕННО', 0, -2 * s);
    ctx.fillText('СЕКРЕТНО', 0, 15 * s);
    ctx.restore();
    // photo: a figure in a specimen tank, paper-clipped
    const px = x + 22 * s, py = y + 140 * s, pw = 190 * s, ph = 230 * s;
    ctx.save();
    ctx.translate(px + pw / 2, py + ph / 2); ctx.rotate(0.03); ctx.translate(-pw / 2, -ph / 2);
    ctx.fillStyle = '#e9e4d6'; ctx.fillRect(-6 * s, -6 * s, pw + 12 * s, ph + 12 * s);
    ctx.fillStyle = '#0b0d0c'; ctx.fillRect(0, 0, pw, ph);
    const g = ctx.createRadialGradient(pw / 2, ph * 0.8, 4 * s, pw / 2, ph * 0.6, ph * 0.6);
    g.addColorStop(0, 'rgba(210,215,200,0.9)'); g.addColorStop(0.5, 'rgba(90,95,88,0.6)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g; ctx.fillRect(pw * 0.2, ph * 0.08, pw * 0.6, ph * 0.84);
    ctx.strokeStyle = 'rgba(220,225,215,0.5)'; ctx.lineWidth = 1.5 * s;
    ctx.strokeRect(pw * 0.2, ph * 0.08, pw * 0.6, ph * 0.84);
    // hunched silhouette
    ctx.fillStyle = '#060706';
    ctx.beginPath();
    ctx.ellipse(pw * 0.53, ph * 0.3, 11 * s, 14 * s, 0.4, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath();
    ctx.moveTo(pw * 0.44, ph * 0.36); ctx.quadraticCurveTo(pw * 0.36, ph * 0.55, pw * 0.44, ph * 0.72);
    ctx.lineTo(pw * 0.40, ph * 0.9); ctx.lineTo(pw * 0.47, ph * 0.9); ctx.lineTo(pw * 0.52, ph * 0.72);
    ctx.lineTo(pw * 0.58, ph * 0.9); ctx.lineTo(pw * 0.64, ph * 0.9); ctx.quadraticCurveTo(pw * 0.66, ph * 0.5, pw * 0.6, ph * 0.38);
    ctx.closePath(); ctx.fill();
    ctx.strokeStyle = '#060706'; ctx.lineWidth = 4 * s;
    ctx.beginPath(); ctx.moveTo(pw * 0.46, ph * 0.4); ctx.quadraticCurveTo(pw * 0.34, ph * 0.55, pw * 0.36, ph * 0.72); ctx.stroke();
    for (let i = 0; i < 900; i++) {
      const b = rnd();
      ctx.fillStyle = `rgba(${200 * b},${205 * b},${195 * b},${rnd() * 0.25})`;
      ctx.fillRect(rnd() * pw, rnd() * ph, 1.3 * s, 1.3 * s);
    }
    ctx.restore();
    ctx.fillStyle = '#777'; ctx.fillRect(px + 30 * s, py - 12 * s, 6 * s, 30 * s);   // paper clip
    ctx.fillStyle = '#3a352a';
    ctx.font = `${10 * s}px "PT Mono"`;
    ctx.fillText('РЕЗЕРВУАР 4 · 14.06.89', px, py + ph + 22 * s);
    // typed report lines
    ctx.fillStyle = '#1e1c16';
    ctx.font = `${12.5 * s}px "PT Mono"`;
    const lines = [
      'Извлечён с глубины 3700 м',
      'из подлёдного озера (скв. 9).',
      'Организм жизнеспособен при',
      '+2 °C. Проникает в ткани',
      'носителя в течение 6 часов.',
      'Носители сохраняют',
      'двигательную активность',
      'после клинической смерти.',
      '',
      'Реагирует на свет.',
      'НЕ ОТКРЫВАТЬ РЕЗЕРВУАРЫ.',
    ];
    let ly = py + 12 * s;
    for (const l of lines) { ctx.fillText(l, px + pw + 20 * s, ly); ly += 19 * s; }
    // redaction bar and handwritten note
    ctx.fillStyle = '#111'; ctx.fillRect(px + pw + 20 * s, py + 44 * s, 150 * s, 13 * s);
    ctx.fillStyle = 'rgba(40,40,110,0.8)';
    ctx.font = `italic ${15 * s}px "Special Elite"`;
    ctx.fillText('он смотрит на нас', px + pw + 24 * s, y + h - 36 * s);
    // cold torch falloff across the page
    const tg = ctx.createRadialGradient(-40 * s, -30 * s, 30 * s, 0, 0, w * 0.8);
    tg.addColorStop(0, 'rgba(0,0,0,0)'); tg.addColorStop(1, 'rgba(0,4,10,0.75)');
    ctx.fillStyle = tg; ctx.fillRect(x, y, w, h);
    ctx.fillStyle = 'rgba(120,150,200,0.06)'; ctx.fillRect(x, y, w, h);
    ctx.restore();
  },
};
