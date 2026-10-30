// A notification arrives and light spreads off the toast: a click-through layer above the windows
// and under the toast overlay (so the card hides the middle of it), drawn by shaders/arrival.frag
// only while an arrival is under way. The toast column sits top right, under the bar if the bar is
// on top or right; the card is about 380 px wide and its height depends on its text, so the light
// is anchored to a source box near the top of that column and not fitted to the card.
//
// Arrivals come from the service's NotificationFeed. At most three are drawn at once; a burst
// is thinned so it does not stack into a flash, and Omarchy's own action toasts (screenshots and
// recordings, which the user has just asked for) are fainter.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: win

  required property var service

  readonly property real renderScale: 0.5
  readonly property var hyprMonitor: Hyprland.monitorFor(screen)
  readonly property bool fullscreenHere: !!(hyprMonitor && hyprMonitor.activeWorkspace
    && hyprMonitor.activeWorkspace.hasFullscreen)

  // How far the ring travels from the source, in logical pixels, judged at the real resolution.
  readonly property real reach: Math.max(180, Math.min(340, height * 0.26))
  // Where the first toast sits: its centre is half a card from the right edge and about half a
  // short card below the top, past whatever the bar reserves and the gap the shell leaves.
  readonly property real cardHalfWidth: 190
  readonly property real cardHalfHeight: 34
  // The light's source is narrower than the card, so the ring rounds off soon instead of keeping
  // the card's long outline.
  readonly property vector2d sourceBox: Qt.vector2d(100, 30)

  // Live arrivals: { start, dur, urgency, amp, salt }, oldest first, in ms of wall time.
  property var events: []
  property real nowMs: 0

  readonly property int maxEvents: 3

  function durationFor(urgency) {
    return urgency === 0 ? 3200 : (urgency === 2 ? 6000 : 4200)
  }

  // How strong an arrival is: critical more, low less, Omarchy's own toasts and bursts fainter.
  function amplitudeFor(entry, sinceLast) {
    var base = entry.urgency === 0 ? 0.6 : (entry.urgency === 2 ? 1.3 : 1.0)
    if (entry.app === "omarchy-action") base *= 0.7
    if (sinceLast < 400) base *= 0.6
    return base
  }

  function addEvent(entry, now) {
    var last = events.length > 0 ? events[events.length - 1] : null
    var next = {
      start: now,
      dur: durationFor(entry.urgency),
      urgency: entry.urgency,
      amp: amplitudeFor(entry, last ? now - last.start : 1e9),
      salt: (events.length + Math.floor(now / 1000)) % 7 * 1.3
    }
    var kept = live(now)
    kept.push(next)
    events = kept.slice(-maxEvents)
    nowMs = now
  }

  function live(now) {
    return events.filter(function(e) { return now - e.start < e.dur })
  }

  // (progress, urgency, amplitude, salt) for the i-th arrival, or progress 0 (off) if there is none.
  function evAt(i, now) {
    var e = i < events.length ? events[i] : null
    if (!e) return Qt.vector4d(0, 1, 0, 0)
    return Qt.vector4d(Math.max(0, Math.min(1, (now - e.start) / e.dur)), e.urgency, e.amp, e.salt)
  }

  function originPoint() {
    var r = hyprMonitor && hyprMonitor.lastIpcObject ? hyprMonitor.lastIpcObject.reserved : null
    var top = r && r.length >= 4 ? r[1] : 0
    var right = r && r.length >= 4 ? r[2] : 0
    var gap = Style.gapsOut
    return Qt.vector2d(width - right - gap - cardHalfWidth, top + gap + cardHalfHeight)
  }

  function tick() {
    var now = Date.now()
    nowMs = now
    var kept = live(now)
    if (kept.length !== events.length) events = kept
  }

  visible: service.themeActive && service.notifyGlow && events.length > 0
    && !fullscreenHere && !service.screensaverActive
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}

  WlrLayershell.namespace: "annihilation-arrival"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Connections {
    target: win.service.notifications
    function onArrived(entry) {
      if (!win.service.themeActive || !win.service.notifyGlow) return
      Hyprland.refreshMonitors()
      win.addEvent(entry, Date.now())
    }
  }

  // One step a display frame while something is showing, and nothing otherwise.
  FrameAnimation {
    running: win.visible
    onTriggered: win.tick()
  }

  ShaderEffect {
    anchors.fill: parent

    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * win.renderScale)),
                               Math.max(1, Math.round(height * win.renderScale)))

    property real seed: win.service.shimmerSeed
    property real strength: win.service.notifyGlowStrength
    property real additive: win.service.layerAdditive ? 1.0 : 0.0
    property real reach: win.reach
    property size resolution: Qt.size(width, height)
    property vector2d origin: win.originPoint()
    property vector2d box: win.sourceBox
    property vector4d ev0: win.evAt(0, win.nowMs)
    property vector4d ev1: win.evAt(1, win.nowMs)
    property vector4d ev2: win.evAt(2, win.nowMs)

    fragmentShader: Qt.resolvedUrl("shaders/arrival.frag.qsb")
  }
}
