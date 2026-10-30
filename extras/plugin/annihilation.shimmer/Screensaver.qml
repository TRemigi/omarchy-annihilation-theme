// The Shimmer screensaver: one fullscreen overlay per screen showing the
// wallpaper slowly taken by the bloom shader, with a passage crawling across it
// as living light (see Crawl.qml). Every screen starts from the same saved
// position, so they agree. Idle-driven instances are ended by the idle monitor
// on any input; summoned ones take input and end themselves (see
// Service.screensaverForced).

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: win

  required property var service

  // The shader is soft, but this is a photograph: keep most of its detail.
  readonly property real renderScale: 0.75
  readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  readonly property var passageStyle: win.service.passageStyle
  readonly property real passageSize: Math.max(22, Math.round(win.height * passageStyle.scale))

  property real startedAt: 0
  property real elapsed: 0

  function dismiss() {
    service.screensaverForced = false
  }

  visible: service.screensaverActive
  anchors { top: true; bottom: true; left: true; right: true }
  color: "black"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "annihilation-screensaver"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: service.screensaverForced ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onVisibleChanged: {
    if (visible) {
      startedAt = Date.now()
      elapsed = 0
      crawl.opacity = 0
      crawlIn.restart()
    } else {
      crawlIn.stop()
      // Next time, carry on from the first part that was still on screen.
      service.passageIndex = crawl.resumeIndex()
    }
  }

  Timer {
    interval: 33
    running: win.visible
    repeat: true
    onTriggered: win.elapsed = (Date.now() - win.startedAt) / 1000
  }

  Image {
    id: wallpaper
    anchors.fill: parent
    visible: false
    source: win.visible ? "file://" + win.wallpaperPath : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    sourceSize.width: Math.min(3840, win.width)
  }

  ShaderEffect {
    anchors.fill: parent

    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * win.renderScale)),
                               Math.max(1, Math.round(height * win.renderScale)))

    property variant source: wallpaper
    property real time: win.elapsed
    property size resolution: Qt.size(width, height)
    // The shader crops the image to cover the screen itself: a sampled Image
    // hands it the whole texture whatever its fillMode says.
    property real imageAspect: wallpaper.implicitHeight > 0
      ? wallpaper.implicitWidth / wallpaper.implicitHeight : width / Math.max(1, height)
    property real brightness: win.service.screensaverBrightness
    property color tealColor: Color.accent

    fragmentShader: Qt.resolvedUrl("shaders/bloom.frag.qsb")
  }

  // The passage, as living light: a dark halo for legibility, three blooms of
  // teal that breathe slowly, and a pale core that now and then gutters. The
  // band is tall enough for the widest bloom not to be clipped.
  Crawl {
    id: crawl
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: Math.max(win.passageSize * 5, win.passageSize * 1.5 + 160)
    opacity: 0

    parts: win.service.passageParts
    startIndex: win.service.passageIndex
    running: win.visible
    speed: win.service.crawlSpeed * win.passageSize
    gap: win.passageSize * 7

    fontFamily: win.passageStyle.family
    fontAxes: win.passageStyle.axes
    capitals: win.passageStyle.caps
    pixelSize: win.passageSize
    letterSpacing: win.passageSize * win.passageStyle.tracking

    wideColor: Color.accent
    midColor: Qt.lighter(Color.accent, 1.25)
    nearColor: Qt.lighter(Color.accent, 1.5)
    coreColor: Qt.lighter(Color.accent, 1.8)
  }

  // Let the wallpaper settle before the first words drift in.
  SequentialAnimation {
    id: crawlIn
    PauseAnimation { duration: 2000 }
    NumberAnimation { target: crawl; property: "opacity"; from: 0; to: 1; duration: 3000; easing.type: Easing.InOutSine }
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: win.dismiss()

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: win.dismiss()
      onPositionChanged: if (win.elapsed > 1.0) win.dismiss()
    }
  }
}
