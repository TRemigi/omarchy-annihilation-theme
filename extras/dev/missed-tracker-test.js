// Developer tool, not part of the theme. Tests MissedTracker.qml's judgement of what counts as a
// missed notification (expired, silenced, acted on, Omarchy's own), its list and its saved file,
// by extracting the real functions and running them in node against stubs.
//   usage: node extras/dev/missed-tracker-test.js [path/to/MissedTracker.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/MissedTracker.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
const num = (name) => { const m = src.match(new RegExp("readonly property int " + name + ": (\\d+)")); if (!m) throw new Error("cannot find " + name); return Number(m[1]); };
function make() {
  const log = { saves: 0, reads: [] };
  const ctx = { maxMissed: num("maxMissed"), graceMs: num("graceMs"), keepMs: num("keepMs"), missed: [], known: {}, pending: [], loaded: false,
    historyDir: "/state/history", saveSoon: { restart() { log.saves++; } }, reader: { name: "", kind: "", command: null } };
  Object.defineProperty(ctx.reader, "running", { get() { return this._r || false; }, set(v) { this._r = v; if (v) log.reads.push([this.name, this.kind]); } });
  new Function("ctx", "with (ctx) { Object.assign(ctx, {" + ["lifetimeFor", "consider", "restore", "clear", "enqueue", "readNext"].map(grab).join(",") + "}); }")(ctx);
  ctx.log = log; ctx.root = ctx; return ctx;
}
let pass = 0, fail = 0; const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };
const T = 1e12;
const file = (o) => JSON.stringify(Object.assign({ app: "Signal", summary: "Hello", body: "", urgency: 1, expireTimeout: 0, timestamp: T }, o));

let m = make();
eq("lifetimes: low 5 s, normal 8 s, critical never", [m.lifetimeFor(0, 0), m.lifetimeFor(1, 0), m.lifetimeFor(2, 0)], [5000, 8000, 0]);
eq("a longer request is honoured, up to 30 s", [m.lifetimeFor(1, 12000), m.lifetimeFor(1, 99999), m.lifetimeFor(0, 20000)], [12000, 30000, 20000]);
eq("a shorter request does not shorten it", m.lifetimeFor(1, 2000), 8000);
eq("junk timeouts are ignored", [m.lifetimeFor(1, -5), m.lifetimeFor(1, NaN), m.lifetimeFor(1, "x")], [8000, 8000, 8000]);

eq("a toast that left after its whole lifetime was missed", m.consider("a.json", "moved", file(), T + 8000), "missed");
eq("it is listed as expired", [m.missed.length, m.missed[0].kind, m.missed[0].app, m.missed[0].summary], [1, "expired", "Signal", "Hello"]);
eq("one that left a moment early still counts (grace)", m.consider("b.json", "moved", file({ timestamp: T + 1 }), T + 1 + 7500), "missed");
eq("dismissed or clicked at 3 s was acted on", m.consider("c.json", "moved", file({ timestamp: T + 2 }), T + 2 + 3000), "acted");
eq("acted on adds nothing", m.missed.length, 2);
eq("the edge: 7499 ms is acted, 7500 is missed", [m.consider("d.json", "moved", file({ timestamp: T + 3 }), T + 3 + 7499), m.consider("e.json", "moved", file({ timestamp: T + 4 }), T + 4 + 7500)], ["acted", "missed"]);
eq("a long-lifetime toast dismissed after 9 s was acted on", m.consider("f.json", "moved", file({ timestamp: T + 5, expireTimeout: 15000 }), T + 5 + 9000), "acted");
eq("critical toasts leave only by dismissal", m.consider("g.json", "moved", file({ timestamp: T + 6, urgency: 2 }), T + 6 + 60000), "acted");
eq("low urgency expires at 5 s", m.consider("h.json", "moved", file({ timestamp: T + 7, urgency: 0 }), T + 7 + 5000), "missed");
eq("newest first", m.missed.map((x) => x.name), ["h.json", "e.json", "b.json", "a.json"]);

