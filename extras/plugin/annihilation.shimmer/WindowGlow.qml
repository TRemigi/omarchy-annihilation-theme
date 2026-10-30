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
//
// In cursor mode (service.windowGlowMode) only the active window glows, faintly, and the
// span of its edge nearest the pointer is wider and brighter; the pointer comes from the
// service's CursorTracker and is smoothed here so the pool of light glides.

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

  // Topmost first, at most six, in this screen's logical pixels. In cursor mode: just the
  // active window, if it is on this screen.
  property var rects: []

  readonly property bool cursorMode: service.windowGlowMode === "cursor"
  // Which window is active, so that moving to another one can fade the glow in anew.
  property string activeKey: ""
  property real fade: 1

  // The pointer, smoothed. The first few readings jump, so the glow does not sweep in
  // from the corner of the screen when tracking starts.
  property real smoothX: service.pointer.cursorX
  property real smoothY: service.pointer.cursorY
  Behavior on smoothX { enabled: win.service.pointer.samples > 2; NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
  Behavior on smoothY { enabled: win.service.pointer.samples > 2; NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

  onCursorModeChanged: { refresh.restart(); trackPointer() }
  onActiveKeyChanged: { if (activeKey !== "") fadeIn.restart(); trackPointer() }
  onSmoothXChanged: trackPointer()
  onSmoothYChanged: trackPointer()
  onRectsChanged: trackPointer()

  Connections {
    target: win.service.pointer
    function onKnownChanged() { win.trackPointer() }
  }

  NumberAnimation { id: fadeIn; target: win; property: "fade"; from: 0; to: 1; duration: 350; easing.type: Easing.InOutSine }

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
      found.push({ x: o.at[0] - mon.x - b, y: o.at[1] - mon.y - b, w: o.size[0] + 2 * b, h: o.size[1] + 2 * b, z: o.focusHistoryID, a: String(o.address) })
    }
    found.sort(function(a, b) { return a.z - b.z })
    if (cursorMode) {
      // The active window is the most recently focused one (focusHistoryID 0), and only
      // counts here if it is on this screen.
      var active = found.length > 0 && found[0].z === 0 ? found[0] : null
      rects = active ? [active] : []
      activeKey = active ? active.a : ""
    } else {
      rects = found.slice(0, 6)
      activeKey = ""
    }
  }

  // How far a point is from the nearest edge of a rectangle: negative inside, positive
  // outside. The sign matters to the shader, which uses it to work out how far along the
  // edge each pixel is from the point nearest the pointer.
  function edgeDistance(cx, cy, r) {
    var dx = Math.max(r.x - cx, 0, cx - (r.x + r.w))
    var dy = Math.max(r.y - cy, 0, cy - (r.y + r.h))
    if (dx > 0 || dy > 0) return Math.sqrt(dx * dx + dy * dy)
    return -Math.min(cx - r.x, r.x + r.w - cx, cy - r.y, r.y + r.h - cy)
  }

  // The point of a rectangle's edge nearest a point, and the edge's unit direction there, as
  // x, y, tx, ty. Inside, the nearest of the four sides; outside, the nearest point of the
  // rectangle, and past a corner the side the pointer is more nearly beside.
  function nearestEdge(cx, cy, r) {
    var l = cx - r.x
    var rt = r.x + r.w - cx
    var t = cy - r.y
    var b = r.y + r.h - cy
    if (l >= 0 && rt >= 0 && t >= 0 && b >= 0) {
      var m = Math.min(l, rt, t, b)
      if (m === l) return Qt.vector4d(r.x, cy, 0, 1)
      if (m === rt) return Qt.vector4d(r.x + r.w, cy, 0, 1)
      if (m === t) return Qt.vector4d(cx, r.y, 1, 0)
      return Qt.vector4d(cx, r.y + r.h, 1, 0)
    }
    var qx = Math.min(Math.max(cx, r.x), r.x + r.w)
    var qy = Math.min(Math.max(cy, r.y), r.y + r.h)
    var dx = Math.abs(cx - qx)
    var dy = Math.abs(cy - qy)
    return dx >= dy ? Qt.vector4d(qx, qy, 0, 1) : Qt.vector4d(qx, qy, 1, 0)
  }

  // ---- The pool's animation.
  //
  // Which edge holds the pool is a discontinuous choice: when the pointer crosses the line
  // where another edge becomes the nearest, the pool would otherwise vanish from one and
  // appear at full strength on the other. So the pool is state here, not a function of the
  // pointer. The new edge's pool spills in (320 ms: it grows outward along the edge from the
  // point nearest the pointer while its light rises, and flares on the way; shaders/
  // windowglow.frag draws that from `spill`), and the old one drains away over 220 ms from
  // where it was.
  property string edgeSide: ""                              // L, R, T or B of the active window
  property string poolKey: ""                               // the window that pool belongs to
  property vector4d nearestV: Qt.vector4d(0, 0, 0, 1)       // its nearest point and direction
  property real curDist: 0                                  // the pointer's signed distance to it
  property vector4d prevV: Qt.vector4d(0, 0, 0, 1)          // the edge that held it before
  property real prevDist: 0
  property real spill: 1
  property real prevAmount: 0

  NumberAnimation { id: spillAnim; target: win; property: "spill"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
  NumberAnimation { id: drainAnim; target: win; property: "prevAmount"; from: 1; to: 0; duration: 220; easing.type: Easing.InOutSine }

  // Which side of a rectangle a point on its edge is on.
  function sideOf(q, r) {
    if (q.z === 0 && q.w === 1) return q.x <= r.x + r.w / 2 ? "L" : "R"
    return q.y <= r.y + r.h / 2 ? "T" : "B"
  }

  // How far a point is from the line of one side of a rectangle (positive inside).
  function sideDistance(cx, cy, r, side) {
    if (side === "L") return cx - r.x
    if (side === "R") return r.x + r.w - cx
    if (side === "T") return cy - r.y
    return r.y + r.h - cy
  }

  // The point on one side of a rectangle nearest a point, and the side's direction there.
  function sidePoint(cx, cy, r, side) {
    var x = Math.min(Math.max(cx, r.x), r.x + r.w)
    var y = Math.min(Math.max(cy, r.y), r.y + r.h)
    if (side === "L") return Qt.vector4d(r.x, y, 0, 1)
    if (side === "R") return Qt.vector4d(r.x + r.w, y, 0, 1)
    if (side === "T") return Qt.vector4d(x, r.y, 1, 0)
    return Qt.vector4d(x, r.y + r.h, 1, 0)
  }

  // Called whenever the pointer, the window or the mode changes.
  function trackPointer() {
    var mon = hyprMonitor
    if (!cursorMode || !service.pointer.known || rects.length === 0 || !mon) {
      if (edgeSide !== "") {
        edgeSide = ""
        poolKey = ""
        nearestV = Qt.vector4d(0, 0, 0, 1)
        drainAnim.stop()
        spillAnim.stop()
        prevAmount = 0
        spill = 1
      }
      return
    }
    var r = rects[0]
    var cx = smoothX - mon.x
    var cy = smoothY - mon.y
    var q = nearestEdge(cx, cy, r)
    var side = sideOf(q, r)
    var inside = cx >= r.x && cx <= r.x + r.w && cy >= r.y && cy <= r.y + r.h
    var fresh = edgeSide === "" || poolKey !== activeKey
    // A pointer resting near the line between two edges would flip the pool back and forth;
    // the held edge stays until another is clearly nearer.
    if (!fresh && inside && side !== edgeSide
        && sideDistance(cx, cy, r, edgeSide) - sideDistance(cx, cy, r, side) < 24) {
      side = edgeSide
      q = sidePoint(cx, cy, r, side)
    }
    if (fresh) {
      drainAnim.stop()
      prevAmount = 0
      edgeSide = side
      poolKey = activeKey
      spillAnim.restart()
    } else if (side !== edgeSide) {
      prevV = nearestV
      prevDist = curDist
      prevAmount = 1
      drainAnim.restart()
      edgeSide = side
      spillAnim.restart()
    }
    nearestV = q
    curDist = inside ? -sideDistance(cx, cy, r, side) : edgeDistance(cx, cy, r)
  }

  // The pointer for the shader: x, y on this screen, its signed distance to the edge that holds
  // the pool, and 1 when the cursor effect applies (0 gives the uniform glow).
  function cursorUniform() {
    var mon = hyprMonitor
    if (!cursorMode || !service.pointer.known || rects.length === 0 || !mon || edgeSide === "")
      return Qt.vector4d(0, 0, 0, 0)
    return Qt.vector4d(smoothX - mon.x, smoothY - mon.y, curDist, 1)
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
    property vector4d cursor: win.cursorUniform()
    property vector4d nearest: win.nearestV
    property vector4d nearestPrev: win.prevV
    property vector4d pools: Qt.vector4d(win.spill, win.prevAmount, win.prevDist, 0)
    property real cursorSpan: win.service.windowGlowSpan
    property real depth: win.service.windowGlowDepth
    property real centerGain: win.service.windowGlowCenter
    opacity: win.fade
    property vector4d win0: win.rectAt(0)
    property vector4d win1: win.rectAt(1)
    property vector4d win2: win.rectAt(2)
    property vector4d win3: win.rectAt(3)
    property vector4d win4: win.rectAt(4)
    property vector4d win5: win.rectAt(5)

    fragmentShader: Qt.resolvedUrl("shaders/windowglow.frag.qsb")
  }
}
