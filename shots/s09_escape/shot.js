// s09_escape — hangar, the Kharkovchanka rams the doors, grenade, the hangar explodes.
// Key times (keep in sync with shot.glsl + cues.json):
//   0.9 headlights ignite, 1.3+ the staff pour in, 5.0 lurch, 8.0 ram, 9.45 grenade thrown,
//   11.0 cut to exterior, 12.6 explosion.
const T_RAM = 8.0, T_THROW = 9.45, T_EXT = 11.0, T_EXPL = 12.6;

export default {
  duration: 18,
  fps: 24,
  sceneScale: 0.6,

  textures: [
    // iTex0: top half = АНГАР 9 stencil for the wall over the doors, bottom half = ОПАСНО door stencil
    {
      w: 1024, h: 256,
      draw(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        // top: АНГАР 9 with a red star
        ctx.fillStyle = 'rgba(205,198,176,0.85)';
        ctx.font = `${Math.round(h * 0.34)}px "Russo One"`;
        ctx.fillText('АНГАР 9', w * 0.55, h * 0.26);
        ctx.fillStyle = 'rgba(150,26,22,0.9)';
        const cx = w * 0.2, cy = h * 0.26, r = h * 0.17;
        ctx.beginPath();
        for (let i = 0; i < 10; i++) {
          const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * 0.42 : r;
          ctx.lineTo(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr);
        }
        ctx.closePath(); ctx.fill();
        // bottom: yellow/black hazard band + ОПАСНО
        ctx.save();
        ctx.beginPath(); ctx.rect(0, h * 0.6, w, h * 0.3); ctx.clip();
        for (let x = -h; x < w + h; x += 60) {
          ctx.fillStyle = 'rgba(190,150,30,0.8)';
          ctx.beginPath(); ctx.moveTo(x, h * 0.9); ctx.lineTo(x + 30, h * 0.9); ctx.lineTo(x + 30 + h * 0.3, h * 0.6); ctx.lineTo(x + h * 0.3, h * 0.6); ctx.fill();
        }
        ctx.restore();
        ctx.fillStyle = 'rgba(20,20,18,0.9)';
        ctx.fillRect(w * 0.3, h * 0.64, w * 0.4, h * 0.22);
        ctx.fillStyle = 'rgba(210,190,120,0.9)';
        ctx.font = `${Math.round(h * 0.17)}px "Rubik Mono One"`;
        ctx.fillText('ОПАСНО', w * 0.5, h * 0.755);
      },
    },
  ],

  post(t) {
    const ram = t >= T_RAM && t < T_EXT ? Math.exp(-(t - T_RAM) * 3.5) : 0;
    const b = t - T_EXPL;
    const boom = b >= 0 ? Math.exp(-b * 1.6) : 0;
    const ext = t >= T_EXT;
    return {
      bar: 0.12,
      grain: ext ? 0.08 : 0.07,
      aberr: 0.0016 + 0.003 * boom,
      vignette: 1.1,
      bloom: ext ? 0.45 : 0.4,
      exposure: 1.0 + (b >= 0 ? 0.5 * Math.exp(-b * 6) : 0),   // multiplicative: blacks stay black
      temp: ext ? 0.0 : 0.05,
      contrast: 1.1,
      sat: 1.0,
      shake: 2.6 * ram + 3.0 * boom + (t > 5 && t < T_RAM ? 0.35 : 0.1) + (t > 0.9 && t < 1.4 ? 0.3 : 0),
      flash: 0,
      flashColor: [1.0, 0.72, 0.4],
      fade: 0,
      lift: [0.0, 0.0, 0.01],
    };
  },
};
