// Generates cues.json for s07_fight from the fight script in shot.js, so sound and picture never drift.
//   node shots/s07_fight/make_cues.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { KS, AK, PPSH, FLARE, FLARE_LAND } from './shot.js';

const dir = path.dirname(fileURLToPath(import.meta.url));
const cues = [
  { t: 0.0, type: 'heartbeat', gain: 0.45, dur: 4.0 },
  { t: 0.2, type: 'breath', gain: 0.5, dur: 3.6 },
  { t: 1.5, type: 'growl', gain: 0.35, dur: 1.8 },
  { t: 3.4, type: 'growl', gain: 0.6, dur: 1.2 },
  { t: 4.0, type: 'shriek', gain: 0.8 },
  { t: 4.5, type: 'shriek', gain: 0.6 },
  { t: 4.1, type: 'footsteps', gain: 0.6, dur: 1.0 },
];
for (const s of KS) {
  cues.push({ t: s, type: 'ks23_shot', gain: 1.0 });
  cues.push({ t: s + 0.02, type: 'gore_hit', gain: 0.9 });
  cues.push({ t: s + 0.3, type: 'pump_rack', gain: 0.9 });
}
cues.push({ t: 5.75, type: 'body_fall', gain: 0.8 });
for (const [a, b] of AK) cues.push({ t: a, type: 'ak_burst', gain: 0.9, dur: +(b - a).toFixed(3) });
for (const [a, b] of PPSH) cues.push({ t: a, type: 'ppsh_burst', gain: 0.9, dur: +(b - a).toFixed(3) });
// monster deaths from the side guns, and their charges
cues.push({ t: 6.9, type: 'gore_hit', gain: 0.6 }, { t: 7.4, type: 'body_fall', gain: 0.7 });
cues.push({ t: 8.0, type: 'shriek', gain: 0.7 }, { t: 8.5, type: 'growl', gain: 0.8, dur: 1.5 });
cues.push({ t: 10.2, type: 'body_fall', gain: 0.8 });
cues.push({ t: 11.0, type: 'gore_hit', gain: 0.6 }, { t: 11.5, type: 'body_fall', gain: 0.7 });
cues.push({ t: 12.6, type: 'body_fall', gain: 0.8 });
cues.push({ t: 12.5, type: 'shriek', gain: 0.9 });
cues.push({ t: 13.4, type: 'gore_hit', gain: 0.6 }, { t: 13.9, type: 'body_fall', gain: 0.7 });
cues.push({ t: 14.6, type: 'growl', gain: 1.0, dur: 1.0 });
cues.push({ t: 16.4, type: 'body_fall', gain: 1.0 });
cues.push({ t: 16.0, type: 'breath', gain: 0.8, dur: 2.2 }, { t: 16.2, type: 'heartbeat', gain: 0.7, dur: 2.0 });
cues.push({ t: FLARE, type: 'flare_shot', gain: 1.0 });
cues.push({ t: FLARE_LAND, type: 'impact', gain: 0.4 });
cues.push({ t: FLARE_LAND, type: 'drone_swell', gain: 0.9, dur: 3.0 });
cues.push({ t: 21.2, type: 'growl', gain: 0.9, dur: 1.4 });
cues.push({ t: 22.0, type: 'stinger', gain: 1.0 });
cues.push({ t: 22.6, type: 'shriek', gain: 1.0 }, { t: 22.8, type: 'shriek', gain: 0.8 }, { t: 23.0, type: 'footsteps', gain: 0.9, dur: 0.6 });
cues.sort((a, b) => a.t - b.t);
fs.writeFileSync(path.join(dir, 'cues.json'), JSON.stringify({ ambience: 'interior_dead', cues }, null, 1));
console.log(`${cues.length} cues -> cues.json`);
