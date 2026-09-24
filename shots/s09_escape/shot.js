// s09_escape — the hangar and the way out.
export default {
  duration: 18,
  fps: 24,
  sceneScale: 0.7,

  post(t) {
    const ramK = t >= 9.15 && t < 9.6 ? 1 - (t - 9.15) / 0.45 : 0;
    const blastFlash = t >= 11.0 && t < 11.3 ? 1 - (t - 11.0) / 0.3 : 0;
    const ext = t >= 11.0;
    return {
      bar: 0.12,
      grain: ext ? 0.08 : 0.065,
      aberr: 0.0017,
      vignette: 1.05,
      bloom: ext ? 0.42 : 0.3,
      exposure: blastFlash > 0.5 ? 1.4 : 1.0,
      temp: ext ? 0.15 : -0.1,
      contrast: 1.08,
      sat: ext ? 1.05 : 0.95,
      shake: ramK * 2.2 + (ext && t < 13.5 ? Math.max(0, 1.8 - (t - 11.0)) : 0) + (t < 5 ? 0.15 : 0),
      flash: blastFlash * 0.9,
      flashColor: [1.0, 0.75, 0.4],
      fade: 0,
      scan: 0,
    };
  },

  overlay(ctx, t, W, H) {
    // subtitle beat: none needed — action reads visually.
  },
};
