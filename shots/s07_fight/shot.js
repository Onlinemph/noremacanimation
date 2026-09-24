// s07_fight — first person, KS-23, red-lit corridor. The staff charge.
// The fight is scripted here; shot.glsl carries the same monster timings (see MONSTER SCRIPT there),
// and cues.json is generated from this file by `node shots/s07_fight/make_cues.mjs`.

export const KS = [5.0, 9.6, 12.0, 15.6];                 // KS-23 shots (Hollis)
export const AK = [[6.55, 7.15], [13.0, 13.6]];            // AKS-74U bursts from the left (Volkov)
export const PPSH = [[10.4, 11.2]];                        // PPSh-41 burst from the left (Lundqvist)
export const FLARE = 18.3, FLARE_LAND = 19.2;
export const AK_RPM = 700, PPSH_RPM = 950;

const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

export function rounds() {
  const r = [];
  for (const [a, b] of AK) for (let t = a; t < b; t += 60 / AK_RPM) r.push({ t, gun: 'ak' });
  for (const [a, b] of PPSH) for (let t = a; t < b; t += 60 / PPSH_RPM) r.push({ t, gun: 'ppsh' });
  return r.sort((x, y) => x.t - y.t);
}
const ROUNDS = rounds();

// aim keyframes: where Hollis points the gun (world space)
const AIM = [
  [0.0, [0.0, 1.35, 16]], [3.6, [0.25, 1.3, 13.5]], [4.6, [0.3, 1.2, 10]], [5.0, [0.3, 1.15, 8.6]],
  [6.0, [-0.3, 1.25, 11]], [7.4, [0.6, 1.2, 9]], [8.6, [1.3, 1.2, 8]], [9.6, [0.45, 1.15, 5.6]],
  [10.6, [0, 1.25, 9]], [12.0, [0.05, 1.15, 6.6]], [13.2, [0.2, 1.3, 11]], [14.8, [-0.3, 1.3, 4]],
  [15.6, [-0.35, 1.35, 2.3]], [16.6, [0, 1.3, 8]], [18.2, [0, 1.35, 14]], [19.4, [-0.2, 1.1, 16]], [24, [0, 1.2, 16.5]],
];
function aim(t) {
  for (let i = 0; i < AIM.length - 1; i++) {
    const [t0, a] = AIM[i], [t1, b] = AIM[i + 1];
    if (t >= t0 && t < t1) { const k = smooth(t0, t1, t); return a.map((v, j) => v + (b[j] - v) * k); }
  }
  return AIM[AIM.length - 1][1];
}

function ksState(t) {
  let flash = 0, recoil = 0, pump = 0;
  for (const s of KS) {
    const d = t - s;
    if (d >= 0 && d < 0.09) flash = Math.max(flash, 1 - d / 0.09);
    if (d >= 0 && d < 0.5) recoil = Math.max(recoil, d < 0.04 ? d / 0.04 : Math.exp(-(d - 0.04) * 9));
    if (d >= 0.3 && d < 0.72) pump = Math.max(pump, Math.sin(Math.PI * (d - 0.3) / 0.42));
  }
  return [flash, recoil, pump];
}
function leftGun(t) {
  let flash = 0, since = -1;
  for (const r of ROUNDS) {
    const d = t - r.t;
    if (d >= 0 && d < 0.035) flash = 1;
    if (d >= 0 && (since < 0 || d < since)) since = d;
  }
  return [flash, since];
}

export default {
  duration: 24,
  fps: 24,
  sceneScale: 0.7,

  params(t) {
    const [ksFlash, recoil, pump] = ksState(t);
    const [lf, since] = leftGun(t);
    const a = aim(t);
    const flareK = clamp((t - FLARE) / (FLARE_LAND - FLARE), 0, 1);
    const flareOn = t >= FLARE ? (t < FLARE_LAND ? 0.6 : 1) : 0;
    const lens = t >= 15.6 ? Math.min(1, (t - 15.6) / 0.05) : 0;
    const turn = smooth(21.2, 22.0, t), run = smooth(22.6, 23.2, t);
    return [ksFlash, pump, recoil, lf, since > 0.12 ? -1 : since, 0, flareOn, flareK, lens, turn, run, a[0], a[1], a[2], t, 0];
  },

  post(t) {
    const [ksFlash, recoil] = ksState(t);
    const [lf] = leftGun(t);
    const p = { bar: 0.12, grain: 0.09, vignette: 1.15, bloom: 0.55, aberr: 0.0018, temp: 0.05, contrast: 1.12, sat: 0.9, exposure: 1.1 };
    p.shake = 0.9 * recoil + 0.15 * lf + 0.04;
    p.flash = ksFlash * 0.07 + lf * 0.02;
    p.flashColor = [1, 0.75, 0.45];
    p.aberr += 0.004 * recoil;
    if (t >= 23.6) p.fade = 1;
    return p;
  },

  overlay(ctx, t, W, H) {
    // blood on the lens after the point-blank shot
    if (t < 15.6 || t >= 23.6) return;
    const s = W / 1280;
    const age = t - 15.6;
    const a = Math.min(1, age / 0.05) * (0.62 - 0.22 * Math.min(1, age / 8));
    const drops = [[0.62, 0.28, 60], [0.7, 0.4, 28], [0.55, 0.36, 22], [0.78, 0.22, 34], [0.48, 0.2, 16], [0.83, 0.5, 20], [0.66, 0.55, 12], [0.4, 0.3, 10]];
    ctx.save();
    ctx.globalAlpha = a;
    ctx.filter = `blur(${2 * s}px)`;
    drops.forEach(([x, y, r], i) => {
      const cx = x * W, cy = y * H, rr = r * s;
      ctx.fillStyle = 'rgba(70,4,4,0.9)';
      ctx.beginPath(); ctx.ellipse(cx, cy, rr, rr * 0.8, i, 0, Math.PI * 2); ctx.fill();
      // satellite spatter
      for (let k = 0; k < 6; k++) {
        const ang = i * 2.1 + k * 1.05, dist = rr * (1.2 + (k % 3) * 0.5);
        ctx.beginPath(); ctx.arc(cx + Math.cos(ang) * dist, cy + Math.sin(ang) * dist, rr * 0.12 * (1 + (k % 2)), 0, 7); ctx.fill();
      }
      // drips running down the glass
      const run = Math.min(1, age / 3) * rr * (2 + (i % 3));
      ctx.fillRect(cx - rr * 0.12, cy, rr * 0.24, run);
      ctx.beginPath(); ctx.arc(cx, cy + run, rr * 0.16, 0, 7); ctx.fill();
    });
    // a faint highlight so it reads as liquid on glass
    ctx.filter = 'none';
    ctx.globalAlpha = a * 0.25;
    ctx.fillStyle = 'rgba(255,200,180,1)';
    drops.slice(0, 4).forEach(([x, y, r]) => { ctx.beginPath(); ctx.arc(x * W - r * s * 0.3, y * H - r * s * 0.3, r * s * 0.18, 0, 7); ctx.fill(); });
    ctx.restore();
  },
};
