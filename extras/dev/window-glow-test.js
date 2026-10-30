// Developer tool, not part of the theme. Tests the logic of WindowGlow.qml (which windows glow, the
// active window in cursor mode, distance to an edge, the pointer uniform for the shader) by extracting
// its functions from the real file and running them in node against a mock desktop. The
// distance from the pointer to the active window's edge is signed: negative inside. Each check was
// also confirmed to fail when the code is broken on purpose.
//   usage: node extras/dev/window-glow-test.js [path/to/WindowGlow.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/WindowGlow.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
const mk = (o) => Object.assign({ mapped: true, hidden: false, at: [0, 0], size: [100, 100], workspace: { id: 1 }, monitor: 0, focusHistoryID: 5, address: "0x0" }, o);
function make(clients, mon, over = {}) {
  const calls = { spill: 0, drain: 0, drainStop: 0, spillStop: 0 };
  const ctx = Object.assign({ rects: [], hyprMonitor: mon, styleBorder: 2, cursorMode: false, activeKey: "", smoothX: 0, smoothY: 0, calls,
    targetX: 0, targetY: 0, velX: 0, velY: 0, followRate: 32, pointerFollow: { running: false },
    edgeSide: "", poolKey: "", nearestV: [0, 0, 0, 1], curDist: 0, prevV: [0, 0, 0, 1], prevDist: 0, spill: 1, prevAmount: 0,
    spillAnim: { restart() { calls.spill++; }, stop() { calls.spillStop++; } }, drainAnim: { restart() { calls.drain++; }, stop() { calls.drainStop++; } },
    service: { pointer: { known: true, samples: 10 } }, Qt: { vector4d: (a, b, c, d) => Object.assign([a, b, c, d], { x: a, y: b, z: c, w: d }) } }, over);
  const Hyprland = { toplevels: { values: clients.map((o) => ({ lastIpcObject: o })) } };
  new Function("ctx", "Hyprland", "with (ctx) { Object.assign(ctx, {" + [grab("collect"), grab("edgeDistance"), grab("cursorUniform"), grab("nearestEdge"), grab("sideOf"), grab("sideDistance"), grab("sidePoint"), grab("trackPointer"), grab("springStep"), grab("stepPointer"), grab("retarget")].join(",") + "}); }")(ctx, Hyprland); return ctx;
}
let pass = 0, fail = 0; const eq = (n, g, w) => { const ok = JSON.stringify(g) === JSON.stringify(w); ok ? pass++ : (fail++, console.log("FAIL", n, "got", JSON.stringify(g), "want", JSON.stringify(w))); };
const mon0 = { id: 0, x: 0, y: 0, activeWorkspace: { id: 1 } }, mon1 = { id: 1, x: 1920, y: 0, activeWorkspace: { id: 5 } };
const clients = [
  mk({ address: "0xA", at: [10, 10], size: [500, 400], focusHistoryID: 2 }),
  mk({ address: "0xB", at: [600, 10], size: [300, 300], focusHistoryID: 0 }),                        // the active window
  mk({ address: "0xC", at: [50, 50], size: [10, 10], workspace: { id: 2 }, focusHistoryID: 1 }),     // other workspace
  mk({ address: "0xD", at: [2000, 100], size: [800, 600], monitor: 1, workspace: { id: 5 }, focusHistoryID: 3 }),
];
let c = make(clients, mon0); c.collect();
eq("all mode: every window on this screen, topmost first", c.rects.map((r) => r.a), ["0xB", "0xA"]); eq("all mode: no active key", c.activeKey, "");
c = make(clients, mon0, { cursorMode: true }); c.collect();
eq("cursor mode: only the active window", c.rects.map((r) => [r.a, r.x, r.y, r.w, r.h]), [["0xB", 598, 8, 304, 304]]); eq("cursor mode: active key set", c.activeKey, "0xB");
c = make(clients, mon1, { cursorMode: true }); c.collect();
eq("cursor mode: the active window is elsewhere, so nothing here", [c.rects.length, c.activeKey], [0, ""]);
const noFocus = clients.map((o) => ({ ...o, focusHistoryID: o.focusHistoryID + 1 })); c = make(noFocus, mon0, { cursorMode: true }); c.collect();
eq("cursor mode: nothing at focus 0 on this screen means nothing", c.rects.length, 0);

const r = { x: 100, y: 100, w: 400, h: 300 }; c = make([], mon0);
eq("edge distance, inside near the left (negative)", c.edgeDistance(130, 250, r), -30); eq("edge distance, inside near the bottom", c.edgeDistance(300, 390, r), -10);
eq("edge distance, the middle", c.edgeDistance(300, 250, r), -150); eq("edge distance, outside to the left (positive)", c.edgeDistance(60, 250, r), 40);
eq("edge distance, outside past a corner", c.edgeDistance(500 + 40, 400 + 30, r), 50); eq("edge distance, on the edge", c.edgeDistance(100, 200, r), 0);

