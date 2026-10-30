// Developer tool, not part of the theme. Tests the bookkeeping of ArrivalGlow.qml (how long an
// arrival lasts, how strong it is, how many are kept, what the shader is told) by extracting its
// functions from the real file and running them in node against stubs.
//   usage: node extras/dev/arrival-glow-test.js [path/to/ArrivalGlow.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/ArrivalGlow.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
const num = (name) => { const m = src.match(new RegExp("readonly property \\w+ " + name + ": (\\d+)")); if (!m) throw new Error("cannot find " + name); return Number(m[1]); };
function make(width = 1880, reserved = [0, 30, 0, 0]) {
  const ctx = {
    events: [], nowMs: 0, maxEvents: num("maxEvents"), width, cardHalfWidth: num("cardHalfWidth"), cardHalfHeight: num("cardHalfHeight"),
    hyprMonitor: { lastIpcObject: { reserved } }, Style: { gapsOut: 10 },
    Qt: { vector4d: (x, y, z, w) => [x, y, z, w], vector2d: (x, y) => [x, y] },
  };
  new Function("ctx", "with (ctx) { Object.assign(ctx, {" + ["durationFor", "amplitudeFor", "addEvent", "live", "evAt", "originPoint", "tick"].map(grab).join(",") + "}); }")(ctx);
  return ctx;
}
let pass = 0, fail = 0; const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };
const near = (name, got, want, tol = 1e-9) => { const ok = Math.abs(got - want) <= tol; ok ? pass++ : (fail++, console.log("FAIL", name, "got", got, "want", want)); };
const T0 = 1e12, e = (urgency, app = "Signal") => ({ urgency, app });

let g = make();
eq("durations: low, normal, critical", [0, 1, 2].map((u) => g.durationFor(u)), [3200, 4200, 6000]);
near("normal strength", g.amplitudeFor(e(1), 1e9), 1);
near("low is fainter", g.amplitudeFor(e(0), 1e9), 0.6);
near("critical is stronger", g.amplitudeFor(e(2), 1e9), 1.3);
near("omarchy's own toasts are fainter", g.amplitudeFor(e(1, "omarchy-action"), 1e9), 0.7);
near("a burst is thinned", g.amplitudeFor(e(1), 399), 0.6);
near("not a burst at 400 ms", g.amplitudeFor(e(1), 400), 1);
near("both reductions compose", g.amplitudeFor(e(1, "omarchy-action"), 10), 0.42);

g.addEvent(e(1), T0);
eq("one arrival", [g.events.length, g.nowMs], [1, T0]);
eq("it is off before it starts and at progress 0 on the first frame", g.evAt(0, T0)[0], 0);
near("half way is progress 0.5", g.evAt(0, T0 + 2100)[0], 0.5);
eq("the shader gets urgency and amplitude", [g.evAt(0, T0 + 2100)[1], g.evAt(0, T0 + 2100)[2]], [1, 1]);
near("progress is clamped to 1", g.evAt(0, T0 + 99999)[0], 1);
near("and to 0 before the start", g.evAt(0, T0 - 500)[0], 0);
eq("an empty slot is off with zero amplitude", [g.evAt(1, T0)[0], g.evAt(1, T0)[2]], [0, 0]);
near("a second arrival right after is thinned", (g.addEvent(e(1), T0 + 100), g.events[1].amp), 0.6);
g.addEvent(e(1), T0 + 2000); g.addEvent(e(1), T0 + 3000);
eq("at most three are kept, newest last", [g.events.length, g.events[2].start], [3, T0 + 3000]);
eq("the oldest was dropped", g.events[0].start, T0 + 100);

g = make(); g.addEvent(e(1), T0); g.addEvent(e(0), T0 + 2000);
eq("live keeps what is still running", g.live(T0 + 4199).length, 2);
eq("live drops what has finished (normal 4200 from T0; low 3200 from T0 + 2000)", g.live(T0 + 4200).map((x) => x.urgency), [0]);
eq("and everything eventually", g.live(T0 + 9999).length, 0);
g = make(); g.addEvent(e(1), T0); g.addEvent(e(1), T0 + 5000);
eq("adding prunes a finished arrival first", [g.events.length, g.events[0].start], [1, T0 + 5000]);

g = make(1880, [0, 30, 0, 0]);
eq("the source sits half a card in from the right, below the bar", g.originPoint(), [1880 - 0 - 10 - 190, 30 + 10 + 34]);
g = make(1880, [0, 0, 28, 0]); eq("a right-hand bar moves it left", g.originPoint()[0], 1880 - 28 - 10 - 190);
g = make(1880, null); g.hyprMonitor = { lastIpcObject: null }; eq("no monitor data: no reservation", g.originPoint(), [1880 - 10 - 190, 10 + 34]);
g = make(1880, [0, 30]); eq("a short reserved array is ignored", g.originPoint(), [1880 - 10 - 190, 10 + 34]);

console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
