// s07_fight — first-person KS-23 corridor firefight. See shot.glsl header for
// the full scripted timeline; every envelope below must stay in sync with it
// and with cues.json.

const KS23 = [5.00, 10.6, 14.2, 17.0];
const AK = [[8.4, .45], [11.6, .5], [15.3, .45]];
const PPSH = [[9.3, .4], [13.0, .45], [16.4, .4]];
const FLARE_LAUNCH = 18.3, FLARE_LAND = 19.6;
const TURN_T = 22.6;
const FADE_START = 22.8, FADE_END = 23.6;

// Ramps up to 1 *before* t0 so the scripted event frame itself (t0) is already
// at full strength (muzzle flashes/recoil must read on the exact cue frame).
function pulse(t, t0, attack, hold, decay) {
  if (t < t0 - attack) return 0;
  if (t < t0) return (t - (t0 - attack)) / attack;
  const dt = t - t0;
  if (dt < hold) return 1;
  const d = dt - hold;
  if (d < decay) return 1 - d / decay;
  return 0;
}
function tri(t, t0, dur) {
  if (t < t0 || t > t0 + dur) return 0;
  const x = (t - t0) / dur;
  return x < .5 ? x / .5 : (1 - x) / .5;
}
function maxOf(arr) { return arr.reduce((a, b) => Math.max(a, b), 0); }

function burstEnv(t, bursts, freq) {
  let v = 0;
  for (const [t0, dur] of bursts) {
    if (t < t0 || t > t0 + dur) continue;
    const edge = Math.min((t - t0) / .03, (t0 + dur - t) / .03, 1);
    v = Math.max(v, edge * (.55 + .45 * Math.abs(Math.sin((t - t0) * freq))));
  }
  return v;
}

export default {
  duration: 24,
  sceneScale: 0.75,

  params(t) {
    const recoilEnv = maxOf(KS23.map(s => pulse(t, s, .02, .03, .30)));
    const pumpEnv = maxOf(KS23.map(s => tri(t, s + .08, .35)));
    const muzzleFlashEnv = maxOf(KS23.map(s => pulse(t, s, .008, .02, .06)));
    const pointBlankEnv = pulse(t, 17.0, .01, .15, .5);
    const akFlashEnv = burstEnv(t, AK, 62);
    const ppshFlashEnv = burstEnv(t, PPSH, 85);
    const flareProgress = t < FLARE_LAUNCH ? 0 : Math.min(1, (t - FLARE_LAUNCH) / (FLARE_LAND - FLARE_LAUNCH));
    const landedRamp = Math.min(1, Math.max(0, (t - FLARE_LAND) / .12));
    const flareGroundPulse = t < FLARE_LAND ? 0 : landedRamp * (.75 + .25 * Math.sin((t - FLARE_LAND) * 6.0));
    const revealEnv = Math.min(1, Math.max(0, (t - FLARE_LAND) / .6));
    const turnFlash = pulse(t, TURN_T, .05, .1, .4);
    return [recoilEnv, pumpEnv, muzzleFlashEnv, pointBlankEnv, akFlashEnv, ppshFlashEnv, flareProgress, flareGroundPulse, revealEnv, turnFlash];
  },

  post(t) {
    const [recoilEnv, , muzzleFlashEnv, pointBlankEnv, akFlashEnv, ppshFlashEnv, , , revealEnv, turnFlash] = this.params(t);
    const shake = .20 + (t >= 4 && t < 18 ? .13 : 0) + recoilEnv * 1.5 + pointBlankEnv * .9 + akFlashEnv * .28 + ppshFlashEnv * .28;
    const flashSum = Math.min(.85, muzzleFlashEnv * .6 + akFlashEnv * .28 + ppshFlashEnv * .28 + turnFlash * .4);
    const warm = muzzleFlashEnv, cool = akFlashEnv + ppshFlashEnv, red = turnFlash;
    const wsum = Math.max(.0001, warm + cool + red);
    const flashColor = [
      (warm * 1.0 + cool * .85 + red * 1.0) / wsum,
      (warm * .8 + cool * .9 + red * .18) / wsum,
      (warm * .55 + cool * 1.0 + red * .32) / wsum,
    ];
    let fade = 0;
    if (t > FADE_START) fade = Math.min(1, (t - FADE_START) / (FADE_END - FADE_START));
    return {
      grain: .06 + pointBlankEnv * .03,
      aberr: .0016 + recoilEnv * .001,
      vignette: .85,
      shake,
      exposure: .72 + muzzleFlashEnv * .12 + revealEnv * .18,
      flash: flashSum * .6,
      flashColor,
      fade,
      bloom: .36 + muzzleFlashEnv * .15 + revealEnv * .1,
      bar: 0.12,
      sat: Math.max(.5, .78 - pointBlankEnv * .15),
      contrast: 1.32,
      temp: -.12 + muzzleFlashEnv * .5 + (akFlashEnv + ppshFlashEnv) * .15 - revealEnv * .1,
      lift: [-.015 + revealEnv * .015, -.01, .012 - revealEnv * .008],
    };
  },

  overlay(ctx, t, W, H) {
    const s = W / 1280;
    // blood spatter hits the lens once, right after the 14.2s KS-23 shot
    const t0 = 14.28, holdEnd = 17.2, fadeEnd = 19.5;
    let a = 0;
    if (t > t0 && t < fadeEnd) {
      a = t < t0 + .06 ? (t - t0) / .06 : (t < holdEnd ? 1 : 1 - (t - holdEnd) / (fadeEnd - holdEnd));
    }
    if (a > 0.01) {
      const drops = [
        [230, 140, 46], [980, 210, 34], [140, 430, 38], [1080, 460, 30],
        [560, 90, 26], [720, 520, 42], [340, 610, 24],
      ];
      ctx.save();
      ctx.globalAlpha = a;
      for (const [dx, dy, r] of drops) {
        const x = dx * s, y = dy * s, rr = r * s;
        const g = ctx.createRadialGradient(x, y, 0, x, y, rr);
        g.addColorStop(0, 'rgba(60,4,4,0.85)');
        g.addColorStop(.6, 'rgba(40,2,2,0.55)');
        g.addColorStop(1, 'rgba(40,2,2,0)');
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.ellipse(x, y, rr, rr * 1.5, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = 'rgba(50,3,3,0.6)';
        ctx.fillRect(x - rr * .12, y, rr * .24, rr * 1.8);
      }
      ctx.restore();
    }
  },
};
