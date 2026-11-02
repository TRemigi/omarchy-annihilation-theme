.pragma library

// Root-like veins that start at the edges of a canvas and grow inward, branching, for the
// screensaver's background. Drawn once per activation into a canvas that the bloom shader
// reads (see Veins.qml). Pure: it only calls the 2D context, so it runs under node for tests.
//
// Each short stroke carries what the shader needs in its colour:
//   r  how far along its vein it is, counted from when the vein starts and in units of
//      `reach` pixels, so the shader can reveal veins progressively (red = 255 is `reach` away)
//   g  its thickness, for shading
//   b  a per-branch random value, so neighbouring veins differ in tint
// Veins stop when they reach the clear box in the middle, where the words are.

var STEP = 2.5

function rng(seed) {
  var a = (seed >>> 0) || 1
  return function() {
    a = (a + 0x6D2B79F5) >>> 0
    var t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// hx, hy: half size of the clear box as fractions of the canvas. Returns the number of
// strokes drawn.
function grow(ctx, w, h, seed, hx, hy) {
  var rand = rng(seed)
  var reach = 0.62 * h                    // path length (pixels) that red = 255 stands for
  var thick = Math.max(2.0, h / 160)      // trunk width, in canvas pixels
  var count = 0
  var queue = []

  function inside(x, y) {
    return Math.abs(x - w / 2) < hx * w && Math.abs(y - h / 2) < hy * h
  }

  // How far a point is from the clear box, in pixels (0 inside).
  function boxGap(x, y) {
    var dx = Math.max(0, Math.abs(x - w / 2) - hx * w)
    var dy = Math.max(0, Math.abs(y - h / 2) - hy * h)
    return Math.sqrt(dx * dx + dy * dy)
  }

  // Trunks: spread round the edges, in proportion to their length, each starting a little
  // after the last so the growth does not begin everywhere at once.
  var trunks = Math.round(15 * (w + h) / (2 * h))
  for (var i = 0; i < trunks; i++) {
    var u = (i + 0.2 + 0.6 * rand()) / trunks * (2 * w + 2 * h)
    var x, y, a
    if (u < w) { x = u; y = 1; a = Math.PI / 2 }
    else if (u < 2 * w) { x = u - w; y = h - 1; a = -Math.PI / 2 }
    else if (u < 2 * w + h) { x = 1; y = u - 2 * w; a = 0 }
    else { x = w - 1; y = u - 2 * w - h; a = Math.PI }
    a += (rand() - 0.5) * 0.9
    queue.push({ x: x, y: y, a: a, a0: a, av: 0, width: thick * (0.8 + 0.5 * rand()), life: reach * (0.55 + 0.45 * rand()),
                 off: rand() * 0.28 * reach, depth: 0, tint: rand() })
  }

  while (queue.length > 0) {
    var b = queue.pop()
    var total = b.life
    var walked = 0
    while (b.life > 0) {
      var nx = b.x + Math.cos(b.a) * STEP
      var ny = b.y + Math.sin(b.a) * STEP
      if (nx < -4 || nx > w + 4 || ny < -4 || ny > h + 4 || inside(nx, ny)) break
      walked += STEP
      // Near the box a vein tires: it thins out and ends on the way in, not at a line.
      var gap = boxGap(nx, ny)
      b.life -= STEP * (gap < 0.12 * h ? 1 + (0.12 * h - gap) / (0.025 * h) : 1)
      var wd = Math.max(0.8, b.width * (1 - 0.6 * (walked / total)))
      var s = Math.min(1, (b.off + walked) / reach)
      ctx.strokeStyle = "rgb(" + Math.round(s * 255) + "," + Math.min(255, Math.round(wd / (2.5 * thick) * 255)) + "," + Math.round(b.tint * 255) + ")"
      ctx.lineWidth = wd
      ctx.beginPath()
      ctx.moveTo(b.x, b.y)
      ctx.lineTo(nx, ny)
      ctx.stroke()
      count++
      b.x = nx
      b.y = ny
      // A gentle wander that cannot loop: the heading is pulled back toward where the vein was
      // going, and trunks lean a little toward the middle.
      var lean = b.depth === 0 ? Math.sin(Math.atan2(h / 2 - b.y, w / 2 - b.x) - b.a) * 0.012 : 0
      b.av = b.av * 0.9 + (rand() - 0.5) * 0.09 - 0.05 * Math.sin(b.a - b.a0) + lean
      b.a += b.av

      // Side branches, fewer and finer the deeper they are.
      if (b.depth < 4 && rand() < 0.045 * Math.pow(0.85, b.depth)) {
        var side = rand() < 0.5 ? -1 : 1
        var fork = b.a + side * (0.35 + 0.45 * rand())
        queue.push({ x: b.x, y: b.y, a: fork, a0: fork, av: 0, width: wd * 0.66,
                     life: Math.min(b.life, reach * 0.35) * (0.4 + 0.5 * rand()), off: b.off + walked,
                     depth: b.depth + 1, tint: rand() })
      }
    }
  }
  return count
}

if (typeof module !== "undefined") module.exports = { grow: grow, rng: rng }
