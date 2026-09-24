#!/usr/bin/env node
// Render a shot to video or stills.
//
//   node render/render.mjs <shot>                       full shot -> build/shots/<shot>.mp4
//   node render/render.mjs <shot> --stills 0.5,3,7.25   PNG stills -> build/stills/<shot>_<t>.png
//   node render/render.mjs <shot> --scale 0.5           render at half res (fast preview)
//   node render/render.mjs <shot> --from 2 --to 5       sub-range (video)
//   node render/render.mjs <shot> --fps 12              lower fps preview video
//
// A shot lives in shots/<shot>/ and has shot.glsl (defines `vec3 render(vec2 fc)`) and shot.js.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const FFMPEG = process.env.FFMPEG || '/usr/local/lib/python3.11/dist-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2';

const args = process.argv.slice(2);
const shotName = args[0];
if (!shotName) { console.error('usage: render.mjs <shot> [--stills t,t] [--scale s] [--from s] [--to s] [--fps n]'); process.exit(1); }
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const scale = parseFloat(opt('scale', '1'));
const W = Math.round(1280 * scale / 2) * 2, H = Math.round(720 * scale / 2) * 2;
const stills = opt('stills', null);

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.png': 'image/png', '.glsl': 'text/plain', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(p).pipe(res);
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

const shotDir = path.join(ROOT, 'shots', shotName);
const glsl = fs.readFileSync(path.join(shotDir, 'shot.glsl'), 'utf8');
const common = fs.readFileSync(path.join(ROOT, 'shaders/common.glsl'), 'utf8');
const post = fs.readFileSync(path.join(ROOT, 'shaders/post.glsl'), 'utf8');

const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--disable-gpu-watchdog', '--disable-renderer-backgrounding'],
});
const page = await browser.newPage({ viewport: { width: W, height: H } });
page.on('console', m => console.log('[page]', m.text()));
page.on('pageerror', e => console.error('[pageerror]', e.message));
page.setDefaultTimeout(0);
await page.goto(base + '/render/page.html');
await page.waitForFunction(() => window.ENGINE_READY);

// shot.js may set sceneScale to trade resolution for speed
let sceneScale = 1;
{
  const src = fs.readFileSync(path.join(shotDir, 'shot.js'), 'utf8');
  const m = /sceneScale\s*:\s*([0-9.]+)/.exec(src);
  if (m) sceneScale = parseFloat(m[1]);
}
let info;
try {
  info = await page.evaluate(o => window.ENGINE.init(o), { W, H, glsl, common, post, shotUrl: `/shots/${shotName}/shot.js`, sceneScale });
} catch (e) {
  console.error(String(e.message || e));
  await browser.close(); server.close(); process.exit(2);
}
const fps = parseFloat(opt('fps', String(info.fps)));

if (stills) {
  fs.mkdirSync(path.join(ROOT, 'build/stills'), { recursive: true });
  for (const ts of stills.split(',')) {
    const t = parseFloat(ts);
    const t0 = Date.now();
    // warm the feedback buffer with one previous frame
    await page.evaluate(([t, i]) => { window.ENGINE.frameRaw(t, i); }, [Math.max(0, t - 1 / fps), Math.round(t * fps) - 1]);
    const url = await page.evaluate(([t, i]) => window.ENGINE.framePng(t, i), [t, Math.round(t * fps)]);
    const out = path.join(ROOT, 'build/stills', `${shotName}_${ts}.png`);
    fs.writeFileSync(out, Buffer.from(url.split(',')[1], 'base64'));
    console.log(`still t=${t} -> ${path.relative(ROOT, out)} (${Date.now() - t0} ms incl. warm frame)`);
  }
} else {
  const from = parseFloat(opt('from', '0'));
  const to = parseFloat(opt('to', String(info.duration)));
  const n = Math.round((to - from) * fps);
  fs.mkdirSync(path.join(ROOT, 'build/shots'), { recursive: true });
  const out = opt('out', path.join(ROOT, 'build/shots', `${shotName}${scale !== 1 || fps !== info.fps ? '_preview' : ''}.mp4`));
  const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-r', String(fps), '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '14', '-pix_fmt', 'yuv420p', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  const t0 = Date.now();
  for (let i = 0; i < n; i++) {
    const t = from + i / fps;
    const b = await page.evaluate(([t, i]) => window.ENGINE.frameRaw(t, i), [t, Math.round(t * fps)]);
    const buf = Buffer.from(b, 'base64');
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 24 === 0 || i === n - 1) {
      const el = (Date.now() - t0) / 1000;
      process.stdout.write(`\r${shotName}: frame ${i + 1}/${n}  ${(el / (i + 1)).toFixed(2)} s/frame  eta ${((n - i - 1) * el / (i + 1) / 60).toFixed(1)} min   `);
    }
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  console.log(`\n-> ${path.relative(ROOT, out)}`);
}
await browser.close();
server.close();
