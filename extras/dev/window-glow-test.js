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
    edgeSide: "", poolKey: "", nearestV: [0, 0, 0, 1], curDist: 0, prevV: [0, 0, 0, 1], prevDist: 0, spill: 1, prevAmount: 0,
    spillAnim: { restart() { calls.spill++; }, stop() { calls.spillStop++; } }, drainAnim: { restart() { calls.drain++; }, stop() { calls.drainStop++; } },
    service: { pointer: { known: true } }, Qt: { vector4d: (a, b, c, d) => Object.assign([a, b, c, d], { x: a, y: b, z: c, w: d }) } }, over);
  const Hyprland = { toplevels: { values: clients.map((o) => ({ lastIpcObject: o })) } };
  new Function("ctx", "Hyprland", "with (ctx) { Object.assign(ctx, {" + [grab("collect"), grab("edgeDistance"), grab("cursorUniform"), grab("nearestEdge"), grab("sideOf"), grab("sideDistance"), grab("sidePoint"), grab("trackPointer")].join(",") + "}); }")(ctx, Hyprland); return ctx;
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
console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
