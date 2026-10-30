// Developer tool, not part of the theme. Tests the popup's unread list logic in Panel.qml (how ages
// read, which five entries are shown) by extracting the real functions and running them in node.
//   usage: node extras/dev/panel-missed-test.js [path/to/Panel.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/Panel.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
const ctx = {}; new Function("ctx", "with (ctx) { Object.assign(ctx, {" + ["ageText", "snapshot"].map(grab).join(",") + "}); }")(ctx);
let pass = 0, fail = 0; const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };
const M = 60000;
eq("under a minute", [0, 1, 59999].map(ctx.ageText), ["just now", "just now", "just now"]);
eq("a negative age (clock skew) is just now", ctx.ageText(-5000), "just now");
eq("minutes", [M, 12 * M, 59 * M + 59999].map(ctx.ageText), ["1 min ago", "12 min ago", "59 min ago"]);
eq("hours", [60 * M, 3 * 60 * M + 5 * M, 1439 * M].map(ctx.ageText), ["1 h ago", "3 h ago", "23 h ago"]);
eq("days", [1440 * M, 2.5 * 1440 * M].map(ctx.ageText), ["1 d ago", "2 d ago"]);
const T = 1e12, list = Array.from({ length: 8 }, (_, i) => ({ summary: "s" + i, app: "a" + i, kind: i % 2 ? "silenced" : "expired", timestamp: T - i * M, urgency: 1, name: i + ".json" }));
const s = ctx.snapshot(list, T);
eq("at most five, in order", s.map((x) => x.summary), ["s0", "s1", "s2", "s3", "s4"]);
eq("ages are worked out from the timestamps", s.map((x) => x.age), ["just now", "1 min ago", "2 min ago", "3 min ago", "4 min ago"]);
eq("silenced is flagged", s.map((x) => x.silenced), [false, true, false, true, false]);
eq("an empty list gives an empty snapshot", ctx.snapshot([], T), []);
console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
