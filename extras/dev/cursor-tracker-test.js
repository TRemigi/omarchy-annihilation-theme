// Developer tool, not part of the theme. Tests the logic of CursorTracker.qml (reply parsing and
// the miss and fallback state machine) by extracting its functions from the real file and
// running them in node against stubs. Each check was also confirmed to fail when the code is
// broken on purpose.   usage: node extras/dev/cursor-tracker-test.js [path/to/CursorTracker.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/CursorTracker.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
function make(socketPath = "/run/user/1000/hypr/x/.socket.sock") {
  const log = { watchdogStops: 0, watchdogStarts: 0, socketUp: 0, proc: 0 };
  const ctx = {
    cursorX: 0, cursorY: 0, known: false, samples: 0, still: 0, failures: 0, awaiting: false, buffer: "", active: false,
    source: socketPath !== "" ? "socket" : "hyprctl",
    watchdog: { stop() { log.watchdogStops++; }, restart() { log.watchdogStarts++; } },
    sock: { set connected(v) { if (v) log.socketUp++; }, get connected() { return false; } },
    proc: { set running(v) { if (v) log.proc++; } },
  };
  new Function("ctx", "with (ctx) { Object.assign(ctx, {" + [grab("parse"), grab("settle"), grab("pollOnce")].join(",") + "}); }")(ctx);
  ctx.log = log; return ctx;
}
let pass = 0, fail = 0; const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };

const t = make();
eq("plain reply", t.parse("1234, 567"), [1234, 567]);
eq("json reply", t.parse('{\n\t"x": 1234,\n\t"y": 567\n}'), [1234, 567]);
eq("compact json", t.parse('{"x": 12, "y": 34}'), [12, 34]);
eq("negative (monitor to the left)", t.parse("-120, 80"), [-120, 80]);
eq("decimals", t.parse("100.5, 200.25"), [100.5, 200.25]);
eq("trailing newline", t.parse("5, 6\n"), [5, 6]);
eq("empty", t.parse(""), null); eq("null", t.parse(null), null); eq("undefined", t.parse(undefined), null);
eq("words only", t.parse("unknown request"), null); eq("one number", t.parse("12"), null);
eq("absurd", t.parse("99999999, 1"), null);

// success path
let c = make(); c.pollOnce(); eq("a poll goes out on the socket", [c.awaiting, c.log.socketUp, c.log.watchdogStarts], [true, 1, 1]);
c.pollOnce(); eq("no second poll while one is in flight", c.log.socketUp, 1);
c.settle("100, 200"); eq("reply accepted", [c.cursorX, c.cursorY, c.known, c.samples, c.still, c.awaiting], [100, 200, true, 1, 0, false]);
c.pollOnce(); c.settle("100, 200"); eq("an unmoved pointer counts as still", [c.still, c.samples], [1, 2]);
c.pollOnce(); c.settle("101, 200"); eq("moving resets still", [c.still, c.cursorX], [0, 101]);
c.settle("5, 5"); eq("a reply with no poll in flight is ignored", [c.cursorX, c.samples], [101, 3]);

// failure and fallback
c = make(); for (let i = 0; i < 5; i++) { c.pollOnce(); c.settle(null); }
eq("five misses stay on the socket", [c.source, c.failures], ["socket", 5]);
c.pollOnce(); c.settle(null); eq("six misses fall back to hyprctl", [c.source, c.failures], ["hyprctl", 0]);
c.pollOnce(); eq("the fallback spawns a process", c.log.proc, 1);
c.settle("7, 8"); eq("the fallback works", [c.cursorX, c.cursorY, c.known], [7, 8, true]);
c = make(); for (let i = 0; i < 12; i++) { c.pollOnce(); c.settle(""); }
eq("twelve misses in all end at none", c.source, "none");
c = make(); for (let i = 0; i < 5; i++) { c.pollOnce(); c.settle(null); } c.pollOnce(); c.settle("1, 2"); for (let i = 0; i < 5; i++) { c.pollOnce(); c.settle(null); }
eq("a success resets the miss count", [c.source, c.failures], ["socket", 5]);
c = make(); c.pollOnce(); c.settle("garbage"); eq("an unparseable reply counts as a miss", c.failures, 1);
c = make(""); eq("no socket path starts on hyprctl", c.source, "hyprctl");
console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
