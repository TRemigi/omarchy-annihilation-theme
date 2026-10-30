// The Shimmer screensaver: one fullscreen overlay per screen showing the
// wallpaper slowly taken by the bloom shader, with a journal line that fades
// in and out and now and then mis-spells itself. Idle-driven instances are
// ended by the idle monitor on any input; summoned ones take input and end
// themselves (see Service.screensaverForced).

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

  property real startedAt: 0
  property real elapsed: 0
  property string line: ""
  property string display: ""
  property int glitchLeft: 0

  function dismiss() {
    service.screensaverForced = false
  }

  function nextLine() {
    line = service.randomLine(line)
    display = line
    glitchLeft = 0
  }

  // Swap two neighbouring letters, as if the line had briefly forgotten itself.
  function glitched(text) {
    if (text.length < 4) return text
    var i = 1 + Math.floor(Math.random() * (text.length - 2))
    if (text.charAt(i) === " " || text.charAt(i + 1) === " ") return text
    return text.slice(0, i) + text.charAt(i + 1) + text.charAt(i) + text.slice(i + 2)
  }

  visible: service.screensaverActive
  anchors { top: true; bottom: true; left: true; right: true }
  color: "black"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "annihilation-screensaver"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: service.screensaverForced ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onVisibleChanged: {
    if (!visible) return
    startedAt = Date.now()
    elapsed = 0
    line = ""
    display = ""
    journalText.opacity = 0
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
    property color tealColor: Color.accent

    fragmentShader: Qt.resolvedUrl("shaders/bloom.frag.qsb")
  }

  Text {
    id: journalText
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.62
    width: parent.width * 0.7
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: win.display
    color: Color.foreground
    opacity: 0
    font.family: Style.fontFamily
    font.pixelSize: Math.max(16, Math.round(win.height * 0.024))
    font.letterSpacing: 1.5
    style: Text.Outline
    styleColor: "#99131109"
  }

  // First line after a pause, then one every ~40 s: fade in, hold, fade out.
  SequentialAnimation {
    running: win.visible
    loops: Animation.Infinite
    PauseAnimation { duration: 6000 }
    ScriptAction { script: win.nextLine() }
    NumberAnimation { target: journalText; property: "opacity"; to: 0.85; duration: 3500; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 28000 }
    NumberAnimation { target: journalText; property: "opacity"; to: 0; duration: 3500; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 4000 }
  }

  Timer {
    interval: 130
    running: win.visible && journalText.opacity > 0.3
    repeat: true
    onTriggered: {
      if (win.glitchLeft > 0) {
        win.glitchLeft--
        if (win.glitchLeft === 0) win.display = win.line
      } else if (Math.random() < 0.04) {
        win.display = win.glitched(win.line)
        win.glitchLeft = 2
      }
    }
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