c = make([], mon1, { cursorMode: true, rects: [{ x: 80, y: 100, w: 800, h: 600 }], smoothX: 2050, smoothY: 150, activeKey: "A" }); c.trackPointer();
eq("uniform: local coordinates, signed edge distance, on", c.cursorUniform(), [130, 150, -50, 1]);
c.service.pointer.known = false; eq("uniform: pointer unknown means off", c.cursorUniform(), [0, 0, 0, 0]); c.service.pointer.known = true;
c.rects = []; eq("uniform: no active window means off", c.cursorUniform(), [0, 0, 0, 0]); c.rects = [{ x: 80, y: 100, w: 800, h: 600 }];
c.cursorMode = false; eq("uniform: all mode means off", c.cursorUniform(), [0, 0, 0, 0]);
// the point of the edge nearest the pointer, and the edge's direction (x, y, tx, ty)
c = make([], mon0);
eq("nearest edge: left side, pointer inside", c.nearestEdge(130, 250, r), [100, 250, 0, 1]);
eq("nearest edge: right side", c.nearestEdge(470, 250, r), [500, 250, 0, 1]);
eq("nearest edge: top", c.nearestEdge(300, 120, r), [300, 100, 1, 0]);
eq("nearest edge: bottom", c.nearestEdge(300, 390, r), [300, 400, 1, 0]);
eq("nearest edge: outside, beside the left side", c.nearestEdge(60, 250, r), [100, 250, 0, 1]);
eq("nearest edge: outside, above the top", c.nearestEdge(300, 70, r), [300, 100, 1, 0]);
eq("nearest edge: past a corner, mostly to the side", c.nearestEdge(40, 80, r), [100, 100, 0, 1]);
eq("nearest edge: past a corner, mostly above", c.nearestEdge(80, 40, r), [100, 100, 1, 0]);
eq("nearest edge: on the edge", c.nearestEdge(100, 200, r), [100, 200, 0, 1]);
// ---- the pool's animation state
const R = { x: 0, y: 0, w: 1000, h: 600 };
const pool = (over = {}) => make([], mon0, Object.assign({ cursorMode: true, rects: [R], activeKey: "A" }, over));
const at = (c, x, y) => { c.smoothX = x; c.smoothY = y; c.trackPointer(); };
c = pool(); at(c, 500, 50);
eq("first pool: top edge, spills in", [c.edgeSide, c.calls.spill, c.prevAmount, c.nearestV, c.curDist], ["T", 1, 0, [500, 0, 1, 0], -50]);
at(c, 520, 60); eq("sliding along the same edge starts nothing", [c.calls.spill, c.calls.drain, c.nearestV[0]], [1, 0, 520]);
at(c, 500, 320); eq("crossing to the bottom edge: spill again, the top drains", [c.edgeSide, c.calls.spill, c.calls.drain, c.prevAmount, c.prevV, c.prevDist], ["B", 2, 1, 1, [520, 0, 1, 0], -60]);
eq("the new pool's own point and distance", [c.nearestV, c.curDist], [[500, 600, 1, 0], -280]);
at(c, 500, 300); eq("resting on the line between two edges does not flip it", [c.edgeSide, c.calls.spill], ["B", 2]);
at(c, 500, 270); eq("clearly nearer to the top again: flips", [c.edgeSide, c.calls.spill, c.calls.drain], ["T", 3, 2]);
c.activeKey = "B"; at(c, 500, 270); eq("a different window starts a fresh pool, with nothing draining", [c.calls.spill, c.prevAmount, c.poolKey], [4, 0, "B"]);
c = pool(); at(c, 500, 50); at(c, 500, 500); c.cursorMode = false; at(c, 500, 500);
eq("cursor mode off clears everything", [c.edgeSide, c.spill, c.prevAmount, c.nearestV], ["", 1, 0, [0, 0, 0, 1]]);
c = pool(); c.service.pointer.known = false; at(c, 500, 50); eq("pointer unknown: no pool", [c.edgeSide, c.calls.spill], ["", 0]);
c = pool(); at(c, 1200, 300); eq("pointer outside, beside the right side", [c.edgeSide, c.nearestV, c.curDist], ["R", [1000, 300, 0, 1], 200]);
at(c, 1200, 100); eq("outside: the nearest side wins at once (no hysteresis)", c.edgeSide, "R");
c = make([], mon1, { cursorMode: true, rects: [{ x: 80, y: 100, w: 800, h: 600 }], activeKey: "A" }); at(c, 2050, 150);
eq("uniform: local coordinates, the pool's distance, on", c.cursorUniform(), [130, 150, -50, 1]);
c.edgeSide = ""; eq("uniform: no pool means off", c.cursorUniform(), [0, 0, 0, 0]);
const RR = { x: 80, y: 100, w: 800, h: 600 }, v = (x, y, z, w) => ({ x, y, z, w });
eq("side of a rectangle", [c.sideOf(v(80, 300, 0, 1), RR), c.sideOf(v(880, 300, 0, 1), RR), c.sideOf(v(300, 100, 1, 0), RR), c.sideOf(v(300, 700, 1, 0), RR)], ["L", "R", "T", "B"]);

