import { chromium } from 'playwright'
import { spawn, execFileSync } from 'node:child_process'
import { mkdtempSync, rmSync, mkdirSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import http from 'node:http'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const PUBLIC = path.resolve(HERE, '../../apps/api/public')
const OUT = path.join(HERE, 'out')
// WIDE=1 is the version for places that take a video rather than a page: a
// 16:9 frame at 2560x1440, no grain, the heading centred in a band above the
// scene, and 50fps so the GIF can take every second frame at an exact 4cs
// delay. The default is the site's own shape, for checking the film itself.
const WIDE = process.env.WIDE === '1'
const FPS = WIDE ? 50 : 20
const WIDTH = WIDE ? 2560 : 1200
const GIF_WIDTH = WIDE ? 1920 : WIDTH
const NAME = WIDE ? 'notifi-wide' : 'notifi'

execFileSync('python3', ['gen.py'], { cwd: HERE, stdio: 'inherit' })

const doc = readFileSync(path.join(HERE, 'gif-full.html'), 'utf8')
// The loop length is gen.py's T_MS, written into the page as --T. Read it
// back rather than carry a copy: the film went from 15s to 21s and a fixed
// number here captured the first 15 and dropped the last scene.
const LOOP_MS = parseFloat(doc.match(/--T:([\d.]+)s/)[1]) * 1000
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
const page = await browser.newPage({ viewport: { width: WIDE ? 1280 : WIDTH, height: 720 }, deviceScaleFactor: 2 })
await page.goto(`http://127.0.0.1:${server.address().port}/__film`, { waitUntil: 'networkidle' })
await page.evaluate(() => document.fonts.ready)
await page.evaluate(() => document.querySelector('.stage').classList.add('gif'))

// The scene is laid out in percentages of a 2160x960 stage. Stretching that
// to 16:9 adds height below, so every vertical position is rescaled by the
// ratio of the two heights and then pushed down by the band the centred
// heading takes. The numbers come off the page, so a move in gen.py follows.
if (WIDE) await page.evaluate(() => {
  const k = (960 / 2160) / (9 / 16)
  const band = 13
  const stageH = document.querySelector('.stage').clientHeight
  const moves = []
  for (const el of document.querySelectorAll('.term,.dev,.cardpos,.trail,.clip')) {
    const cs = getComputedStyle(el)
    const top = parseFloat(cs.top) / stageH * 100
    let decl = `top:${(top * k + band).toFixed(2)}%`
    if (el.matches('.term,.clip')) decl += `;height:${(parseFloat(cs.height) / stageH * 100 * k).toFixed(2)}%`
    moves.push([el, decl])
  }
  for (const [el, decl] of moves) el.style.cssText += ';' + decl
  const st = document.createElement('style')
  st.textContent = '.stage{aspect-ratio:16/9;border:0;border-radius:0}'
    + '.head{left:0;width:100%;text-align:center;top:3.5%}'
  document.head.appendChild(st)
})

if (!WIDE) await page.evaluate(() => {
  const stage = document.querySelector('.stage')
  const cv = document.createElement('canvas')
  cv.style.cssText = 'position:absolute;inset:0;width:100%;height:100%'
  stage.prepend(cv)
  const dpr = 2
  cv.width = Math.floor(stage.clientWidth * dpr)
  cv.height = Math.floor(stage.clientHeight * dpr)
  const ctx = cv.getContext('2d', { alpha: false })
  const SIZE = 256, GROUND = 28, SPREAD = 14
  const t = document.createElement('canvas')
  t.width = t.height = SIZE
  const tc = t.getContext('2d')
  const img = tc.createImageData(SIZE, SIZE)
  for (let i = 0; i < SIZE * SIZE; i++) {
    const v = GROUND + (Math.random() - 0.5) * 2 * SPREAD
    img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v
    img.data[i * 4 + 3] = 255
  }
  tc.putImageData(img, 0, 0)
  ctx.fillStyle = ctx.createPattern(t, 'repeat')
  ctx.fillRect(0, 0, cv.width, cv.height)
})

const stage = page.locator('.stage').first()
const count = LOOP_MS / 1000 * FPS
for (let i = 0; i < count; i++) {
  const at = i * LOOP_MS / count
  await page.evaluate(t => document.getAnimations().forEach(a => { a.currentTime = t; a.pause() }), at)
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

// The grainy page build dithers; the flat wide build must not, or every frame
// carries a different dither pattern and the GIF crawls.
const gifIn = `fps=${WIDE ? FPS / 2 : FPS},scale=${GIF_WIDTH}:-1:flags=lanczos`
const gifOut = WIDE ? 'paletteuse=dither=none:diff_mode=rectangle'
  : 'paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle'
await ffmpeg([...src, '-vf', `${gifIn},palettegen=stats_mode=diff`, pal])
await ffmpeg([...src, '-i', pal, '-lavfi', `${gifIn}[x];[x][1:v]${gifOut}`,
  '-loop', '0', path.join(OUT, `${NAME}.gif`)])
await ffmpeg([...src, '-vf', `scale=${WIDTH}:-2:flags=lanczos,format=yuv420p`,
  '-c:v', 'libx264', '-crf', WIDE ? '16' : '18', '-preset', 'slow', '-r', String(FPS),
  '-movflags', '+faststart', path.join(OUT, `${NAME}.mp4`)])

rmSync(frames, { recursive: true, force: true })
console.log(`wrote ${OUT}/${NAME}.gif and ${OUT}/${NAME}.mp4`)
