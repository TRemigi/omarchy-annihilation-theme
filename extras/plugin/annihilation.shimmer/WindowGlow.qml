// Light spilling over the edges of windows, as if it came from behind them: a
// click-through layer ABOVE the windows that draws only a thin band along each
// window's edge (shaders/windowglow.frag). Where the light comes from is the
// shader's business; this file tells it where the windows are.
//
// Window rectangles come from Hyprland over Quickshell. They are refreshed on the
// events that change them, and on a slow timer for the one change that raises no
// event (an interactive resize), so during a resize the glow lags until it ends.
// The windows are sorted by focus history, most recent first, as a stand-in for
// stacking order. Hidden while a fullscreen window covers the screen.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: win

  required property var service

  readonly property real renderScale: 0.75
  readonly property var hyprMonitor: Hyprland.monitorFor(screen)
  readonly property bool fullscreenHere: !!(hyprMonitor && hyprMonitor.activeWorkspace
    && hyprMonitor.activeWorkspace.hasFullscreen)

  // How far the light reaches into a window, in logical pixels: a band that hugs the
  // edge the way a window shadow does, not a flood across the window.
  readonly property real rim: Math.max(16, Math.min(44, height * 0.026))

  // The windows' own corner radius and border width, read from Hyprland so that the
  // glow follows the real shape (and keeps doing so if the user changes them).
  property real styleRounding: 4
  property real styleBorder: 2

  // Topmost first, at most six, in this screen's logical pixels.
  property var rects: []

  readonly property var relevantEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2",
    "changefloatingmode", "fullscreen", "workspace", "workspacev2", "activewindow", "activewindowv2",
    "focusedmon", "monitoradded", "monitorremoved", "configreloaded", "moveworkspace", "moveworkspacev2"]

  function collect() {
    var mon = hyprMonitor
    if (!mon || !mon.activeWorkspace) { rects = []; return }
    var wsId = mon.activeWorkspace.id
    var found = []
    var all = Hyprland.toplevels.values
    for (var i = 0; i < all.length; i++) {
      var o = all[i].lastIpcObject
      if (!o || !o.mapped || o.hidden || !o.at || !o.size) continue
      if (!o.workspace || o.workspace.id !== wsId || o.monitor !== mon.id) continue
      // The border is drawn outside the window's own rectangle; start at its outer edge.
      var b = styleBorder
      found.push({ x: o.at[0] - mon.x - b, y: o.at[1] - mon.y - b, w: o.size[0] + 2 * b, h: o.size[1] + 2 * b, z: o.focusHistoryID })
    }
    found.sort(function(a, b) { return a.z - b.z })
    rects = found.slice(0, 6)
  }

  function rectAt(i) {
    return i < rects.length ? Qt.vector4d(rects[i].x, rects[i].y, rects[i].w, rects[i].h) : Qt.vector4d(0, 0, 0, 0)
  }

  // The part of the screen not reserved by bars: x, y, width, height.
  function usableRect() {
    var r = hyprMonitor && hyprMonitor.lastIpcObject ? hyprMonitor.lastIpcObject.reserved : null
    if (!r || r.length < 4) return Qt.vector4d(0, 0, width, height)
    return Qt.vector4d(r[0], r[1], width - r[0] - r[2], height - r[1] - r[3])
  }

  visible: service.running && service.windowGlow && !fullscreenHere && !service.screensaverActive
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}

  WlrLayershell.namespace: "annihilation-windowglow"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  onVisibleChanged: if (visible) { styleQuery.running = true; refresh.restart() }

  Process {
    id: styleQuery
    command: ["bash", "-c", "echo $(hyprctl getoption decoration:rounding -j | jq -r .int) $(hyprctl getoption general:border_size -j | jq -r .int)"]
    stdout: StdioCollector {
      onStreamFinished: {
        var p = String(text).trim().split(/\s+/).map(Number)
        if (p.length >= 2 && isFinite(p[0]) && isFinite(p[1])) {
          win.styleRounding = p[0]
          win.styleBorder = p[1]
          settle.restart()
        }
      }
    }
  }

  // Coalesce a burst of events into one refresh, then read the result once it lands.
  Timer {
    id: refresh
    interval: 60
    onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); settle.restart() }
  }

  Timer {
    id: settle
    interval: 140
    onTriggered: win.collect()
  }

  // Interactive resizes raise no event, so look now and then.
  Timer {
    interval: 1500
    running: win.visible
    repeat: true
    onTriggered: refresh.restart()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") styleQuery.running = true
      if (win.relevantEvents.indexOf(event.name) >= 0) refresh.restart()
    }
  }

  ShaderEffect {
    anchors.fill: parent

    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * win.renderScale)),
                               Math.max(1, Math.round(height * win.renderScale)))

    property real time: win.service.shimmerClock
    property real intensity: win.service.effectiveIntensity
    property real seed: win.service.shimmerSeed
    property real additive: win.service.layerAdditive ? 1.0 : 0.0
    property real rimWidth: win.rim
    property real rounding: win.styleRounding
    property size resolution: Qt.size(width, height)
    property vector4d usable: win.usableRect()
    property vector4d win0: win.rectAt(0)
    property vector4d win1: win.rectAt(1)
    property vector4d win2: win.rectAt(2)
    property vector4d win3: win.rectAt(3)
    property vector4d win4: win.rectAt(4)
    property vector4d win5: win.rectAt(5)

    fragmentShader: Qt.resolvedUrl("shaders/windowglow.frag.qsb")
  }
}
