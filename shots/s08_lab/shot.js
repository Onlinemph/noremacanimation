// s08_lab — the discovery. Specimen tanks, a Soviet report, a tank bursts.
export default {
  duration: 13,
  fps: 24,
  sceneScale: 0.75,
  params: t => [0,0,0,0,0,1],

  post(t) {
    const burstFlash = t >= 10.2 && t < 10.45 ? (1 - (t - 10.2) / 0.25) : 0;
    return {
      bar: 0.12,
      grain: 0.07,
      aberr: 0.0016,
      vignette: 1.0,
      bloom: 0.5,
      exposure: t >= 10.2 && t < 10.6 ? 1.5 : 1.0,
      temp: -0.25,
      contrast: 1.08,
      sat: t >= 10.2 && t < 10.6 ? 1.15 : 0.92,
      shake: t >= 10.0 && t < 11.2 ? (t < 10.2 ? 1.2 : 3.5) : 0.15,
      flash: burstFlash * 0.8,
      flashColor: [0.75, 1.0, 0.7],
      fade: t >= 11.2 ? 1 : 0,
      scan: 0,
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
    const s = W / 1280;
    // document close-up, ~3-6.2s
    const on = t > 2.8 && t < 6.4;
    if (on) {
      const inK = Math.min(1, (t - 2.8) / 0.5);
      const outK = Math.min(1, Math.max(0, (t - 5.9) / 0.5));
      const a = Math.min(inK, 1 - outK);
      if (a > 0.01) {
        ctx.save();
        ctx.globalAlpha = a;
        const w = 620 * s, h = 760 * s;
        const x = W / 2 - w / 2, y = H / 2 - h / 2 - 10 * s;
        ctx.fillStyle = '#d8d0b6';
        ctx.fillRect(x, y, w, h);
        ctx.strokeStyle = 'rgba(0,0,0,.4)'; ctx.lineWidth = 2 * s; ctx.strokeRect(x, y, w, h);
        // grime
        for (let i = 0; i < 1200; i++) {
          ctx.fillStyle = `rgba(70,60,40,${Math.random() * 0.06})`;
          ctx.fillRect(x + Math.random() * w, y + Math.random() * h, 2, 2);
        }
        // top secret stamp
        ctx.save();
        ctx.translate(x + w * 0.72, y + h * 0.14);
        ctx.rotate(-0.2);
        ctx.strokeStyle = '#8a1c1c'; ctx.lineWidth = 3 * s;
        ctx.strokeRect(-95 * s, -22 * s, 190 * s, 44 * s);
        ctx.fillStyle = 'rgba(138,28,28,0.9)';
        ctx.font = `bold ${20 * s}px "Oswald"`;
        ctx.textAlign = 'center';
        ctx.fillText('СОВЕРШЕННО', 0, -2 * s);
        ctx.fillText('СЕКРЕТНО', 0, 18 * s);
        ctx.restore();
        ctx.textAlign = 'left';

        ctx.fillStyle = '#1a1a16';
        ctx.font = `${26 * s}px "PT Mono"`;
        ctx.fillText('ОБРАЗЕЦ 9-А. ПОДЛЁДНОЕ ОЗЕРО.', x + 30 * s, y + 60 * s);
        ctx.fillText('ГЛУБИНА 3700 М', x + 30 * s, y + 92 * s);
        ctx.font = `italic ${17 * s}px "PT Mono"`;
        ctx.fillStyle = '#4a4436';
        ctx.fillText('Sample 9-A. Subglacial lake.', x + 30 * s, y + 122 * s);
        ctx.fillText('Depth 3,700 m.', x + 30 * s, y + 144 * s);

        // grainy "photo" of the drill site
        const px = x + 30 * s, py = y + 180 * s, pw = w - 60 * s, ph = 260 * s;
        ctx.fillStyle = '#0c0f10'; ctx.fillRect(px, py, pw, ph);
        ctx.save();
        ctx.beginPath(); ctx.rect(px, py, pw, ph); ctx.clip();
        ctx.strokeStyle = 'rgba(150,170,180,.5)'; ctx.lineWidth = 2 * s;
        ctx.beginPath(); ctx.moveTo(px + pw * 0.5, py + ph); ctx.lineTo(px + pw * 0.5, py + ph * 0.25);
        ctx.lineTo(px + pw * 0.35, py); ctx.stroke();
        ctx.beginPath(); ctx.arc(px + pw * 0.5, py + ph * 0.22, pw * 0.16, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(150,170,180,.35)'; ctx.stroke();
        for (let i = 0; i < 3000; i++) {
          const b = Math.random() * 0.5 + Math.random() * 0.15;
          ctx.fillStyle = `rgba(${180 * b},${190 * b},${195 * b},${Math.random() * 0.5})`;
          ctx.fillRect(px + Math.random() * pw, py + Math.random() * ph, 1.4, 1.4);
        }
        ctx.restore();
        ctx.font = `${13 * s}px "PT Mono"`;
        ctx.fillStyle = '#3a352a';
        ctx.fillText('БУРОВАЯ ПЛОЩАДКА — Т9', px, py + ph + 20 * s);

        ctx.restore();
      }
    }

    // hard cut hold-black title beat isn't needed here; the fade handles it.
  },
};
