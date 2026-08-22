
// The 404 glyph decaying, ported from GrainyBell in EmptyStateView.swift so the
// site and the app fail in the same visual language. Three things move, each on
// its own clock and each mostly idle:
//
//   grain    six tiles baked once and cycled at 12fps, as the ground static is
//   chroma   a horizontal split, 22% of the time, 11 times a second
//   glow     brief dropouts: a 13% chance of an episode 1.7 times a second,
//            and inside one a 40% chance per 18Hz frame of dimming
//
// The probabilities are the Swift ones unchanged. The shift is in em rather
// than px because the glyph is three times the bell's size and a fixed offset
// that reads as a fringe at 96px reads as a seam at 320.
(function(){
  var bell = document.querySelector(".bellmark");
  var solid = document.querySelector(".solid");
  if (!bell || !solid) return;

  var SIZE = 180;   // tile edge in CSS px, matching background-size

  function tile(dpr, px){
    var c = document.createElement("canvas");
    c.width = c.height = SIZE * dpr;
    var ctx = c.getContext("2d");
    var cell = px * dpr;
    for (var y = 0; y < c.height; y += cell){
      for (var x = 0; x < c.width; x += cell){
        if (Math.random() >= 0.5) continue;
        ctx.fillStyle = "rgba(255,255,255," + (Math.random() * 0.35).toFixed(3) + ")";
        ctx.fillRect(x, y, cell, cell);
      }
    }
    return "url(" + c.toDataURL("image/png") + ")";
  }

  // The still tile under the numeral. Opaque greys either side of mid, so
  // hard-light has something to darken with; the spread is the ground
  // static's, at a cell a third the size.
  function still(dpr){
    var c = document.createElement("canvas");
    c.width = c.height = SIZE * dpr;
    var ctx = c.getContext("2d");
    var img = ctx.createImageData(c.width, c.height);
    var d = img.data;
    for (var i = 0; i < d.length; i += 4){
      var v = 128 + (Math.random() - 0.5) * 2 * 34;
      d[i] = d[i+1] = d[i+2] = v; d[i+3] = 255;
    }
    ctx.putImageData(img, 0, 0);
    return "url(" + c.toDataURL("image/png") + ")";
  }

  var dpr = Math.min(window.devicePixelRatio || 1, 3);
  var frames = [];
  for (var i = 0; i < 6; i++) frames.push(tile(dpr, 2));
  bell.style.setProperty("--noise", frames[0]);
  solid.style.setProperty("--grain", still(dpr));

  // Reduce Motion keeps the grain — it is texture, not movement — and stops
  // everything that flickers, which is the whole of what could trigger anyone.
  var still = window.matchMedia("(prefers-reduced-motion: reduce)");
  var timer = null;
  var n = 0;
  var episode = false;

  function tick(){
    n++;
    bell.style.setProperty("--noise", frames[((n / 1.5) | 0) % frames.length]);

    if (n % 11 === 0) episode = Math.random() < 0.13;
    var dim = episode && Math.random() < 0.4;
    bell.style.setProperty("--glow", dim ? (0.35 + Math.random() * 0.27).toFixed(2) : "1");

    if (n % 2 === 0){
      var split = Math.random() < 0.22;
      bell.style.setProperty("--chroma", split ? "1" : "0");
      if (split) {
        bell.style.setProperty("--shift", (0.008 + Math.random() * 0.025).toFixed(4) + "em");
      }
    }
  }

  function apply(){
    if (timer) { clearInterval(timer); timer = null; }
    if (still.matches){
      bell.style.setProperty("--glow", "1");
      bell.style.setProperty("--chroma", "0");
      return;
    }
    timer = setInterval(tick, 1000 / 18);
  }
  still.addEventListener("change", apply);
  apply();

  document.addEventListener("visibilitychange", function(){
    if (document.hidden) { if (timer) { clearInterval(timer); timer = null; } }
    else apply();
  });
})();
