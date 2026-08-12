/* notifi launch GIF — 2160×960, three passes, loops. Palette + type lifted from apps/api/public/index.html */
const { CompositionStage, useComposition, Easing, interpolate, clamp } = window;

const BG = '#1C1C1E', SURFACE = '#262628', LINE = '#333333', CHIP = '#3C3C3C';
const FG = '#EDEDED', MUTED = '#A1A1A1', DIM = '#8A8A8A', RED = '#DB4A4B', BLUE = '#7FA8E0';
const MONO = "'Inconsolata',ui-monospace,SFMono-Regular,Menlo,monospace";
/* Apple UI (banners, clocks, menu bar) renders in SF via -apple-system; Karla stays for nothing UI-side */
const SANS = "-apple-system,BlinkMacSystemFont,'SF Pro Text',system-ui,sans-serif";

const noiseURI = (seed, fill, alpha) => `url("data:image/svg+xml,${encodeURIComponent(
  `<svg xmlns='http://www.w3.org/2000/svg' width='260' height='260'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='2' seed='${seed}' stitchTiles='stitch'/><feColorMatrix type='matrix' values='0 0 0 0 ${fill} 0 0 0 0 ${fill} 0 0 0 0 ${fill} ${alpha} 0 0 0 0'/></filter><rect width='260' height='260' filter='url(#n)'/></svg>`
)}")`;
/* Television static, matching the site's #static canvas: per-pixel greys #101010–#292929,
   pre-baked to three PNG tiles (seeded, deterministic) and cycled from T. Drawn at 2×
   block size so the speckle survives the preview's downscale. */
const GRAIN = (() => {
  let seed = 1234;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  return [0, 1, 2].map(() => {
    const c = document.createElement('canvas'); c.width = 256; c.height = 256;
    const x = c.getContext('2d'); const im = x.createImageData(256, 256);
    for (let i = 0; i < im.data.length; i += 4) {
      const v = 16 + Math.floor(rnd() * 26);
      im.data[i] = v; im.data[i + 1] = v; im.data[i + 2] = v + 1; im.data[i + 3] = 165;
    }
    x.putImageData(im, 0, 0);
    return `url(${c.toDataURL()})`;
  });
})();

/* the three motion helpers */
const MOTION = {
  enter: (a, b) => T => interpolate([a, b], [0, 1], Easing.easeOutCubic)(clamp(T, a, b)),
  /* UIKit-style underdamped spring (response ~0.55s, damping ~0.8): slight overshoot, soft settle */
  drop: (a, b) => T => {
    const x = clamp((T - a) / (b - a), 0, 1);
    if (x <= 0) return 0; if (x >= 1) return 1;
    return 1 - Math.exp(-6.2 * x) * Math.cos(7.5 * x);
  },
  fade: (a, b) => T => interpolate([a, b], [1, 0], Easing.easeOutQuad)(clamp(T, a, b)),
};
/* opacity window: ramps in over [i0,i1], out over [o0,o1] */
const win = (T, i0, i1, o0, o1) => MOTION.enter(i0, i1)(T) * MOTION.fade(o0, o1)(T);

/* terminal text resolves out of the ground letter by letter, the same move as the
   headlines; the response only lands once the last character has arrived */
function TermBody({ lines, resp, t0, T }) {
  const DIMBG = '#2B2B2D';
  let idx = 0;
  const body = lines.map((l, i) => React.createElement('div', { key: i, style: { minHeight: 48 } },
    l.map((s, j) => React.createElement('span', { key: j }, s.t.split('').map((ch, k) => {
      const at = t0 + 0.25 + (idx++) * 0.005;
      const p = Easing.easeOutCubic(clamp((T - at) / 0.5, 0, 1));
      return React.createElement('span', { key: k, style: { color: hexLerp(DIMBG, s.c, p) } }, ch);
    })))));
  const respOn = MOTION.enter(t0 + 2.0, t0 + 2.15)(T);
  return React.createElement('div', { style: { padding: '30px 36px', fontFamily: MONO, fontSize: 28, lineHeight: '48px', whiteSpace: 'pre' } },
    body,
    React.createElement('div', { style: { color: DIM, opacity: respOn, minHeight: 48 } }, resp),
  );
}

