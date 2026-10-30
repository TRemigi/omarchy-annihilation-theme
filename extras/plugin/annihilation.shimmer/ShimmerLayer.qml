// One click-through window per screen, between the wallpaper and the windows,
// painting the Shimmer shader. Hidden while a fullscreen window covers this
// screen, so a game or video costs nothing. The shader's clock is the service's.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
  id: win

  required property var service

  // The shader is all soft gradients, so it renders at a fraction of the
  // screen size and is scaled up: a quarter of the pixels at 0.5.
  readonly property real renderScale: 0.5

  readonly property var hyprMonitor: Hyprland.monitorFor(screen)
  readonly property bool fullscreenHere: !!(hyprMonitor && hyprMonitor.activeWorkspace
    && hyprMonitor.activeWorkspace.hasFullscreen)

  visible: service.running && !fullscreenHere && !service.screensaverActive
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}

  WlrLayershell.namespace: "annihilation-shimmer"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  ShaderEffect {
    anchors.fill: parent

    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * win.renderScale)),
                               Math.max(1, Math.round(height * win.renderScale)))

    property real time: win.service.shimmerClock
    property real intensity: win.service.effectiveIntensity
    property real motes: win.service.motes ? 1.0 : 0.0
    property size resolution: Qt.size(width, height)
    property real seed: win.service.shimmerSeed
    property real additive: win.service.layerAdditive ? 1.0 : 0.0

    fragmentShader: Qt.resolvedUrl("shaders/shimmer.frag.qsb")
  }
}
