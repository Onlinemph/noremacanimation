// s05_corridor — the signature scare.
// A long dead corridor, most tubes gone. A figure at the far end. Every blackout, it is closer.
//
// Shared timeline (seconds) used by params(), post() and cues.json:
//   0.0 - 2.8   lights on (weak, one tube faulty). Figure at 26 m, back half-turned, twitching.
//   2.8 - 3.3   blackout (flashlight only).            -> returns at 17 m
//   5.6 - 5.8   tease flicker, no move
//   7.0 - 7.5   blackout                               -> returns at 10 m, now facing us
//   9.4 - 9.9   blackout                               -> returns at 2.2 m from camera (in the beam)
//  11.6 -12.15  everything dies, flashlight too (total black)
//  12.15-12.55  flashlight snaps back on: face at 0.7 m
//  12.55-14.0   hard black

const BLACKOUTS = [[2.8, 3.3], [5.6, 5.8], [7.0, 7.5], [9.4, 9.9], [11.6, 12.55]];

function hash(n) { const s = Math.sin(n * 127.1) * 43758.5453; return s - Math.floor(s); }

// camera walks forward, stops when the thing gets close
function camZ(t) {
  const walk = Math.min(t, 9.9);
  return walk * 0.36;
}

function lightLevel(t) {
  for (const [a, b] of BLACKOUTS) {
    if (t >= a && t < b) {
      // sputter at the edges of each blackout
      const edge = Math.min(t - a, b - t);
      if (edge < 0.08) return hash(Math.floor(t * 60)) > 0.5 ? 0.6 : 0.0;
      return 0.0;
    }
  }
  if (t >= 12.55) return 0;
  // general unsteady mains: small dips
  const dip = hash(Math.floor(t * 14)) > 0.93 ? 0.55 : 1.0;
  return dip;
}

function flashLevel(t) {
  if (t >= 11.6 && t < 12.15) return 0.0;             // the torch dies too
  if (t >= 11.45 && t < 11.6) return hash(Math.floor(t * 50)) > 0.5 ? 1 : 0.1;
  if (t >= 12.55) return 0;
  return 1.0;
}

// monster z (world) and facing (0 = facing away, 1 = facing camera), run pose
function monster(t) {
  const cz = camZ(t);
  if (t < 3.3) return [24.6, 0.25, 0.0, 0.0];
  if (t < 7.5) return [17.0, 0.55, 0.0, 0.1];
  if (t < 9.9) return [10.0, 1.0, 0.0, 0.2];
  if (t < 12.15) return [cz + 2.3, 1.0, 0.1, 0.4];
  return [cz + 0.8, 1.0, 0.35, 0.55];
}

export default {
  duration: 14,
  fps: 24,
  sceneScale: 0.72,

  params(t) {
    const [mz, face, run, rear] = monster(t);
    const scare = t >= 12.15 && t < 12.55 ? 1 : 0;
    return [lightLevel(t), mz, face, run, camZ(t), flashLevel(t), scare, t >= 12.15 ? 12.2 : t, rear];
  },

  post(t) {
    const p = { bar: 0.12, grain: 0.085, vignette: 1.15, bloom: 0.45, aberr: 0.0018, temp: -0.25, contrast: 1.12, sat: 0.8, exposure: 1.0 };
    if (t >= 12.15 && t < 12.55) {
      Object.assign(p, { shake: 0.9, aberr: 0.006, flash: t < 12.2 ? 0.25 : 0, flashColor: [0.8, 0.85, 1.0], contrast: 1.3, exposure: 1.4 });
    }
    if (t >= 12.55) p.fade = 1;
    return p;
  },

  textures: [
    {
      // atlas: left half = Soviet safety poster, right half = stencilled sector sign
      w: 1024, h: 512,
      draw(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        // poster
        ctx.fillStyle = '#b8ad8c'; ctx.fillRect(20, 20, 472, 472);
        ctx.fillStyle = '#8e1c17'; ctx.fillRect(20, 20, 472, 150);
        ctx.fillStyle = '#e8dcc0'; ctx.font = 'bold 64px "Russo One"'; ctx.textAlign = 'center';
        ctx.fillText('БДИТЕЛЬНОСТЬ', 256, 118);
        ctx.fillStyle = '#2a211a'; ctx.font = '38px "Oswald"';
        ctx.fillText('— НАШЕ ОРУЖИЕ —', 256, 230);
        // silhouette of a worker with a finger to his lips
        ctx.beginPath(); ctx.arc(256, 330, 52, 0, Math.PI * 2); ctx.fill();
        ctx.fillRect(176, 380, 160, 112);
        ctx.fillStyle = '#8e1c17'; ctx.fillRect(250, 300, 12, 70);
        ctx.fillStyle = '#2a211a'; ctx.font = '30px "PT Mono"';
        ctx.fillText('НЕ БОЛТАЙ', 256, 478);
        // tear + stains
        ctx.globalCompositeOperation = 'destination-out';
        ctx.beginPath(); ctx.moveTo(492, 20); ctx.lineTo(380, 20); ctx.lineTo(430, 90); ctx.lineTo(400, 140); ctx.lineTo(492, 200); ctx.fill();
        ctx.globalCompositeOperation = 'source-over';
        ctx.fillStyle = 'rgba(60,30,10,0.25)';
        for (let i = 0; i < 30; i++) { ctx.beginPath(); ctx.arc(40 + (i * 97) % 440, 40 + (i * 53) % 440, 6 + (i % 5) * 7, 0, 7); ctx.fill(); }
        // stencil sign on the right half
        ctx.fillStyle = 'rgba(210,200,175,0.85)';
        ctx.font = '120px "Russo One"'; ctx.textAlign = 'center';
        ctx.fillText('СЕКТОР Б', 768, 230);
        ctx.font = '56px "Russo One"';
        ctx.fillText('ЛАБОРАТОРИИ →', 768, 330);
      },
    },
  ],
};