function Terminal({ tabs, active, children, opacity }) {
  return React.createElement('div', {
    style: { position: 'absolute', inset: 0, opacity, background: SURFACE, borderRadius: 24, overflow: 'hidden' },
  },
    /* macOS Terminal chrome: title bar with the dots, then a full-width tab strip below it */
    React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10, padding: '16px 26px' } },
      [0, 1, 2].map(i => React.createElement('span', { key: i, style: { width: 18, height: 18, borderRadius: '50%', background: CHIP } }))),
    React.createElement('div', { style: { display: 'flex', borderBottom: `1px solid ${LINE}`, padding: '0 10px 10px' } },
      tabs.map((t, i) => React.createElement('span', {
        key: t,
        style: {
          flex: 1, textAlign: 'center',
          fontFamily: MONO, fontSize: 20, padding: '8px 0', borderRadius: 10,
          color: i === active ? FG : DIM,
          background: i === active ? CHIP : 'transparent',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        },
      }, t)),
    ),
    children,
  );
}

/* Liquid Glass (iOS 26+/macOS Tahoe): translucent fill, heavy blur+saturation, a specular
   top-edge highlight and a faint glass rim instead of a border */
const CARD = {
  background: 'linear-gradient(rgba(255,255,255,0.07), rgba(255,255,255,0.02) 40%), rgba(58,58,64,0.44)',
  backdropFilter: 'blur(40px) saturate(1.8)',
  WebkitBackdropFilter: 'blur(40px) saturate(1.8)',
  boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.22), inset 0 0 0 1px rgba(255,255,255,0.08), 0 16px 40px rgba(0,0,0,0.45)',
};

/* ── banners ── */
/* Real iOS metrics, ~1pt≈1px at this device scale: 42pt icon, 18pt text, 26pt radius,
   banner spans the screen minus ~8pt margins; compact two-line stack, "now" top-right. */
