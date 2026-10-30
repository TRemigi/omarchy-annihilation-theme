// Where the pointer is, in Hyprland's global layout coordinates (the same space as window
// positions). Hyprland has no pointer event and a click-through layer cannot receive
// hover, so this polls, as cheaply as it can:
//
//   "socket"   asks Hyprland's request socket directly, the way hyprctl does, with no
//              process to start: microseconds a poll. This is the first choice.
//   "hyprctl"  starts `hyprctl cursorpos` instead: about 7 ms of CPU a poll, so it runs at
//              6 polls a second. Used automatically if the socket gives no usable answer.
//   "none"     neither worked. The glow then falls back to its uniform look.
//
// It polls only while `active`, about 60 times a second while the pointer moves and a few
// times a second once it has rested. `source` says which route is live, and is in the
// plugin's `shimmer status` output, which is how to tell what happened on a given machine.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
  id: root

  property bool active: false

  property real cursorX: 0
  property real cursorY: 0
  property bool known: false      // a position has been read
  property int samples: 0         // how many have been
  property int still: 0           // polls since the position last changed
  property string source: Hyprland.requestSocketPath !== "" ? "socket" : "hyprctl"
  property int failures: 0
  property bool awaiting: false   // a poll is in flight
  property string buffer: ""

  readonly property bool polling: active && source !== "none"
  // A poll waits for its own reply, so a slow answer only lowers the rate; it never queues.
  readonly property int pollInterval: source === "hyprctl" ? 160 : (still > 90 ? 150 : 16)

  // The first two numbers in the reply. Hyprland answers `cursorpos` with "x, y", and
  // with the j flag with JSON; either way the numbers come first and in x, y order.
  function parse(text) {
    var m = String(text === null || text === undefined ? "" : text).match(/-?\d+(?:\.\d+)?/g)
    if (!m || m.length < 2) return null
    var x = Number(m[0])
    var y = Number(m[1])
    if (!isFinite(x) || !isFinite(y) || Math.abs(x) > 1e6 || Math.abs(y) > 1e6) return null
    return [x, y]
  }

  // Every poll ends here, with the reply text or null for no reply. A late answer to a poll
  // already given up on is ignored.
  function settle(text) {
    if (!awaiting) return
    awaiting = false
    watchdog.stop()
    var p = text === null ? null : parse(text)
    if (!p) {
      failures++
      // Six misses in a row: this route does not work here. Try the next one.
      if (failures >= 6) {
        failures = 0
        source = source === "socket" ? "hyprctl" : "none"
      }
      return
    }
    failures = 0
    if (p[0] !== cursorX || p[1] !== cursorY) {
      still = 0
      cursorX = p[0]
      cursorY = p[1]
    } else {
      still++
    }
    known = true
    samples++
  }

  function pollOnce() {
    if (awaiting) return
    awaiting = true
    watchdog.restart()
    if (source === "socket") {
      buffer = ""
      sock.connected = true
    } else if (source === "hyprctl") {
      proc.running = true
    }
  }

  // Try the best route again whenever tracking is switched back on after a total failure.
  onActiveChanged: {
    if (active && source === "none") {
      failures = 0
      source = Hyprland.requestSocketPath !== "" ? "socket" : "hyprctl"
    }
  }

  Timer {
    interval: root.pollInterval
    running: root.polling
    repeat: true
    onTriggered: root.pollOnce()
  }

  // A poll that has not answered in half a second has failed.
  Timer {
    id: watchdog
    interval: 500
    onTriggered: {
      var wasWaiting = root.awaiting
      if (sock.connected) sock.connected = false
      if (wasWaiting) root.settle(null)
    }
  }

  // Hyprland answers one request per connection and then closes it.
  Socket {
    id: sock
    path: Hyprland.requestSocketPath
    parser: SplitParser {
      splitMarker: ""
      onRead: function(data) { root.buffer += data }
    }
    onConnectedChanged: {
      if (connected) {
        write("cursorpos")
        flush()
      } else {
        var reply = root.buffer
        root.buffer = ""
        root.settle(reply.length > 0 ? reply : null)
      }
    }
    onError: root.settle(null)
  }

  Process {
    id: proc
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: root.settle(text)
    }
  }
}
