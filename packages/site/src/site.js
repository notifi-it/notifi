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
