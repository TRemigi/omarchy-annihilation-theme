// Developer tool, not part of the theme. Tests the logic of WindowGlow.qml (which windows glow, the
// active window in cursor mode, distance to an edge, the pointer uniform for the shader) by extracting
// its functions from the real file and running them in node against a mock desktop. Each check was
// also confirmed to fail when the code is broken on purpose.
//   usage: node extras/dev/window-glow-test.js [path/to/WindowGlow.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/WindowGlow.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
const mk = (o) => Object.assign({ mapped: true, hidden: false, at: [0, 0], size: [100, 100], workspace: { id: 1 }, monitor: 0, focusHistoryID: 5, address: "0x0" }, o);
function make(clients, mon, over = {}) {
  const ctx = Object.assign({ rects: [], hyprMonitor: mon, styleBorder: 2, cursorMode: false, activeKey: "", smoothX: 0, smoothY: 0,
    service: { pointer: { known: true } }, Qt: { vector4d: (a, b, c, d) => [a, b, c, d] } }, over);
  const Hyprland = { toplevels: { values: clients.map((o) => ({ lastIpcObject: o })) } };
  new Function("ctx", "Hyprland", "with (ctx) { Object.assign(ctx, {" + [grab("collect"), grab("edgeDistance"), grab("cursorUniform")].join(",") + "}); }")(ctx, Hyprland); return ctx;
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
eq("edge distance, inside near the left", c.edgeDistance(130, 250, r), 30); eq("edge distance, inside near the bottom", c.edgeDistance(300, 390, r), 10);
eq("edge distance, the middle", c.edgeDistance(300, 250, r), 150); eq("edge distance, outside to the left", c.edgeDistance(60, 250, r), 40);
eq("edge distance, outside past a corner", c.edgeDistance(500 + 40, 400 + 30, r), 50); eq("edge distance, on the edge", c.edgeDistance(100, 200, r), 0);

c = make([], mon1, { cursorMode: true, rects: [{ x: 80, y: 100, w: 800, h: 600 }], smoothX: 2050, smoothY: 150 });
eq("uniform: local coordinates, edge distance, on", c.cursorUniform(), [130, 150, 50, 1]);
c.service.pointer.known = false; eq("uniform: pointer unknown means off", c.cursorUniform(), [0, 0, 0, 0]); c.service.pointer.known = true;
c.rects = []; eq("uniform: no active window means off", c.cursorUniform(), [0, 0, 0, 0]); c.rects = [{ x: 80, y: 100, w: 800, h: 600 }];
c.cursorMode = false; eq("uniform: all mode means off", c.cursorUniform(), [0, 0, 0, 0]);
console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
