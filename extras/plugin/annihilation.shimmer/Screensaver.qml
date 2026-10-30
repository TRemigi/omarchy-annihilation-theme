// The Shimmer screensaver: one fullscreen overlay per screen showing the
// wallpaper slowly taken by the bloom shader, with a passage that kindles one
// part at a time as living light. Which part, and when, is the service's call
// (so every screen agrees); this file only draws it. Idle-driven instances are
// ended by the idle monitor on any input; summoned ones take input and end
// themselves (see Service.screensaverForced).

import QtQuick
import QtQuick.Effects
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
    if (!visible) return
    startedAt = Date.now()
    elapsed = 0
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

  // The passage, as living light: a dark halo for legibility, two blooms of
  // teal that breathe slowly, and a pale core that now and then gutters.
  Item {
    id: passage
    anchors.fill: parent
    opacity: win.service.passageOpacity

    property real breath: 0.85
    property real flicker: 1

    Behavior on flicker { NumberAnimation { duration: 140 } }

    SequentialAnimation on breath {
      running: win.visible
      loops: Animation.Infinite
      NumberAnimation { to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.7; duration: 3800; easing.type: Easing.InOutSine }
    }

    Timer {
      interval: 110
      running: win.visible && passage.opacity > 0.05
      repeat: true
      onTriggered: passage.flicker = Math.random() < 0.025 ? 0.5 : 0.88 + Math.random() * 0.12
    }

    Repeater {
      model: [
        { kind: "shadow", blur: 40, tint: "#131109", alpha: 0.7 },
        { kind: "halo", blur: 64, tint: Color.accent, alpha: 0.9 },
        { kind: "halo", blur: 32, tint: Qt.lighter(Color.accent, 1.25), alpha: 0.9 },
        { kind: "halo", blur: 14, tint: Qt.lighter(Color.accent, 1.5), alpha: 1.0 },
        { kind: "core", blur: 0, tint: Qt.lighter(Color.accent, 1.8), alpha: 0.95 }
      ]

      Text {
        id: layerText
        required property var modelData

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: passage.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: win.service.passageText
        color: modelData.tint
        font.family: win.passageStyle.family
        font.variableAxes: win.passageStyle.axes
        font.capitalization: win.passageStyle.caps ? Font.AllUppercase : Font.MixedCase
        font.pixelSize: win.passageSize
        font.letterSpacing: win.passageSize * win.passageStyle.tracking
        lineHeight: 1.15
        // Letter-spacing trails the last glyph of a line; pad the other side
        // so the text sits dead centre.
        leftPadding: font.letterSpacing

        opacity: modelData.alpha * (modelData.kind === "halo" ? passage.breath
          : modelData.kind === "core" ? passage.flicker : 1)

        layer.enabled: modelData.blur > 0
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1.0
          blurMax: layerText.modelData.blur
        }
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