// ---- following the pointer: a critically damped spring stepped once per frame
const near = (n, g, w, tol) => { const ok = Math.abs(g - w) <= tol; ok ? pass++ : (fail++, console.log("FAIL", n, "got", g, "want", w, "+-", tol)); };
c = make([], mon0);
// the exact solution does not depend on how the time is cut up
let a1 = c.springStep(0, 0, 100, 32, 0.016); a1 = c.springStep(a1[0], a1[1], 100, 32, 0.016);
const a2 = c.springStep(0, 0, 100, 32, 0.032);
near("spring: two 16 ms steps equal one 32 ms step (x)", a1[0], a2[0], 1e-9); near("spring: ... and (v)", a1[1], a2[1], 1e-9);
// critically damped: from rest it approaches the target and never passes it
let st = [0, 0], over = 0; for (let i = 0; i < 400; i++) { st = c.springStep(st[0], st[1], 100, 32, 1 / 144); over = Math.max(over, st[0] - 100); }
eq("spring: no overshoot, and it arrives", [over <= 1e-9, Math.abs(st[0] - 100) < 1e-6], [true, true]);
// a steady sweep: constant speed is reproduced, trailing by about 2 / w
let sx = 0, sv = 0; const dtF = 1 / 144, sp = 1200; const speeds = [];
for (let i = 0; i < 288; i++) { const tg = sp * i * dtF; const p0 = sx; [sx, sv] = c.springStep(sx, sv, tg, 32, dtF); if (i > 72) speeds.push((sx - p0) / dtF); }
near("spring: steady sweep keeps the pointer's speed", speeds.reduce((s, q) => s + q) / speeds.length, sp, 5);
near("spring: and keeps it evenly", Math.max(...speeds) - Math.min(...speeds), 0, 5);
near("spring: lag behind a steady pointer is 2 / w less half a frame (the target holds across a step)", sp * 287 * dtF - sx, sp * 2 / 32 - sp * dtF / 2, 1);
// a long frame is clamped, and the frame clock stops once it has settled
c = make([], mon0, { cursorMode: true, rects: [R], activeKey: "A", targetX: 500, targetY: 50 }); c.pointerFollow.running = true;
c.stepPointer(10); const first = c.smoothX; eq("stepPointer: a 10 s frame counts as 50 ms", first > 0 && first < 500, true);
for (let i = 0; i < 600; i++) c.stepPointer(1 / 60);
eq("stepPointer: settles exactly on the target and stops the frame clock", [c.smoothX, c.smoothY, c.velX, c.velY, c.pointerFollow.running], [500, 50, 0, 0, false]);
// readings: the first few jump, later ones start the frame clock
c = make([], mon0, { cursorMode: true, rects: [R], activeKey: "A", targetX: 300, targetY: 200 }); c.service.pointer.samples = 2; c.retarget();
eq("retarget: an early reading jumps, with no frame clock", [c.smoothX, c.smoothY, c.pointerFollow.running], [300, 200, false]);
c.service.pointer.samples = 3; c.targetX = 340; c.retarget();
eq("retarget: a later one starts the frame clock and leaves the glow where it was", [c.smoothX, c.pointerFollow.running], [300, true]);
c = make([], mon0, { cursorMode: false, rects: [R], targetX: 300, targetY: 200 }); c.retarget();
eq("retarget: not in cursor mode there is nothing to smooth", [c.smoothX, c.pointerFollow.running], [300, false]);
c = make([], mon0, { cursorMode: true, rects: [], targetX: 300, targetY: 200 }); c.retarget();
eq("retarget: no window to light means no frame clock either", [c.smoothX, c.pointerFollow.running], [300, false]);
c = make([], mon0, { cursorMode: true, rects: [R], activeKey: "A", targetX: 500, targetY: 50 }); c.stepPointer(1 / 144);
eq("stepPointer: keeps the pool in step with the glow's position", [c.edgeSide, c.nearestV[1]], ["T", 0]);
console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
