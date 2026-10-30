// Which notifications went by unnoticed, for the bar prism and the popup.
//
// The notification service moves a toast into history/ when it leaves the screen (a `mv`, seen here
// as moved_to), and writes one it silenced for Do Not Disturb straight there (close_write). What
// happened to a toast shows in how long it was on screen:
//
//   silenced  written to history without ever being shown: missed
//   expired   on screen for its whole lifetime, so nobody acted on it: missed
//   acted     dismissed or clicked before then, or critical (those only leave when dismissed): not missed
//   own       Omarchy's own action toasts (a screenshot, a recording): the user did that, not missed
//
// A toast that sat on screen while you read it also counts as expired; there is no way to know.
// The list is written to `statePath` (newest first, at most ten, nothing older than a week) so the
// bar widget and the popup, which do not talk to the service, can read it, and so a shell restart
// does not lose it. `clear()` is what "seen" means; the popup asks for it by IPC when it opens.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property bool active: false
  property string historyDir: ""
  property string statePath: ""

  readonly property int maxMissed: 10
  readonly property int graceMs: 500          // a toast leaves a moment after its lifetime ends, never before
  readonly property int keepMs: 604800000     // a week
  property var missed: []                     // newest first: { name, app, summary, urgency, timestamp, kind }
  property var known: ({})                    // history file names already judged -> time judged
  property var pending: []                    // { name, kind } waiting to be read
  property bool watching: false
  property bool backoff: false
  property bool loaded: false

  // How long the service keeps a toast on screen, as Service.durationFor does in the notification
  // plugin: 0 for critical (until dismissed), otherwise at least 5 s (low) or 8 s, at most 30 s.
  function lifetimeFor(urgency, expire) {
    if (urgency === 2) return 0
    var asked = Number(expire)
    if (!isFinite(asked) || asked < 0) asked = 0
    return Math.min(30000, Math.max(urgency === 0 ? 5000 : 8000, asked))
  }

  // Judge one history file. kind is "moved" (a toast left the screen) or "written" (silenced).
  // Returns "missed", "acted", "own", "known" or "bad". `now` is in ms.
  function consider(name, kind, text, now) {
    var entry = null
    try { entry = JSON.parse(String(text)) } catch (e) { entry = null }
    if (!entry || typeof entry !== "object" || typeof entry.summary !== "string") return "bad"
    var stamp = Number(entry.timestamp)
    if (!isFinite(stamp)) return "bad"
    if (known[name] !== undefined) return "known"
    known[name] = now
    for (var key in known) if (now - known[key] > keepMs) delete known[key]

    if (entry.app === "omarchy-action") return "own"
    var urgency = Number(entry.urgency)
    urgency = urgency === 0 || urgency === 2 ? urgency : 1
    if (kind === "moved") {
      var life = lifetimeFor(urgency, entry.expireTimeout)
      if (life === 0 || now - stamp < life - graceMs) return "acted"
    }
    var item = { name: name, app: String(entry.app || ""), summary: entry.summary, urgency: urgency,
                 timestamp: stamp, kind: kind === "moved" ? "expired" : "silenced" }
    missed = [item].concat(missed).slice(0, maxMissed)
    saveSoon.restart()
    return "missed"
  }

  // The saved list back in, dropping anything malformed or older than a week.
  function restore(text, now) {
    var list = []
    try { list = JSON.parse(String(text)) } catch (e) { list = [] }
    if (!Array.isArray(list)) list = []
    missed = list.filter(function(m) {
      return m && typeof m.summary === "string" && isFinite(Number(m.timestamp)) && now - Number(m.timestamp) < keepMs
    }).slice(0, maxMissed)
    for (var i = 0; i < missed.length; i++) known[missed[i].name] = now
    loaded = true
  }

  function clear() {
    if (missed.length === 0) return
    missed = []
    saveSoon.restart()
  }

  function enqueue(line) {
    var m = String(line).trim().match(/^(\S+)\|([0-9]+-[0-9]+\.json)$/)
    if (!m) return
    var kind = m[1].indexOf("MOVED_TO") >= 0 ? "moved" : (m[1].indexOf("CLOSE_WRITE") >= 0 ? "written" : "")
    if (kind === "") return
    for (var i = 0; i < pending.length; i++) if (pending[i].name === m[2]) return
    pending.push({ name: m[2], kind: kind })
    readNext()
  }

  function readNext() {
    if (reader.running || pending.length === 0) return
    var next = pending.shift()
    reader.name = next.name
    reader.kind = next.kind
    reader.command = ["cat", "--", root.historyDir + "/" + next.name]
    reader.running = true
  }

  FileView {
    path: root.statePath
    printErrors: false
    onLoaded: root.restore(text(), Date.now())
    onLoadFailed: { root.loaded = true; saveSoon.restart() }
  }

  // Coalesce changes; the widget and popup see the file change and reload.
  Timer {
    id: saveSoon
    interval: 400
    onTriggered: {
      if (!root.loaded || root.statePath === "") return
      Quickshell.execDetached(["bash", "-c",
        "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\" || true",
        "--", root.statePath, JSON.stringify(root.missed)])
    }
  }

  // The directory may not exist before the first toast has been archived.
  Process {
    id: watcher
    running: root.active && root.historyDir !== "" && !root.backoff
    command: ["bash", "-c",
      "mkdir -p \"$1\" && exec inotifywait -m -q -e close_write -e moved_to --format '%e|%f' \"$1\"", "--", root.historyDir]
    stdout: SplitParser {
      onRead: function(line) { root.enqueue(line) }
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

  Timer {
    id: retry
    interval: 30000
    onTriggered: root.backoff = false
  }

  // A file can be trimmed from history by the time we read it; that is a miss, and fine.
  Process {
    id: reader
    property string name: ""
    property string kind: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.length > 0) root.consider(reader.name, reader.kind, text, Date.now())
      }
    }
    onRunningChanged: if (!running) root.readNext()
  }
}
