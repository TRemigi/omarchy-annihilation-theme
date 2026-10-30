// Tells the plugin when a notification toast arrives, without touching the notification daemon.
//
// The first-party service writes one compact JSON file per live toast into `dir`
// (<timestamp>-<id>.json), once when the toast appears and again if the sender updates it, and
// moves it to history/ when it leaves. DND-silenced notifications never get a file here. So a
// new file name, seen while the toast is still fresh, is an arrival.
//
//   arrived(entry)   a toast just appeared; entry has app, summary, body, urgency (0 low, 1 normal,
//                    2 critical), timestamp, expireTimeout
//
// Rewrites of a known name are updates and make no signal. A file whose timestamp is older than
// `freshMs` is ignored: the service restores live toasts after a shell restart, and a restart must
// not replay a burst of effects. `watching` and `recent` are in `shimmer status`.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property bool active: false
  property string dir: ""

  property int freshMs: 5000      // a toast older than this when we see it is not an arrival
  property int keepMs: 600000     // how long a seen name is remembered
  property var seen: ({})         // file name -> time first seen
  property var recent: []         // newest first, trimmed to five: { app, summary, urgency, timestamp }
  property int arrivals: 0
  property var pending: []        // names waiting to be read
  property bool watching: false
  property bool backoff: false    // the watcher died; wait before starting it again

  signal arrived(var entry)

  // Decide what a file means. Returns "arrival", "update", "stale" or "bad". `now` is in ms.
  function ingest(name, text, now) {
    var entry = null
    try { entry = JSON.parse(String(text)) } catch (e) { entry = null }
    if (!entry || typeof entry !== "object" || typeof entry.summary !== "string") return "bad"
    if (seen[name] !== undefined) return "update"
    var stamp = Number(entry.timestamp)
    if (!isFinite(stamp) || now - stamp > freshMs) return "stale"
    seen[name] = now
    for (var key in seen) if (now - seen[key] > keepMs) delete seen[key]
    var urgency = Number(entry.urgency)
    var out = {
      app: String(entry.app || ""),
      summary: entry.summary,
      body: String(entry.body || ""),
      urgency: urgency === 0 || urgency === 2 ? urgency : 1,
      timestamp: stamp,
      expireTimeout: Number(entry.expireTimeout) || 0
    }
    recent = [{ app: out.app, summary: out.summary, urgency: out.urgency, timestamp: stamp }]
      .concat(recent).slice(0, 5)
    arrivals++
    arrived(out)
    return "arrival"
  }

  // Names come from inotify one at a time; reads are queued so two toasts in the same
  // millisecond are both read.
  function enqueue(name) {
    if (!/^[0-9]+-[0-9]+\.json$/.test(name)) return
    if (pending.indexOf(name) < 0) pending.push(name)
    readNext()
  }

  function readNext() {
    if (reader.running || pending.length === 0) return
    reader.name = pending.shift()
    reader.command = ["cat", "--", root.dir + "/" + reader.name]
    reader.running = true
  }

  // inotifywait needs the directory to exist, and the service may not have made it yet.
  Process {
    id: watcher
    running: root.active && root.dir !== "" && !root.backoff
    command: ["bash", "-c",
      "mkdir -p \"$1\" && exec inotifywait -m -q -e close_write --format %f \"$1\"", "--", root.dir]
    stdout: SplitParser {
      onRead: function(line) { root.enqueue(line.trim()) }
    }
    onRunningChanged: {
      root.watching = running
      if (!running) {
        root.pending = []
        if (root.active) {
          root.backoff = true
          retry.restart()
        }
      }
    }
  }

  // If the watcher dies (inotify limit, tool missing) try again now and then, but not in a loop.
  Timer {
    id: retry
    interval: 30000
    onTriggered: root.backoff = false
  }

  // A file can already be in history/ by the time we read it; that is a miss, and fine.
  Process {
    id: reader
    property string name: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) root.ingest(reader.name, text, Date.now())
      }
    }
    onRunningChanged: if (!running) root.readNext()
  }
}
