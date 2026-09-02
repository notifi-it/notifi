// The three gallery stills: one per scene, each at the film's own resting
// point. Clicking a terminal tab is what pins a scene — the handler in gen.py
// seeks every animation to HOLD_AT and lifts both the terminal and that
// scene's device to full opacity — so this drives that control rather than
// re-deriving the timing. Change HOLD_AT and these follow.
//
//   make film-stills
//
// Writes out/still-1.png … still-3.png, padded to the 1270x760 slot the
// Product Hunt gallery and the App Store both take.
import { chromium } from 'playwright'
import { execFileSync } from 'node:child_process'
import { mkdirSync, readFileSync, rmSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import http from 'node:http'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const PUBLIC = path.resolve(HERE, '../../apps/api/public')
const OUT = process.env.OUT || path.join(HERE, 'out')
const WIDTH = Number(process.env.WIDTH || 1600)
const TARGET = Number(process.env.TARGET || 2560)
const GROUND = '#1C1C1C'
// The tab order is the film's; the gallery leads with the Claude scene.
const ORDER = (process.env.ORDER || '1,0,2').split(',').map(Number)

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

mkdirSync(OUT, { recursive: true })
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: WIDTH, height: 720 }, deviceScaleFactor: 2 })
await page.goto(`http://127.0.0.1:${server.address().port}/__film`, { waitUntil: 'networkidle' })
await page.evaluate(() => document.fonts.ready)
await page.evaluate(() => document.querySelector('.stage').classList.add('gif'))

// The stage is styled as a card because the landing page hangs it in one.
// build.py strips that when it inlines the film, so a still that keeps it
// carries a frame the site never shows.
await page.evaluate(() => {
  const st = document.querySelector('.stage')
  st.style.border = '0'
  st.style.borderRadius = '0'
})

// gen.py's grain canvas, at the same seed-free spread capture.mjs uses.
await page.evaluate(() => {
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

// A gallery tile is read at a glance and scaled hard, so the heading carries
// more of it than it does on the page: larger, in the normal foreground
// rather than red, and the subline in the same mono. .head is boxed to clear
// the leftmost device (DEV[2] at 51.75%) so neither line runs under it.
await page.evaluate(() => {
  const st = document.createElement('style')
  st.textContent = '.head{top:5%;width:45%}'
    + '.gif .l1{--fs:2.6;color:var(--fg);white-space:nowrap}'
    + '.head .l2{--fs:1.7;font-family:var(--mono);letter-spacing:-.02em;white-space:nowrap}'
  document.head.appendChild(st)
})

const stage = page.locator('.stage').first()
let n = 0
for (const pass of ORDER) {
  n += 1
  await page.click(`[data-pass="${pass}"]`)
  // The handler settles HOLD_AT into the scene; wait past that, then confirm
  // nothing is still running before the shutter.
  await page.waitForFunction(() => {
    const running = document.getAnimations().filter(a => a.playState === 'running')
    return running.length === 0
  }, null, { timeout: 20000 })
  const raw = path.join(OUT, `_raw-${n}.png`)
  await stage.screenshot({ path: raw })
  const h = Math.round(TARGET * 760 / 1270)
  execFileSync('magick', [raw, '-resize', `${TARGET}x`, '-background', GROUND,
    '-gravity', 'center', '-extent', `${TARGET}x${h}`, '-strip',
    '-define', 'png:color-type=6', path.join(OUT, `still-${n}.png`)])
  rmSync(raw)
  console.log(`still-${n}.png  pass ${pass}  ${TARGET}x${h}`)
}

await browser.close()
server.close()
