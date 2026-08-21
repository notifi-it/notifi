import { chromium } from 'playwright'
import { spawn, execFileSync } from 'node:child_process'
import { mkdtempSync, rmSync, mkdirSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import http from 'node:http'

const HERE = path.dirname(new URL(import.meta.url).pathname)
const PUBLIC = path.resolve(HERE, '../../apps/api/public')
const OUT = path.join(HERE, 'out')
const FPS = 20
const WIDTH = 1200
const LOOP_MS = 15000

execFileSync('python3', ['gen.py'], { cwd: HERE, stdio: 'inherit' })

const doc = readFileSync(path.join(HERE, 'gif-full.html'), 'utf8')
const MIME = { '.woff2': 'font/woff2', '.svg': 'image/svg+xml', '.png': 'image/png' }
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0])
  if (url === '/__film') { res.writeHead(200, { 'content-type': 'text/html' }); return res.end(doc) }
  const file = path.join(PUBLIC, path.normalize(url))
  if (!file.startsWith(PUBLIC)) { res.writeHead(403); return res.end() }
  try {
    res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' })
    res.end(readFileSync(file))
  } catch { res.writeHead(404); res.end() }
})
await new Promise(r => server.listen(0, '127.0.0.1', r))

const frames = mkdtempSync(path.join(tmpdir(), 'notifi-gif-'))
mkdirSync(OUT, { recursive: true })

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: WIDTH, height: 720 }, deviceScaleFactor: 2 })
await page.goto(`http://127.0.0.1:${server.address().port}/__film`, { waitUntil: 'networkidle' })
await page.evaluate(() => document.fonts.ready)
await page.evaluate(() => document.querySelector('.stage').classList.add('gif'))

const stage = page.locator('.stage').first()
const count = LOOP_MS / 1000 * FPS
for (let i = 0; i < count; i++) {
  await page.evaluate(t => document.getAnimations().forEach(a => { a.currentTime = t; a.pause() }), i * LOOP_MS / count)
  await stage.screenshot({ path: path.join(frames, `f${String(i).padStart(4, '0')}.png`) })
  process.stderr.write(`\rframe ${i + 1}/${count}`)
}
process.stderr.write('\n')
await browser.close()
server.close()

const ffmpeg = args => new Promise((res, rej) => {
  spawn('ffmpeg', ['-y', '-loglevel', 'error', ...args], { stdio: 'inherit' })
    .on('exit', c => c === 0 ? res() : rej(new Error(`ffmpeg exited ${c}`)))
})
const src = ['-framerate', String(FPS), '-i', path.join(frames, 'f%04d.png')]
const pal = path.join(frames, 'pal.png')

await ffmpeg([...src, '-vf', `scale=${WIDTH}:-1:flags=lanczos,palettegen=stats_mode=diff`, pal])
await ffmpeg([...src, '-i', pal, '-lavfi',
  `scale=${WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle`,
  '-loop', '0', path.join(OUT, 'notifi.gif')])
await ffmpeg([...src, '-vf', `scale=${WIDTH}:-2:flags=lanczos,format=yuv420p`,
  '-c:v', 'libx264', '-crf', '18', '-movflags', '+faststart', path.join(OUT, 'notifi.mp4')])

rmSync(frames, { recursive: true, force: true })
console.log(`wrote ${OUT}/notifi.gif and ${OUT}/notifi.mp4`)
