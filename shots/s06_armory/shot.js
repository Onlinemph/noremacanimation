// s06_armory — 18s. 0-6s: KS-23 on the table under the swinging bulb, pump racks ~4.5s.
// 6-18s: five character/weapon cards, Soviet technical-manual style, Canvas2D over a
// dimmed/blurred hold of the 3D scene.

function pumpEnvelope(t) {
  const t0 = 4.15, t1 = 4.45, t2 = 4.8;
  if (t < t0 || t > t2) return 0;
  if (t < t1) return (t - t0) / (t1 - t0);
  return 1 - (t - t1) / (t2 - t1);
}

// ---------------------------------------------------------------- textures --
function drawStar(ctx, cx, cy, r, color, alpha) {
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = color;
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rad = i % 2 === 0 ? r : r * 0.42;
    const x = cx + Math.cos(a) * rad, y = cy + Math.sin(a) * rad;
    i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function backWallTexture(ctx, w, h) {
  ctx.clearRect(0, 0, w, h);
  // red star, left of the stencil
  drawStar(ctx, w * 0.24, h * 0.38, w * 0.075, '#9c1c1c', 0.92);
  drawStar(ctx, w * 0.24, h * 0.38, w * 0.075, '#000', 0.15);

  // stencilled ОРУЖЕЙНАЯ across the middle, painted rough
  ctx.save();
  ctx.font = `${Math.round(h * 0.12)}px "Russo One"`;
  ctx.textBaseline = 'middle';
  ctx.textAlign = 'left';
  const label = 'ОРУЖЕЙНАЯ';
  let lx = w * 0.36, ly = h * 0.40;
  ctx.letterSpacing = `${Math.round(w * 0.012)}px`;
  for (let pass = 0; pass < 3; pass++) {
    ctx.globalAlpha = pass === 0 ? 0.82 : 0.10;
    ctx.fillStyle = '#d9d2c0';
    ctx.fillText(label, lx + (pass ? (Math.random() - 0.5) * 4 : 0), ly);
  }
  ctx.globalAlpha = 1;
  ctx.restore();
  // paint drips under the stencil
  ctx.save();
  ctx.fillStyle = 'rgba(180,172,150,0.5)';
  for (let i = 0; i < 14; i++) {
    const x = lx + Math.random() * w * 0.55;
    const len = h * (0.03 + Math.random() * 0.08);
    ctx.fillRect(x, ly + h * 0.05, 2, len);
  }
  ctx.restore();

  // torn poster, lower-right: faded Soviet propaganda placard
  ctx.save();
  ctx.translate(w * 0.90, h * 0.78);
  ctx.rotate(-0.04);
  const pw = w * 0.26, ph = h * 0.42;
  ctx.beginPath();
  ctx.moveTo(-pw / 2, -ph / 2);
  ctx.lineTo(pw * 0.1, -ph / 2 + 6);
  ctx.lineTo(pw / 2, -ph / 2 - 4);
  ctx.lineTo(pw / 2 - 8, ph * 0.1);
  ctx.lineTo(pw / 2, ph / 2);
  ctx.lineTo(-pw * 0.05, ph / 2 - 14);
  ctx.lineTo(-pw / 2, ph / 2);
  ctx.lineTo(-pw / 2 + 10, ph * 0.15);
  ctx.closePath();
  ctx.fillStyle = '#7a2222';
  ctx.globalAlpha = 0.55;
  ctx.fill();
  ctx.globalAlpha = 0.85;
  ctx.fillStyle = '#e7d9b0';
  ctx.font = `bold ${Math.round(ph * 0.16)}px "Russo One"`;
  ctx.textAlign = 'center';
  ctx.fillText('СССР', 0, -ph * 0.1);
  ctx.font = `${Math.round(ph * 0.07)}px "Oswald"`;
  ctx.fillText('ВПЕРЁД', 0, ph * 0.08);
  ctx.restore();

  // general grime speckle
  ctx.save();
  ctx.globalAlpha = 0.06;
  ctx.fillStyle = '#000';
  for (let i = 0; i < 400; i++) {
    ctx.fillRect(Math.random() * w, Math.random() * h, 2, 2);
  }
  ctx.restore();
}

function crateStencilTexture(ctx, w, h) {
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  ctx.translate(w / 2, h / 2);
  ctx.globalAlpha = 0.88;
  ctx.fillStyle = '#160f08';
  ctx.strokeStyle = '#160f08';
  ctx.lineWidth = w * 0.012;
  ctx.strokeRect(-w * 0.36, -h * 0.30, w * 0.72, h * 0.60);
  ctx.font = `bold ${Math.round(h * 0.22)}px "PT Mono"`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('1944', 0, -h * 0.02);
  ctx.font = `${Math.round(h * 0.075)}px "PT Mono"`;
  ctx.fillText('МО СССР', 0, h * 0.20);
  drawStar(ctx, 0, -h * 0.30, h * 0.05, '#160f08', 0.9);
  ctx.restore();
}

// ------------------------------------------------------------ card drawing --
const CARDS = [
  { key: 'ks23', ru: 'КС-23', en: 'KS-23', spec: '23×75 mm · pump action',
    person: 'DR. ELLEN HOLLIS', role: 'glaciologist', extra: null },
  { key: 'aks74u', ru: 'АКС-74У', en: 'AKS-74U', spec: '5.45×39 mm · folding stock',
    person: 'Ml. SGT. MIKHAIL "MISHA" VOLKOV', role: 'last of the garrison', extra: '+ РГД-5 / RGD-5 grenades' },
  { key: 'ppsh41', ru: 'ППШ-41', en: 'PPSh-41', spec: '7.62×25 mm · drum · reserve stock, 1944',
    person: 'ANDERS LUNDQVIST', role: 'mechanic', extra: null },
  { key: 'spsh', ru: 'СПШ', en: 'SPSh flare pistol', spec: '26 mm + fire axe',
    person: 'RAY OKAFOR', role: 'radio operator', extra: null },
  { key: 'pm', ru: 'ПМ', en: 'Makarov PM', spec: '9×18 mm',
    person: '(spare.)', role: 'Nobody wants to think about what it’s for.', extra: null, dim: true },
];

// side-profile silhouettes, muzzle to the right (+x), drawn in local "gun units"
const GUNS = {
  ks23: [[100,-6],[40,-6],[40,-15],[10,-17],[-2,-19],[-38,-7],[-41,-7],[-41,11],
         [-37,15],[-16,15],[-5,18],[1,30],[9,24],[10,11],[30,15],[40,11],[85,11],[100,6]],
  aks74u: [[60,-4],[50,-11],[38,-11],[38,-5],[19,-7],[19,-11],[-6,-11],[-6,-14],[-9,-14],[-9,-9],
           [-11,-8],[-35,-2],[-35,11],[-11,5],[-11,7],[1,7],[13,29],[19,11],[19,6],[38,1],[60,2]],
  spsh: [[38,-9],[30,-11],[15,-14],[5,-13],[0,-10],[-14,10],[-16,15],[-6,16],[0,14],[10,6],
         [10,4],[30,0],[38,-2]],
  pm: [[34,-9],[16,-10],[6,-10],[4,-14],[0,-10],[-3,-8],[-11,13],[-13,17],[-3,17],[2,14],
       [10,6],[10,4],[28,2],[34,-4]],
};

function strokePoly(ctx, pts, cx, cy, s) {
  ctx.beginPath();
  pts.forEach((pt, i) => {
    const x = cx + pt[0] * s, y = cy + pt[1] * s;
    i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
  });
  ctx.closePath();
}

function drawGun(ctx, key, cx, cy, s, ink) {
  ctx.save();
  ctx.fillStyle = ink;
  ctx.strokeStyle = ink;
  ctx.lineJoin = 'round';
  if (key === 'ppsh41') {
    // barrel jacket + wood stock outline (drum drawn separately below)
    const pts = [[75,-15],[68,-19],[68,-14],[25,-14],[25,-10],[-10,-8],[-40,-4],[-52,3],[-58,3],
                 [-58,16],[-54,20],[-16,20],[-16,10],[4,6],[25,-2],[68,-2],[75,-2]];
    strokePoly(ctx, pts, cx, cy, s);
    ctx.fill();
    // drum magazine
    ctx.beginPath();
    ctx.arc(cx + 4 * s, cy + 16 * s, 15 * s, 0, Math.PI * 2);
    ctx.fill();
    // perforations on the barrel jacket
    ctx.fillStyle = 'rgba(0,0,0,0)';
    ctx.save();
    ctx.globalCompositeOperation = 'destination-out';
    for (let i = 0; i < 6; i++) {
      ctx.beginPath();
      ctx.arc(cx + (30 + i * 6) * s, cy - 9 * s, 1.6 * s, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
    ctx.restore();
    return;
  }
  const pts = GUNS[key];
  strokePoly(ctx, pts, cx, cy, s);
  ctx.fill();
  if (key === 'aks74u') {
    // curved banana magazine
    ctx.beginPath();
    ctx.moveTo(cx + 1 * s, cy + 7 * s);
    ctx.quadraticCurveTo(cx + 16 * s, cy + 16 * s, cx + 13 * s, cy + 29 * s);
    ctx.quadraticCurveTo(cx + 9 * s, cy + 20 * s, cx - 2 * s, cy + 12 * s);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
}

function drawAxe(ctx, cx, cy, s, ink) {
  ctx.save();
  ctx.fillStyle = ink;
  ctx.strokeStyle = ink;
  ctx.lineWidth = 3 * s;
  ctx.beginPath();
  ctx.moveTo(cx, cy - 30 * s);
  ctx.lineTo(cx, cy + 30 * s);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(cx, cy - 28 * s);
  ctx.lineTo(cx + 20 * s, cy - 22 * s);
  ctx.lineTo(cx + 20 * s, cy - 8 * s);
  ctx.lineTo(cx, cy - 12 * s);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function stamp(ctx, cx, cy, scale, alpha, W) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(-0.24);
  ctx.scale(scale, scale);
  ctx.globalAlpha = alpha * 0.85;
  ctx.strokeStyle = '#a11c1c';
  ctx.fillStyle = '#a11c1c';
  ctx.lineWidth = 3 * (W / 1280);
  const rw = 250 * (W / 1280), rh = 62 * (W / 1280);
  ctx.strokeRect(-rw / 2, -rh / 2, rw, rh);
  ctx.font = `bold ${Math.round(15 * (W / 1280))}px "Special Elite"`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('СОВЕРШЕННО СЕКРЕТНО', 0, 0);
  ctx.restore();
}

function drawCard(ctx, card, ct, s, W, H, idx) {
  const enter = Math.min(1, ct / 0.22);
  const ease = 1 - Math.pow(1 - enter, 3);
  const slide = (1 - ease) * 160 * s;

  const cx = W * 0.5 + slide, cy = H * 0.52;
  const cw = 980 * s, ch = 480 * s;

  ctx.save();
  ctx.globalAlpha = ease;
  // card panel
  ctx.fillStyle = '#c9bd9c';
  ctx.strokeStyle = '#2a2318';
  ctx.lineWidth = 3 * s;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(-0.012);
  ctx.fillRect(-cw / 2, -ch / 2, cw, ch);
  ctx.strokeRect(-cw / 2, -ch / 2, cw, ch);
  ctx.strokeRect(-cw / 2 + 10 * s, -ch / 2 + 10 * s, cw - 20 * s, ch - 20 * s);

  // faint paper grain
  ctx.globalAlpha = ease * 0.06;
  ctx.fillStyle = '#000';
  for (let i = 0; i < 150; i++) {
    ctx.fillRect((Math.random() - 0.5) * cw, (Math.random() - 0.5) * ch, 1.5 * s, 1.5 * s);
  }
  ctx.globalAlpha = ease;

  // gun silhouette, left side
  const gx = -cw * 0.27, gy = -ch * 0.12;
  const gscale = card.key === 'ks23' ? 2.5 * s : card.key === 'pm' ? 4.0 * s : 3.1 * s;
  drawGun(ctx, card.key, gx, gy, gscale, '#241d12');
  if (card.key === 'spsh') drawAxe(ctx, gx + 130 * s, gy, 1.0 * s, '#241d12');

  // designation block, right side
  const tx = cw * 0.06, ty0 = -ch * 0.30;
  ctx.textAlign = 'left';
  ctx.fillStyle = '#241d12';
  ctx.font = `${Math.round(46 * s)}px "Russo One"`;
  ctx.fillText(card.ru, tx, ty0);
  ctx.font = `${Math.round(24 * s)}px "Oswald"`;
  ctx.fillText(card.en.toUpperCase(), tx, ty0 + 40 * s);
  ctx.font = `${Math.round(19 * s)}px "PT Mono"`;
  ctx.fillStyle = '#453a24';
  ctx.fillText(card.spec, tx, ty0 + 78 * s);
  if (card.extra) ctx.fillText(card.extra, tx, ty0 + 104 * s);

  // rule
  ctx.strokeStyle = '#5a4c30';
  ctx.lineWidth = 1.5 * s;
  ctx.beginPath();
  ctx.moveTo(tx, ty0 + 128 * s);
  ctx.lineTo(cw * 0.44, ty0 + 128 * s);
  ctx.stroke();

  // assigned to: typewriter reveal
  ctx.font = `${Math.round(17 * s)}px "Special Elite"`;
  ctx.fillStyle = '#2a2318';
  ctx.fillText('ВЫДАНО / ISSUED TO:', tx, ty0 + 160 * s);
  const full = card.person;
  const reveal = Math.max(0, Math.min(1, (ct - 0.30) / 0.9));
  const n = Math.round(full.length * reveal);
  const shown = full.slice(0, n);
  ctx.font = `${Math.round(24 * s)}px "Special Elite"`;
  ctx.fillText(shown + (reveal < 1 ? '_' : ''), tx, ty0 + 196 * s);
  if (reveal > 0.55) {
    ctx.globalAlpha = ease * Math.min(1, (reveal - 0.55) / 0.3);
    ctx.font = `italic ${Math.round(18 * s)}px "Special Elite"`;
    ctx.fillStyle = '#453a24';
    ctx.fillText(card.role, tx, ty0 + 224 * s);
    ctx.globalAlpha = ease;
  }

  // stamp near the end of the card
  const stampA = Math.max(0, Math.min(1, (ct - 1.5) / 0.25));
  stamp(ctx, cw * 0.30, ch * 0.30, 1.0, stampA, W);

  ctx.restore(); // card transform
  ctx.restore(); // alpha
}

export default {
  duration: 18,
  post(t) {
    const base = {
      bar: 0.12, grain: 0.07, aberr: 0.0016, vignette: 0.95, bloom: 0.4,
      contrast: 1.08, sat: 0.92, temp: -0.05,
    };
    if (t < 6) return { ...base, exposure: 1.5 };
    // dim the 3D scene during the card sequence; snap-flash on each transition
    const local = t - 6, idx = Math.min(4, Math.floor(local / 2.4)), ct = local - idx * 2.4;
    const flash = ct < 0.06 ? 1 - ct / 0.06 : 0;
    return { ...base, exposure: 0.5, flash: flash * 0.8, flashColor: [1, 0.95, 0.85] };
  },
  params(t) {
    return [pumpEnvelope(t), 1];
  },
  textures: [
    { w: 1160, h: 1000, draw: backWallTexture },
    { w: 512, h: 512, draw: crateStencilTexture },
  ],
  overlay(ctx, t, W, H) {
    if (t < 6) return;
    const s = W / 1280;
    // blur + dim the composited 3D frame in place, so the scene reads behind the card
    try {
      ctx.filter = 'blur(' + Math.round(14 * s) + 'px) brightness(0.4) saturate(0.65)';
      ctx.drawImage(ctx.canvas, 0, 0);
      ctx.filter = 'none';
    } catch (e) { /* canvas filter unsupported: fall back to a flat dim */ }
    ctx.fillStyle = 'rgba(6,7,9,0.42)';
    ctx.fillRect(0, 0, W, H);

    const local = t - 6, idx = Math.min(4, Math.floor(local / 2.4)), ct = local - idx * 2.4;
    drawCard(ctx, CARDS[idx], ct, s, W, H, idx);

    // shutter-close flash frame at each cut
    if (ct < 0.05) {
      ctx.fillStyle = `rgba(255,250,240,${(1 - ct / 0.05) * 0.7})`;
      ctx.fillRect(0, 0, W, H);
    }
  },
};
