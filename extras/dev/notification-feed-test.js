// Developer tool, not part of the theme. Tests the decision logic of NotificationFeed.qml (what
// counts as an arrival, an update, a stale file) by extracting its functions from the real file
// and running them in node against stubs.
//   usage: node extras/dev/notification-feed-test.js [path/to/NotificationFeed.qml]
const fs = require("fs"); const src = fs.readFileSync(process.argv[2] || __dirname + "/../plugin/annihilation.shimmer/NotificationFeed.qml", "utf8");
const grab = (name) => { const m = src.match(new RegExp("  function " + name + "\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}\\n")); if (!m) throw new Error("cannot find " + name); return m[0].replace("function " + name, name + ": function"); };
const prop = (name) => { const m = src.match(new RegExp("  property \\w+ " + name + ": (\\d+)")); if (!m) throw new Error("cannot find " + name); return Number(m[1]); };
function make() {
  const log = { reads: [], arrived: [] };
  const ctx = {
    dir: "/state/notifications", freshMs: prop("freshMs"), keepMs: prop("keepMs"), seen: {}, recent: [], arrivals: 0, pending: [],
    reader: { running: false, command: null, name: "", set runningSet(v) {} },
    arrived(e) { log.arrived.push(e); },
  };
  Object.defineProperty(ctx.reader, "running", { get() { return this._r || false; }, set(v) { this._r = v; if (v) log.reads.push(this.name); } });
  new Function("ctx", "with (ctx) { Object.assign(ctx, {" + [grab("ingest"), grab("enqueue"), grab("readNext")].join(",") + "}); }")(ctx);
  ctx.root = ctx; ctx.log = log; return ctx;
}
let pass = 0, fail = 0; const eq = (name, got, want) => { const ok = JSON.stringify(got) === JSON.stringify(want); ok ? pass++ : (fail++, console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want))); };
const file = (o) => JSON.stringify(Object.assign({ id: 1, originalId: 1, app: "Signal", summary: "Hello", body: "there", urgency: 1, expireTimeout: 0, timestamp: 1000000 }, o));
const NOW = 1000500;

let f = make();
eq("a fresh new file is an arrival", f.ingest("1000000-1.json", file(), NOW), "arrival");
eq("it signals once", f.log.arrived.length, 1);
eq("the signal carries the entry", [f.log.arrived[0].app, f.log.arrived[0].summary, f.log.arrived[0].urgency, f.log.arrived[0].timestamp], ["Signal", "Hello", 1, 1000000]);
eq("a rewrite of the same name is an update", f.ingest("1000000-1.json", file({ body: "changed" }), NOW + 50), "update");
eq("an update makes no second signal", [f.log.arrived.length, f.arrivals], [1, 1]);
eq("a second toast is another arrival", f.ingest("1000400-2.json", file({ id: 2, originalId: 2, timestamp: 1000400 }), NOW), "arrival");
eq("two signals now", f.arrivals, 2);
eq("recent is newest first", f.recent.map((r) => r.timestamp), [1000400, 1000000]);

f = make();
eq("an old file (restored after a restart) is stale", f.ingest("900000-1.json", file({ timestamp: 900000 }), NOW), "stale");
eq("stale makes no signal", [f.log.arrived.length, f.arrivals], [0, 0]);
eq("exactly at the limit still counts", f.ingest("a", file({ timestamp: NOW - f.freshMs }), NOW), "arrival");
eq("one past the limit does not", f.ingest("b", file({ timestamp: NOW - f.freshMs - 1 }), NOW), "stale");
eq("a stale name is not remembered, so a later fresh rewrite is judged on its own", f.seen["b"], undefined);

f = make();
eq("not JSON", f.ingest("x", "not json", NOW), "bad");
eq("empty", f.ingest("x", "", NOW), "bad");
eq("JSON with no summary", f.ingest("x", '{"app":"a"}', NOW), "bad");
eq("a bare number", f.ingest("x", "5", NOW), "bad");
eq("null", f.ingest("x", "null", NOW), "bad");
eq("a missing timestamp is stale, not an arrival", f.ingest("x", JSON.stringify({ summary: "s" }), NOW), "stale");
eq("bad files make no signal", f.arrivals, 0);

f = make();
f.ingest("c", file({ urgency: 2 }), NOW); f.ingest("d", file({ urgency: 0 }), NOW); f.ingest("e", file({ urgency: 7 }), NOW); f.ingest("g", file({ urgency: "x" }), NOW);
eq("urgency is kept for low and critical, and anything else is normal", f.log.arrived.map((e) => e.urgency), [2, 0, 1, 1]);
f.ingest("h", file({ summary: "s", body: undefined, app: undefined }), NOW);
eq("missing body and app become empty strings", [f.log.arrived[4].body, f.log.arrived[4].app], ["", ""]);

f = make(); for (let i = 0; i < 8; i++) f.ingest(i + "-1.json", file({ timestamp: NOW - 10 }), NOW);
eq("recent is trimmed to five", f.recent.length, 5);

f = make(); f.ingest("old.json", file(), NOW);
f.ingest("new.json", file({ timestamp: NOW + f.keepMs }), NOW + f.keepMs + 1);
eq("a name older than keepMs is forgotten", Object.keys(f.seen), ["new.json"]);
eq("so the same name can arrive again after that", f.ingest("old.json", file({ timestamp: NOW + f.keepMs + 2 }), NOW + f.keepMs + 3), "arrival");

// the read queue
f = make();
f.enqueue("notes.txt"); f.enqueue("../evil.json"); f.enqueue("1-2"); f.enqueue(""); f.enqueue("12345-6.json.tmp");
eq("only <stamp>-<id>.json names are read", [f.log.reads.length, f.pending.length], [0, 0]);
f.enqueue("100-1.json"); eq("the first name starts a read", [f.log.reads, f.reader.command], [["100-1.json"], ["cat", "--", "/state/notifications/100-1.json"]]);
f.enqueue("101-2.json"); f.enqueue("101-2.json"); f.enqueue("102-3.json");
eq("names queue behind a running read, without duplicates", [f.pending, f.log.reads.length], [["101-2.json", "102-3.json"], 1]);
f.reader.running = false; f.readNext();
eq("the next read starts when the reader is free", f.log.reads, ["100-1.json", "101-2.json"]);

console.log(fail === 0 ? `ALL ${pass} CHECKS PASS` : `${fail} FAILED, ${pass} passed`); process.exit(fail ? 1 : 0);
