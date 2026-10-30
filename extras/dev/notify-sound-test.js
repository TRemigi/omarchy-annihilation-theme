// Developer tool, not part of the theme. Tests which tone a notification gets (Service.qml's
// soundFor and playArrival), by extracting the real functions and running them in node.
//   usage: node extras/dev/notify-sound-test.js [path/to/Service.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/Service.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
function make(over = {}) {
  const played = [];
  const ctx = Object.assign({ notifySound: true, notifySoundVolume: 0.5, screensaverActive: false, lastSoundMs: 0, dir: "/plugin/", played,
    Quickshell: { execDetached(cmd) { played.push(cmd); } } }, over);
  new Function("ctx", "with (ctx) { Object.assign(ctx, {" + ["soundFor", "playSound", "playArrival"].map(grab).join(",") + "}); }")(ctx);
  return ctx;
}
let pass = 0, fail = 0; const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };
const e = (urgency, app = "Signal") => ({ urgency, app });
const T = 1e12;

let s = make();
eq("normal gets arrive", s.soundFor(e(1), T), "arrive");
eq("low gets low", s.soundFor(e(0), T), "low");
eq("critical gets urgent", s.soundFor(e(2), T), "urgent");
eq("omarchy's own toasts are silent", [s.soundFor(e(1, "omarchy-action"), T), s.soundFor(e(0, "omarchy-action"), T)], ["", ""]);
eq("unless critical", s.soundFor(e(2, "omarchy-action"), T), "urgent");
eq("notify-send (any app) sounds", s.soundFor(e(1, "notify-send"), T), "arrive");
eq("off by default is the caller's setting: off means silent", make({ notifySound: false }).soundFor(e(2), T), "");
eq("silent under the screensaver", make({ screensaverActive: true }).soundFor(e(1), T), "");
s = make({ lastSoundMs: T - 999 }); eq("one a second: 999 ms after is too soon", s.soundFor(e(1), T), "");
s = make({ lastSoundMs: T - 1000 }); eq("1000 ms after is fine", s.soundFor(e(1), T), "arrive");

s = make(); s.playArrival(e(1));
eq("playing starts one player with the volume and the file", [s.played.length, s.played[0][3], s.played[0][4], s.played[0][5]], [1, "--", "0.5", "/plugin/sounds/arrive.ogg"]);
eq("the play time is recorded", s.lastSoundMs > 0, true);
s.playArrival(e(1)); eq("a second arrival right after is silent", s.played.length, 1);
s = make(); s.playArrival(e(1, "omarchy-action")); eq("a silent arrival plays nothing and records nothing", [s.played.length, s.lastSoundMs], [0, 0]);
s = make({ notifySoundVolume: 0.25 }); s.playSound("low"); eq("playSound ignores the gates and uses the volume", [s.played[0][4], s.played[0][5]], ["0.25", "/plugin/sounds/low.ogg"]);
eq("the command falls back to paplay", /pw-play .*\|\| paplay/.test(s.played[0][2]), true);
console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