m = make();
eq("a silenced notification is missed at once", m.consider("s.json", "written", file(), T + 10), "missed");
eq("and listed as silenced", m.missed[0].kind, "silenced");
eq("a critical one silenced is missed too", m.consider("s2.json", "written", file({ urgency: 2, timestamp: T + 1 }), T + 10), "missed");
eq("Omarchy's own toasts are never missed, however they left", [m.consider("o1.json", "moved", file({ app: "omarchy-action" }), T + 9e4), m.consider("o2.json", "written", file({ app: "omarchy-action", timestamp: T + 2 }), T + 10)], ["own", "own"]);
eq("the same name twice is counted once", [m.consider("s.json", "written", file({ summary: "again" }), T + 20), m.missed.filter((x) => x.name === "s.json").length], ["known", 1]);
eq("bad files are ignored", ["nope", "", "null", "5", '{"app":"x"}', JSON.stringify({ summary: "s" })].map((t) => m.consider("z.json", "moved", t, T)), Array(6).fill("bad"));
eq("bad files leave no trace", m.known["z.json"], undefined);
eq("urgency outside 0 to 2 counts as normal", (m.consider("u.json", "written", file({ urgency: 9, timestamp: T + 3 }), T + 10), m.missed[0].urgency), 1);

m = make(); for (let i = 0; i < 14; i++) m.consider(i + ".json", "written", file({ timestamp: T + i }), T + 100);
eq("at most ten are kept, the newest", [m.missed.length, m.missed[0].name, m.missed[9].name], [10, "13.json", "4.json"]);
eq("every judgement asks for a save", m.log.saves, 14);
m.clear(); eq("clear empties the list and saves", [m.missed.length, m.log.saves], [0, 15]);
m.clear(); eq("clearing an empty list does not save again", m.log.saves, 15);
eq("cleared names are still known, so they do not come back", m.consider("13.json", "written", file({ timestamp: T + 13 }), T + 200), "known");

m = make(); m.consider("k.json", "written", file(), T); m.consider("late.json", "written", file({ timestamp: T }), T + m.keepMs + 1);
eq("a judged name is forgotten after a week", Object.keys(m.known), ["late.json"]);

m = make();
m.restore(JSON.stringify([{ name: "a.json", summary: "old", timestamp: T - 8 * 86400000 }, { name: "b.json", app: "x", summary: "kept", timestamp: T - 1000 }, { summary: 5 }, null, "str"]), T);
eq("restore keeps the recent well-formed ones only", [m.missed.map((x) => x.summary), m.loaded], [["kept"], true]);
m = make(); m.restore("not json", T); eq("restore tolerates junk", [m.missed, m.loaded], [[], true]);
m = make(); m.restore('{"a":1}', T); eq("restore tolerates a non-array", m.missed, []);
m = make(); m.restore(JSON.stringify(Array.from({ length: 15 }, (_, i) => ({ name: i + ".json", summary: "s", timestamp: T - i }))), T);
eq("restore caps the list", m.missed.length, 10);
m.restore(JSON.stringify([{ name: "q.json", summary: "s", timestamp: T }]), T); eq("a restored name is known", m.consider("q.json", "written", file(), T), "known");

m = make();
m.enqueue("MOVED_TO|100-1.json"); eq("a moved line starts a read", [m.log.reads, m.reader.command], [[["100-1.json", "moved"]], ["cat", "--", "/state/history/100-1.json"]]);
m.enqueue("CLOSE_WRITE,CLOSE|101-2.json"); m.enqueue("CLOSE_WRITE,CLOSE|101-2.json");
eq("a written line queues, once", m.pending, [{ name: "101-2.json", kind: "written" }]);
m.reader.running = false; m.readNext(); eq("the queue goes on when the reader is free", m.log.reads[1], ["101-2.json", "written"]);
m = make(); ["DELETE|100-1.json", "MOVED_TO|notes.txt", "MOVED_TO|../x-1.json", "garbage", "", "MOVED_TO|1-2.json.tmp", "ISDIR|1-2.json"].forEach((l) => m.enqueue(l));
eq("deletes, odd names and junk lines are ignored", [m.log.reads.length, m.pending.length], [0, 0]);

console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