function IosBanner({ w, title, body, thumb, on }) {
  /* lock-screen arrival: fade + scale-up in place (iOS does not drop banners from the top) */
  const p = Easing.easeOutCubic(clamp(on.progress * 1.8, 0, 1));
  const scale = 0.85 + 0.15 * p;
  return React.createElement('div', {
    style: {
      ...CARD,
      position: 'absolute', top: 0, left: '50%', width: w,
      transform: `translate(-50%, ${on.top}px) scale(${scale})`, opacity: on.opacity * p,
      borderRadius: 24, padding: '13px 16px',
      display: 'flex', alignItems: 'center', gap: 13,
    },
  },
    React.createElement('img', { src: '../../apps/api/public/apple-touch-icon.png', width: 42, height: 42, style: { borderRadius: 10, flex: 'none' } }),
    React.createElement('div', { style: { flex: 1, minWidth: 0, fontFamily: SANS } },
      React.createElement('div', { style: { display: 'flex', alignItems: 'baseline', gap: 10 } },
        React.createElement('div', { style: { fontSize: 18, fontWeight: 700, color: FG, flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, title),
        React.createElement('div', { style: { fontSize: 15, color: DIM, flex: 'none' } }, 'now'),
      ),
      React.createElement('div', { style: { fontSize: 18, color: MUTED, lineHeight: 1.25, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, body),
    ),
    thumb && React.createElement('img', { src: thumb, width: 42, height: 42, style: { borderRadius: 8, flex: 'none', objectFit: 'cover', background: '#000' } }),
  );
}

function MacBanner({ title, body, sub, on }) {
  /* macOS slide-in from beyond the right edge: quick ease-out, no bounce */
  const x = 510 * (1 - Easing.easeOutCubic(clamp(on.progress * 1.4, 0, 1)));
  return React.createElement('div', {
    style: {
      ...CARD,
      position: 'absolute', top: 76, right: 16, width: 380,
      transform: `translateX(${x}px)`, opacity: on.opacity,
      borderRadius: 14,
      padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 13,
    },
  },
    React.createElement('img', { src: '../../apps/api/public/apple-touch-icon.png', width: 44, height: 44, style: { borderRadius: 10, flex: 'none' } }),
    React.createElement('div', { style: { fontFamily: SANS, minWidth: 0 } },
      React.createElement('div', { style: { fontSize: 13, fontWeight: 600, letterSpacing: 0.6, color: DIM } }, 'NOTIFI'),
      React.createElement('div', { style: { fontSize: 19, fontWeight: 700, color: FG } }, title),
      React.createElement('div', { style: { fontSize: 17, color: MUTED, lineHeight: 1.3 } }, body),
    ),
  );
}

/* piecewise-linear keyframe read: the site's ring-body/ring-clapper tracks, driven from T */
const kfLerp = (kt, kv, t) => {
  if (t <= kt[0]) return kv[0];
  if (t >= kt[kt.length - 1]) return kv[kv.length - 1];
  let i = 1; while (kt[i] < t) i++;
  const f = (t - kt[i - 1]) / (kt[i] - kt[i - 1]);
  return kv[i - 1] + (kv[i] - kv[i - 1]) * f;
};
const RING_BODY_T = [0, 4.26, 12.96, 21.66, 30.37, 39.07, 47.78, 56.48, 65.18, 73.89, 82.59, 91.30, 100].map(v => v * 2.585 / 100);
const RING_BODY_V = [0, -20, 18, -16, 14, -13, 12, -10, 8, -6, 4, -2, 0];
const RING_CLAP_T = [0, 2.48, 7.02, 16.32, 25.62, 34.92, 44.21, 53.51, 62.81, 72.11, 81.40, 90.70, 100].map(v => v * 2.42 / 100);
const RING_CLAP_V = [0, 0, -30, 27, -24, 20, -18, 15, -12, 9, -6, 3, 0];

/* "Celosia" (iOS 27 / macOS 27 Golden Gate shared default, dark variant): sweeping
   overlapping petal-like bands with soft shadows, drawn once as SVG and cropped per device */
const celosiaSVG = (w, h) => `url("data:image/svg+xml,${encodeURIComponent(
  `<svg xmlns='http://www.w3.org/2000/svg' width='${w}' height='${h}' viewBox='0 0 1000 1000' preserveAspectRatio='xMidYMid slice'>` +
  `<defs><filter id='s' x='-30%' y='-30%' width='160%' height='160%'><feGaussianBlur stdDeviation='26'/></filter>` +
  `<linearGradient id='g1' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#E0574F'/><stop offset='1' stop-color='#922E52'/></linearGradient>` +
  `<linearGradient id='g2' x1='0' y1='1' x2='1' y2='0'><stop offset='0' stop-color='#4A6FB5'/><stop offset='1' stop-color='#7FA8E0'/></linearGradient>` +
  `<linearGradient id='g3' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#814FA8'/><stop offset='1' stop-color='#412A63'/></linearGradient></defs>` +
  `<rect width='1000' height='1000' fill='#0B0A12'/>` +
  `<path d='M-100 780 C 200 560, 420 900, 700 660 S 1150 520, 1150 520 L 1150 1100 L -100 1100 Z' fill='url(#g3)' opacity='0.85' filter='url(#s)'/>` +
  `<path d='M-100 880 C 240 640, 480 980, 760 760 S 1150 640, 1150 640 L 1150 1100 L -100 1100 Z' fill='url(#g2)' opacity='0.8' filter='url(#s)'/>` +
  `<path d='M-100 980 C 260 760, 560 1060, 820 880 S 1150 780, 1150 780 L 1150 1100 L -100 1100 Z' fill='url(#g1)' opacity='0.9' filter='url(#s)'/>` +
  `<path d='M-100 240 C 240 420, 560 160, 860 320 S 1150 300, 1150 300 L 1150 -100 L -100 -100 Z' fill='url(#g3)' opacity='0.5' filter='url(#s)'/>` +
  `</svg>`)}")`;
const WALLPAPER = {
  phone: `${celosiaSVG(400, 830)} center / cover`,
  pad: `${celosiaSVG(880, 660)} center / cover`,
  mac: `${celosiaSVG(940, 564)} center / cover`,
};

/* ── devices ── */
/* bell mask SVGs inlined as data-uris (from apps/api/public/bell-*.svg) so masks survive capture/export */
const BELL_BODY_URI = `url("data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="5.2700 6.5395 21.4600 21.4600"><circle cx="20.3047" cy="9.7539" r="2.9" fill="#000"/><path stroke="#000" stroke-width="0.75" stroke-linejoin="miter" stroke-miterlimit="4" fill-rule="nonzero" fill="#000" fill-opacity="1" d="M 25.296875 20.980469 C 24.558594 20.625 23.972656 20.140625 23.558594 19.542969 C 22.859375 18.542969 22.773438 17.390625 22.699219 16.464844 C 22.695312 16.410156 22.605469 15.222656 22.609375 14.167969 C 22.203125 14.378906 21.777344 14.558594 21.3125 14.652344 C 21.328125 15.605469 21.398438 16.519531 21.402344 16.570312 C 21.484375 17.59375 21.59375 18.996094 22.488281 20.285156 C 22.785156 20.707031 23.140625 21.085938 23.554688 21.417969 C 21.769531 22.046875 19.085938 22.835938 16.09375 22.835938 C 16.070312 22.835938 16.042969 22.835938 16.015625 22.832031 C 13.699219 22.824219 11.160156 22.34375 8.453125 21.414062 C 8.863281 21.082031 9.21875 20.707031 9.511719 20.285156 C 10.40625 18.992188 10.519531 17.589844 10.597656 16.566406 C 10.601562 16.503906 10.71875 14.976562 10.683594 13.820312 C 10.683594 11.652344 11.585938 9.9375 13.226562 8.988281 C 13.9375 8.578125 14.738281 8.351562 15.550781 8.289062 C 15.695312 7.820312 15.886719 7.371094 16.152344 6.972656 C 14.910156 6.945312 13.660156 7.238281 12.574219 7.863281 C 10.515625 9.054688 9.382812 11.171875 9.386719 13.839844 C 9.417969 14.945312 9.304688 16.40625 9.300781 16.464844 C 9.230469 17.390625 9.140625 18.542969 8.445312 19.542969 C 8.027344 20.140625 7.441406 20.625 6.699219 20.980469 C 6.46875 21.089844 6.324219 21.332031 6.332031 21.589844 C 6.34375 21.847656 6.503906 22.078125 6.746094 22.171875 C 10.066406 23.460938 13.183594 24.121094 16.011719 24.132812 L 16.097656 24.132812 C 20.128906 24.132812 23.582031 22.808594 25.25 22.171875 C 25.492188 22.078125 25.65625 21.851562 25.667969 21.589844 C 25.679688 21.332031 25.53125 21.089844 25.296875 20.980469 "/></svg>')}")`;
const BELL_CLAP_URI = `url("data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="5.2700 6.5395 21.4600 21.4600"><path fill="none" stroke-width="2.15" stroke-linecap="round" stroke-linejoin="round" stroke="#000" stroke-opacity="1" stroke-miterlimit="10" d="M 0.001038 -0.1 C -0.083583 -4.903883 -6.325124 -4.771655 -6.418902 -0.1 " transform="matrix(1, 0, 0, -1, 19.252, 23.2139)"/></svg>')}")`;

const Bell = ({ size, color, bodyRot = 0, clapperRot = 0 }) => React.createElement('div', { style: { position: 'relative', width: size, height: size, flex: 'none' } },
  [[BELL_BODY_URI, bodyRot, 'b'], [BELL_CLAP_URI, clapperRot, 'c']].map(([uri, rot, k]) => React.createElement('div', {
    key: k,
    style: {
      position: 'absolute', inset: 0, background: color,
      transform: `rotate(${rot}deg)`, transformOrigin: '50% 0',
      WebkitMaskImage: uri, maskImage: uri,
      WebkitMaskSize: 'contain', maskSize: 'contain', WebkitMaskRepeat: 'no-repeat', maskRepeat: 'no-repeat', WebkitMaskPosition: 'center', maskPosition: 'center',
    },
  })));

/* SF-style glyphs: outlined battery body + nub cap + inner charge; wifi as stroked arcs + dot */
const BatteryIcon = ({ h = 19 }) => React.createElement('svg', { width: h * 30 / 14, height: h, viewBox: '0 0 30 14' },
  React.createElement('rect', { x: 0.75, y: 0.75, width: 24.5, height: 12.5, rx: 4, fill: 'none', stroke: FG, strokeOpacity: 0.45, strokeWidth: 1.5 }),
  React.createElement('path', { d: 'M27.5 4.5 a3.2 3.2 0 0 1 0 5 Z', fill: FG, fillOpacity: 0.45 }),
  React.createElement('rect', { x: 2.6, y: 2.6, width: 15, height: 8.8, rx: 2.2, fill: FG }));
const WifiIcon = ({ h = 18 }) => React.createElement('svg', { width: h * 25 / 18, height: h, viewBox: '0 0 25 18' },
  React.createElement('path', { d: 'M2.2 6.4 a15.5 15.5 0 0 1 20.6 0', fill: 'none', stroke: FG, strokeWidth: 2.4, strokeLinecap: 'round' }),
  React.createElement('path', { d: 'M5.9 10.4 a10 10 0 0 1 13.2 0', fill: 'none', stroke: FG, strokeWidth: 2.4, strokeLinecap: 'round' }),
  React.createElement('path', { d: 'M9.6 14.2 a4.6 4.6 0 0 1 5.8 0', fill: 'none', stroke: FG, strokeWidth: 2.4, strokeLinecap: 'round' }),
  React.createElement('circle', { cx: 12.5, cy: 16.6, r: 1.4, fill: FG }));

function StatusBar({ pad }) {
  return React.createElement('div', { style: { position: 'absolute', top: 0, left: 0, right: 0, display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: `16px ${pad}px`, fontFamily: SANS, fontSize: 22, fontWeight: 600, color: FG } },
    React.createElement('span', null, '10:24'),
    React.createElement('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 10 } },
      React.createElement('svg', { width: 26, height: 18, viewBox: '0 0 26 18' },
        [0, 1, 2, 3].map(i => React.createElement('rect', { key: i, x: i * 7, y: 12 - i * 4, width: 4, height: 6 + i * 4, rx: 1.5, fill: FG }))),
      React.createElement(WifiIcon, null),
      React.createElement(BatteryIcon, null)),
  );
}

function IPhone({ opacity, children }) {
  return React.createElement('div', { style: { position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', opacity } },
    React.createElement('div', { style: { width: 400, height: 830, borderRadius: 62, background: '#0A0A0B', border: `3px solid ${CHIP}`, padding: 10, boxShadow: '0 30px 80px rgba(0,0,0,0.5)' } },
      React.createElement('div', { style: { position: 'relative', width: '100%', height: '100%', borderRadius: 52, background: WALLPAPER.phone, overflow: 'hidden' } },
        React.createElement('div', { style: { position: 'absolute', top: 14, left: '50%', transform: 'translateX(-50%)', width: 110, height: 32, borderRadius: 16, background: '#000' } }),
        React.createElement('div', { style: { position: 'absolute', top: 70, left: 0, right: 0, textAlign: 'center', fontFamily: SANS, fontSize: 22, fontWeight: 600, color: FG } }, 'Tuesday, August 11'),
        React.createElement('div', { style: { position: 'absolute', top: 92, left: 0, right: 0, textAlign: 'center', fontFamily: SANS, fontSize: 96, fontWeight: 200, color: FG, letterSpacing: -2 } }, '10:24'),
        /* lock-screen notifications stack from the bottom since iOS 16, resting above
           the flashlight/camera row rather than on the screen edge */
        React.createElement('div', { style: { position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)', width: 130, height: 5, borderRadius: 3, background: 'rgba(255,255,255,0.85)' } }),
        React.createElement('div', { style: { position: 'absolute', top: 235, left: 0, right: 0, height: 110 } }, children),
      )));
}

function IPad({ opacity, children }) {
  return React.createElement('div', { style: { position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', opacity } },
    React.createElement('div', { style: { width: 880, height: 660, borderRadius: 44, background: '#0A0A0B', border: `3px solid ${CHIP}`, padding: 12, boxShadow: '0 30px 80px rgba(0,0,0,0.5)' } },
      React.createElement('div', { style: { position: 'relative', width: '100%', height: '100%', borderRadius: 32, background: WALLPAPER.pad, overflow: 'hidden' } },
        React.createElement(StatusBar, { pad: 28 }),
        React.createElement('div', { style: { position: 'absolute', top: 200, left: 0, right: 0, textAlign: 'center', fontFamily: SANS, fontSize: 96, fontWeight: 200, color: FG, letterSpacing: -2 } }, '10:24'),
        React.createElement('div', { style: { position: 'absolute', top: 345, left: 0, right: 0, height: 110 } }, children),
      )));
}

function Mac({ opacity, ring, children }) {
  return React.createElement('div', { style: { position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', opacity } },
    React.createElement('div', { style: { width: 940, borderRadius: 24, border: `1px solid ${LINE}`, background: WALLPAPER.mac, overflow: 'hidden', boxShadow: '0 30px 80px rgba(0,0,0,0.5)' } },
      /* Tahoe menu bar: translucent, wallpaper shows through */
      React.createElement('div', { style: { position: 'relative', display: 'flex', alignItems: 'center', height: 64, padding: '0 30px', background: 'rgba(22,22,27,0.42)', backdropFilter: 'blur(18px)', WebkitBackdropFilter: 'blur(18px)', borderBottom: '1px solid rgba(255,255,255,0.06)', fontFamily: SANS, fontSize: 21, color: FG } },
        React.createElement('span', { style: { fontSize: 24, marginRight: 26 } }, ''),
        React.createElement('span', { style: { marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 24 } },
          React.createElement(Bell, { size: 30, color: FG, bodyRot: ring.body, clapperRot: ring.clapper }),
          React.createElement(BatteryIcon, null),
          React.createElement('span', { style: { color: MUTED } }, 'Tue 11 Aug  10:24'),
        ),
      ),
      React.createElement('div', { style: { position: 'relative', height: 500 } }, children),
    ));
}

/* the send: a subtle dotted line traced across the gap between the panels — it stops
   at the device edge, never crossing on top of either */
function TransitDot({ t0, tEnd, ex, ty, T }) {
  const draw = clamp((T - (t0 + 1.7)) / 0.5, 0, 1);
  if (T < t0 + 1.7) return null;
  const p = Easing.easeInOutCubic(draw);
  const sx = 940, sy = 480;
  const op = 0.45 * MOTION.fade(tEnd - 0.3, tEnd)(T);
  /* the DMG's trail: a level row of dots growing in size and brightness toward the
     destination, revealed left to right as the send travels */
  const N = 9;
  /* the packet: a bright spot sweeping the trail; each dot eases up as the front
     reaches it, then settles, so arrival reads as travel rather than a reveal */
  return React.createElement('svg', { width: 2160, height: 960, style: { position: 'absolute', inset: 0, pointerEvents: 'none', opacity: op } },
    Array.from({ length: N }, (_, i) => {
      const f = i / (N - 1);
      const dp = Easing.easeOutCubic(clamp((p - f) * 4, 0, 1));
      if (dp <= 0) return null;
      const glow = Math.exp(-Math.pow((p - f) * 6, 2));
      return React.createElement('circle', {
        key: i,
        cx: sx + f * (ex - sx), cy: sy,
        r: (2 + f * 3.5) * (0.6 + 0.4 * dp) + glow * 2.5,
        fill: DIM, fillOpacity: dp * (0.2 + f * 0.6) + glow * 0.45,
      });
    }),
  );
}

/* the website's scroll-reveal, driven from T: each letter lights in turn and takes its
   time arriving — a soft front a few characters wide, resolving out of the ground */
const hexLerp = (a, b, p) => {
  const c = i => Math.round(parseInt(a.slice(i, i + 2), 16) * (1 - p) + parseInt(b.slice(i, i + 2), 16) * p);
  return `rgb(${c(1)},${c(3)},${c(5)})`;
};
function ResolveTitle({ T, t0, lines, opacity, top = 88 }) {
  /* the headline arrives whole: one soft fade, no per-letter reveal */
  const on = MOTION.enter(t0 + 0.2, t0 + 0.6)(T);
  return React.createElement('div', { style: { position: 'absolute', left: 90, top, fontFamily: SANS, fontSize: 42, fontWeight: 600, lineHeight: '58px', letterSpacing: -0.5, opacity: opacity * on } },
    lines.map((l, li) => React.createElement('div', { key: li, style: { color: l.to } }, l.text)),
  );
}

/* ── the piece ── */
const PASS = 3.5;
function Piece() {
  const { T, CUES, authoredTotal } = useComposition();
  const cues = [CUES.Deploy, CUES.Grafana, CUES.CI];
  const holdAt = CUES.Hold;

  const p1 = [
    [{ t: '# a deploy script sends one curl when it finishes', c: DIM }],
    [{ t: '$ ', c: DIM }, { t: 'curl notifi.it/send \\', c: FG }],
    [{ t: '    -d key=', c: FG }, { t: 'nk_live_8f3a', c: RED }, { t: ' \\', c: FG }],
    [{ t: '    -d title=', c: FG }, { t: '"Deploy finished"', c: BLUE }, { t: ' \\', c: FG }],
    [{ t: '    -d message=', c: FG }, { t: '"prod – 2m 41s"', c: BLUE }, { t: ' \\', c: FG }],
    [{ t: '    -d link=', c: FG }, { t: 'https://console.internal/deploys', c: BLUE }],
  ];
  const p2 = [
    [{ t: '# a training run posts its result, chart attached', c: DIM }],
    [{ t: 'loss = train(epochs=48)', c: FG }, { t: '   # 0.041', c: DIM }],
    [{ t: 'requests.post(', c: FG }, { t: '"https://notifi.it/send"', c: BLUE }, { t: ', data={', c: FG }],
    [{ t: '    "title"', c: BLUE }, { t: ': ', c: FG }, { t: 'f"Training finished – loss {loss}"', c: BLUE }, { t: ',', c: FG }],
    [{ t: '    "key"', c: BLUE }, { t: ': os.environ[', c: FG }, { t: '"NOTIFI_KEY"', c: RED }, { t: ']},', c: FG }],
    [{ t: '  files={', c: FG }, { t: '"image"', c: BLUE }, { t: ': open(', c: FG }, { t: '"loss-curve.png"', c: BLUE }, { t: ', ', c: FG }, { t: '"rb"', c: BLUE }, { t: ')})', c: FG }],
  ];
  const p3 = [
    [{ t: '# a CI step fires only when the build fails', c: DIM }],
    [{ t: '- name: ', c: BLUE }, { t: 'notify', c: FG }],
    [{ t: '  if: ', c: BLUE }, { t: 'failure()', c: FG }],
    [{ t: '  run: ', c: BLUE }, { t: '|', c: DIM }],
    [{ t: '    curl notifi.it/send -d key=', c: FG }, { t: '$NOTIFI_KEY', c: RED }, { t: ' \\', c: DIM }],
    [{ t: '      -d title=', c: FG }, { t: '"Build failed"', c: BLUE }, { t: ' -d link=', c: FG }, { t: '$RUN_URL', c: BLUE }],
  ];
  const passes = [
    { lines: p1, mode: 'lines', title: '~/deploy.sh' },
    { lines: p2, mode: 'lines', title: '~/train.py' },
    { lines: p3, mode: 'lines', title: '.github/workflows/ci.yml' },
  ];

  /* content windows: fade in first 0.25s of pass, out over last 0.3s */
  const termOp = i => win(T, cues[i], cues[i] + 0.25, cues[i] + PASS - 0.3, cues[i] + PASS);
  /* banner: the packet arrives at +2.2 and the banner springs in */
  const bannerOn = i => {
    const t0 = cues[i] + 2.2;
    return { progress: clamp((T - t0) / 0.7, 0, 1), opacity: (T >= t0 ? 1 : 0) * MOTION.fade(cues[i] + PASS - 0.3, cues[i] + PASS)(T), top: 0 };
  };

  /* device opacities; iPhone also owns the Hold beat so the loop seam lands on it */
  const opPhone = Math.max(win(T, 0, 0.001, CUES.Grafana - 0.25, CUES.Grafana + 0.05), MOTION.enter(holdAt + 0.15, holdAt + 0.45)(T));
  const opPad = win(T, CUES.Grafana - 0.05, CUES.Grafana + 0.3, CUES.CI - 0.25, CUES.CI + 0.05);
  const opMac = win(T, CUES.CI - 0.05, CUES.CI + 0.3, holdAt + 0.05, holdAt + 0.4);

  /* the Mac bell rings when its banner lands — the site's ring-body/ring-clapper tracks */
  const ringT = T - (cues[2] + 2.2);
  const ring = { body: ringT > 0 ? kfLerp(RING_BODY_T, RING_BODY_V, ringT) : 0, clapper: ringT > 0 ? kfLerp(RING_CLAP_T, RING_CLAP_V, ringT) : 0 };

  const grainFrame = Math.floor(T * 10) % 3;
  /* idle prompt shown during Hold + before typing starts */
  const idleOp = Math.max(MOTION.enter(holdAt, holdAt + 0.2)(T), T < 0.2 ? 1 - MOTION.enter(0.05, 0.2)(T) * 0 : 0) * (T > holdAt || T < CUES.Deploy + 0.16 ? 1 : 0);
  const idleCaretOn = Math.floor(T * 1.9) % 2 === 0;

  return React.createElement('div', { style: { position: 'absolute', inset: 0, background: BG, overflow: 'hidden', fontFamily: SANS } },
    /* grain */
    GRAIN.map((g, i) => React.createElement('div', { key: i, style: { position: 'absolute', inset: 0, backgroundImage: g, backgroundSize: '512px 512px', imageRendering: 'pixelated', opacity: grainFrame === i ? 1 : 0 } })),
    /* (no seam rule — the dotted send thread carries the left→right read) */

    /* one headline per pass, resolving out of the ground as its scene starts */
    [
      [{ text: 'Get a push notification to your device', to: '#EDEDED' }, { text: 'from anything that can make an HTTP request.', to: '#A1A1A1' }],
      [{ text: 'One key per device.', to: '#EDEDED' }, { text: 'Each iPhone, iPad or Mac gets its own address.', to: '#A1A1A1' }],
      [{ text: 'No signup, no SDK.', to: '#EDEDED' }, { text: 'Install the app, copy your key, start sending.', to: '#A1A1A1' }],
    ].map((lines, i) => React.createElement(ResolveTitle, { key: i, T, t0: cues[i], lines, opacity: termOp(i) })),
    /* left: terminal */
    React.createElement('div', { style: { position: 'absolute', left: 90, top: '50%', transform: 'translateY(-50%)', width: 830, height: 480 } },
      React.createElement(Terminal, { tabs: passes.map(p => p.title), active: T >= holdAt ? 0 : T >= cues[2] ? 2 : T >= cues[1] ? 1 : 0, opacity: 1 },
        passes.map((p, i) => React.createElement('div', { key: i, style: { position: 'absolute', top: 110, left: 0, right: 0, bottom: 0, opacity: termOp(i) } },
          React.createElement(TermBody, { mode: p.mode, lines: p.lines, resp: '{"ok":true}', t0: cues[i], T }))),
        /* idle prompt for the loop seam */
        React.createElement('div', { style: { position: 'absolute', top: 110, left: 0, right: 0, opacity: idleOp, padding: '30px 36px', fontFamily: MONO, fontSize: 28, lineHeight: '48px' } },
          React.createElement('span', { style: { color: DIM } }, '$ '),
          React.createElement('span', { style: { display: 'inline-block', width: 15, height: 30, background: RED, verticalAlign: '-4px', opacity: idleCaretOn ? 1 : 0 } })),
      )),

    /* right: devices */
    React.createElement('div', { style: { position: 'absolute', left: '47%', right: 0, top: 0, bottom: 0 } },
      React.createElement(IPhone, { opacity: opPhone },
        React.createElement(IosBanner, { w: 358, title: 'Deploy finished', body: 'prod – 2m 41s', on: bannerOn(0) })),
      React.createElement(IPad, { opacity: opPad },
        /* iPadOS banners are compact and top-centre, not full-width */
        React.createElement(IosBanner, { w: 400, title: 'Training finished', body: '48 epochs – loss 0.041', thumb: '../../apps/api/public/demo/loss-curve.png', on: bannerOn(1) })),
      React.createElement(Mac, { opacity: opMac, ring },
        React.createElement(MacBanner, { title: 'Build failed', body: 'tests (3.11) exited 1', on: bannerOn(2) })),
    ),
    /* the send in transit — stops at each device's left edge */
    React.createElement(TransitDot, { t0: cues[0], tEnd: cues[0] + PASS, ex: 1370, ty: 400, T }),
    React.createElement(TransitDot, { t0: cues[1], tEnd: cues[1] + PASS, ex: 1130, ty: 420, T }),
    React.createElement(TransitDot, { t0: cues[2], tEnd: cues[2] + PASS, ex: 1100, ty: 430, T }),
  );
}

window.NotifiLaunchGif = function NotifiLaunchGif() {
  return React.createElement(CompositionStage, { width: 2160, height: 960, bg: BG, scenes: window.OM_SCENES, playback: window.OM_PLAYBACK },
    React.createElement(Piece, null));
};
