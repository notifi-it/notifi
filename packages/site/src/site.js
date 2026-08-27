// The static. Six noise tiles are baked once and cycled at 12fps rather than a
// frame being generated per paint — real static never repeats, but at this
// amplitude the loop is invisible and the tiles cost nothing to redraw.
(function(){
  var cv = document.getElementById("static");
  if (!cv) return;
  var ctx = cv.getContext("2d", { alpha: false });

  var SIZE = 256;   // tile edge; large enough that the repeat forms no visible grid
  var CELL = 1;     // one speckle per device pixel — the finest the screen can draw
  var GROUND = 28;  // --bg, #1C1C1E
  var SPREAD = 14;  // ± either side. See the note on #static in the stylesheet.

  function tile(){
    var t = document.createElement("canvas");
    t.width = t.height = SIZE;
    var tc = t.getContext("2d");
    var img = tc.createImageData(SIZE, SIZE);
    var d = img.data;
    var g = SIZE / CELL;
    var cells = new Float32Array(g * g);
    for (var i = 0; i < cells.length; i++) cells[i] = Math.random();

    for (var y = 0; y < SIZE; y++){
      for (var x = 0; x < SIZE; x++){
        var cx = (x / CELL) | 0, cy = (y / CELL) | 0;
        var v = GROUND + (cells[cy*g + cx] - 0.5) * 2 * SPREAD;
        var o = (y*SIZE + x) * 4;
        d[o] = d[o+1] = d[o+2] = v; d[o+3] = 255;
      }
    }
    tc.putImageData(img, 0, 0);
    return ctx.createPattern(t, "repeat");
  }

  var frames = [], f = 0;
  for (var k = 0; k < 6; k++) frames.push(tile());

  function paint(){
    ctx.fillStyle = frames[f++ % frames.length];
    ctx.fillRect(0, 0, cv.width, cv.height);
  }

  function resize(){
    // Backing store at device resolution, so one speckle is one physical pixel
    // rather than one CSS pixel — on a 2x or 3x screen the latter is a visible
    // block, which reads as noise added to the page rather than grain in it.
    var dpr = Math.min(window.devicePixelRatio || 1, 3);
    var w = Math.floor(cv.clientWidth * dpr);
    var h = Math.floor(cv.clientHeight * dpr);
    if (!w || !h) return;               // nothing to paint into yet
    if (w === cv.width && h === cv.height) return;
    cv.width = w; cv.height = h;        // assigning either one clears the canvas
    paint();
  }

  // Measured off the element rather than the window, and observed rather than
  // waiting for a resize event: the canvas is laid out by CSS, and a page that
  // first paints at a zero or provisional viewport would otherwise stay blank
  // until something happened to resize the window.
  if (window.ResizeObserver) new ResizeObserver(resize).observe(cv);
  else window.addEventListener("resize", resize);
  resize();

  // Reduce Motion leaves one still frame. The crawl is the whole effect, so
  // there is nothing to soften — it simply stops.
  var still = window.matchMedia("(prefers-reduced-motion: reduce)");
  var timer = null;
  function apply(){
    if (timer) { clearInterval(timer); timer = null; }
    if (!still.matches) timer = setInterval(paint, 1000/12);
  }
  still.addEventListener("change", apply);
  apply();

  // setInterval is throttled but not stopped in a hidden tab, and a background
  // tab redrawing static is pure battery cost.
  document.addEventListener("visibilitychange", function(){
    if (document.hidden) { if (timer) { clearInterval(timer); timer = null; } }
    else apply();
  });
})();

// Headings and ledes light up word by word as they cross the viewport.
//
// The words are wrapped here rather than in the markup so the HTML stays
// readable and the text stays one string for anything that copies or reads it.
(function(){
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  // Opted out per page with <body data-reveal="off">: the 404 has to be
  // readable the instant it lands, not staged.
  if (document.body.dataset.reveal === "off") return;

  var targets = document.querySelectorAll("h2, .lede");
  if (!targets.length) return;

  var items = [];
  for (var t = 0; t < targets.length; t++) items.push(prepare(targets[t]));

  function prepare(el){
    // Walk the children rather than rewriting innerHTML: the headings contain
    // <br> and the ledes contain <code> and links, and all of that has to
    // survive the split intact.
    var nodes = [].slice.call(el.childNodes);
    for (var i = 0; i < nodes.length; i++){
      var node = nodes[i];
      if (node.nodeType !== 3) continue;             // element — leave it alone
      var parts = node.nodeValue.split(/(\s+)/);
      var frag = document.createDocumentFragment();
      for (var p = 0; p < parts.length; p++){
        if (!parts[p]) continue;
        if (/^\s+$/.test(parts[p])) { frag.appendChild(document.createTextNode(parts[p])); continue; }
        // A word span holds the line-breaking, and one span per character
        // inside it holds the reveal.
        var word = document.createElement("span");
        word.className = "w";
        for (var ch = 0; ch < parts[p].length; ch++){
          var c = document.createElement("span");
          c.className = "c";
          c.textContent = parts[p][ch];
          word.appendChild(c);
        }
        frag.appendChild(word);
      }
      el.replaceChild(frag, node);
    }
    el.classList.add("reveal", "armed");
    return { el: el, words: el.querySelectorAll(".c"), lit: -1 };
  }

  // The band the reveal happens over: a word is lit once the element has risen
  // from 88% of the viewport height to 45% of it. Ending well above the fold
  // means the last word lands while the reader is still approaching the text,
  // not after they have already read past it.
  var START = 0.88, END = 0.45;

  function frame(){
    var vh = window.innerHeight;
    for (var i = 0; i < items.length; i++){
      var it = items[i];
      var top = it.el.getBoundingClientRect().top / vh;
      var p = (START - top) / (START - END);
      p = p < 0 ? 0 : p > 1 ? 1 : p;
      var want = Math.round(p * it.words.length);
      if (want === it.lit) continue;
      // Only the words between the old and new marks are touched, so a fast
      // scroll costs a handful of class flips rather than a full rewrite.
      var from = it.lit < 0 ? 0 : it.lit;
      if (want > from) for (var j = from; j < want; j++) it.words[j].classList.add("on");
      else for (var k = from - 1; k >= want; k--) if (it.words[k]) it.words[k].classList.remove("on");
      it.lit = want;
    }
    ticking = false;
  }

  var ticking = false;
  function onScroll(){
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(frame);
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll);
  frame();
})();

// GrainyBell at link scale — the 404 glyph's decay on the pages' content
// links, with the odds of 404.js and the app unchanged: while hovered, an
// 18Hz tick re-rolls a 22% chance of misconvergence every other frame,
// cycles six grain tiles at 12fps, and dips the brightness inside rare
// episodes. At rest a link keeps a single tell — one brief split every few
// seconds — so the instability is part of what marks it as live.
//
// Links are only rebuilt into the layered form when it cannot cost them
// anything: plain text, short enough never to need a mid-link wrap (the
// layers require inline-block, which wraps as a unit), and on one line at
// build time. Everything else keeps the plain underline. The 404's own
// links stay quiet on purpose — that page's glyph is the effect.
(function(){
  if (document.body.classList.contains("notfound")) return;
  var links = [].filter.call(document.querySelectorAll(".doc a"), function(a){
    var text = a.textContent.trim();
    return a.children.length === 0 &&
           text.length > 0 && text.length <= 25 &&
           a.getClientRects().length === 1;
  });
  if (!links.length) return;

  var still = window.matchMedia("(prefers-reduced-motion: reduce)");

  // The grain tile: opaque greys either side of mid so hard-light has
  // something to darken with, at a cell fine enough for 16px glyphs.
  var SIZE = 60;
  var dpr = Math.min(window.devicePixelRatio || 1, 3);
  function tile(){
    var t = document.createElement("canvas");
    t.width = t.height = SIZE * dpr;
    var tc = t.getContext("2d");
    var img = tc.createImageData(t.width, t.height);
    var d = img.data;
    var cell = Math.max(1, Math.round(1.5 * dpr));
    for (var y = 0; y < t.height; y += cell){
      for (var x = 0; x < t.width; x += cell){
        var v = 128 + (Math.random() - 0.5) * 2 * 34;
        for (var dy = 0; dy < cell && y + dy < t.height; dy++){
          for (var dx = 0; dx < cell && x + dx < t.width; dx++){
            var o = ((y + dy) * t.width + (x + dx)) * 4;
            d[o] = d[o+1] = d[o+2] = v; d[o+3] = 255;
          }
        }
      }
    }
    tc.putImageData(img, 0, 0);
    return "url(" + t.toDataURL("image/png") + ")";
  }
  var frames = [];
  for (var i = 0; i < 6; i++) frames.push(tile());

  for (var k = 0; k < links.length; k++) build(links[k]);

  function build(a){
    var text = a.textContent;
    a.textContent = "";
    var layers = ["gghost gwarm", "gghost gcool", "gsolid"];
    for (var i = 0; i < layers.length; i++){
      var s = document.createElement("span");
      s.className = layers[i];
      s.textContent = text;
      if (layers[i] !== "gsolid") s.setAttribute("aria-hidden", "true");
      a.appendChild(s);
    }
    a.classList.add("glitch");
    a.style.setProperty("--ggrain", frames[0]);

    var timer = null, n = 0, episode = false;

    // The iOS bell's shift range in absolute pixels: the 404's em range is
    // sub-pixel at text sizes, and a fringe that cannot reach a pixel
    // simply is not there.
    function split(){
      a.style.setProperty("--gshift", (0.8 + Math.random() * 1.4).toFixed(2) + "px");
      a.style.setProperty("--gchroma", "1");
    }
    function tick(){
      n++;
      a.style.setProperty("--ggrain", frames[((n / 1.5) | 0) % frames.length]);
      if (n % 11 === 0) episode = Math.random() < 0.13;
      var dim = episode && Math.random() < 0.4;
      a.style.setProperty("--glow", dim ? (0.35 + Math.random() * 0.27).toFixed(2) : "1");
      if (n % 2 === 0){
        if (Math.random() < 0.22) split();
        else a.style.setProperty("--gchroma", "0");
      }
    }
    function start(){
      if (still.matches || timer) return;
      n = 0; episode = false;
      split();
      timer = setInterval(tick, 1000 / 18);
    }
    function stop(){
      if (timer){ clearInterval(timer); timer = null; }
      a.style.setProperty("--gchroma", "0");
      a.style.setProperty("--glow", "1");
    }
    a.addEventListener("mouseenter", start);
    a.addEventListener("mouseleave", stop);
    a.addEventListener("focus", start);
    a.addEventListener("blur", stop);

    (function tell(){
      setTimeout(function(){
        if (!timer && !still.matches && !document.hidden){
          split();
          setTimeout(function(){ if (!timer) a.style.setProperty("--gchroma", "0"); }, 90);
        }
        tell();
      }, 2500 + Math.random() * 3000);
    })();
  }
})();
