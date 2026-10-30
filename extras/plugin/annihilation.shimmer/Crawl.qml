// One continuous line of text scrolling right to left. Parts of a passage
// appear near the right of the screen, one after another with a gap between
// them, and disappear near the left. Both ends fade inside the screen (see
// fadeInset), so text never looks as if it comes from, or goes to, off-screen.
//
// Each part is its own item rather than one long strip: a strip holding a whole
// passage would be far wider than a GPU texture can be once the glow is blurred.
// The glow textures are made once per part and only moved afterwards, so the
// crawl costs one cheap composite per frame.
//
// Positions come from one number, ribbonX. Parts are laid out in a Row inside
// it; when the first part has left, it is removed and ribbonX is advanced by its
// width plus the gap so nothing visibly moves.

import QtQuick
import QtQuick.Effects

Item {
  id: root

  property var parts: []
  property int startIndex: 0
  property real speed: 100       // pixels per second
  property real gap: 200         // pixels between parts
  // Fade zones, as fractions of the width. Fully transparent for the outer
  // fadeInset at each end, then a ramp fadeWidth wide up to full strength.
  property real fadeInset: 0.08
  property real fadeWidth: 0.20

  property string fontFamily: ""
  property var fontAxes: ({})
  property bool capitals: false
  property real pixelSize: 24
  property real letterSpacing: 0

  property color shadowColor: "#131109"
  property color wideColor: "#61A0A8"
  property color midColor: "#7bb5bc"
  property color nearColor: "#97c9ce"
  property color coreColor: "#c5e4e7"

  property bool running: false
  property bool autoDrive: true  // false lets a test call advance() itself
  property bool glow: true
  property bool fade: true

  // Slow swell of the halos and an occasional gutter of the core.
  property real breath: 0.85
  property real flicker: 1

  property real ribbonX: 0
  property int nextIndex: 0

  // False until the first frame with a real width. A layer-shell window is
  // often still zero-wide the instant it becomes visible, so the start position
  // cannot be worked out then.
  property bool primed: false

  readonly property int count: partModel.count

  readonly property var glowLayers: [
    { kind: "shadow", blur: 40, tint: shadowColor, alpha: 0.7 },
    { kind: "halo", blur: 64, tint: wideColor, alpha: 0.9 },
    { kind: "halo", blur: 32, tint: midColor, alpha: 0.9 },
    { kind: "halo", blur: 14, tint: nearColor, alpha: 1.0 },
    { kind: "core", blur: 0, tint: coreColor, alpha: 0.95 }
  ]
  readonly property var plainLayers: [{ kind: "core", blur: 0, tint: coreColor, alpha: 0.95 }]

  function wrap(index) {
    var n = parts.length
    return n > 0 ? ((index % n) + n) % n : 0
  }

  function restart() {
    partModel.clear()
    primed = false
    nextIndex = wrap(startIndex)
  }

  // Index of the first part still on screen, so the next run can pick up there.
  function resumeIndex() {
    return wrap(nextIndex - partModel.count)
  }

  function advance(dt) {
    if (parts.length === 0) return

    // The first words begin where they are already starting to fade in, so
    // they are never spent unseen.
    if (!primed) {
      if (width <= 0) return
      ribbonX = width * (1.0 - fadeInset)
      primed = true
    }

    ribbonX -= speed * dt

    var first = partRepeater.itemAt(0)
    if (first && first.width > 0 && ribbonX + first.width < 0) {
      ribbonX += first.width + gap
      partModel.remove(0)
    }

    // Keep the ribbon reaching past the right edge. One part per frame is
    // plenty, and the Row only knows a new part's width on the next frame.
    if (partModel.count === 0 || ribbonX + ribbon.implicitWidth < width + gap) {
      partModel.append({ line: parts[nextIndex] })
      nextIndex = wrap(nextIndex + 1)
    }
  }

  onRunningChanged: if (running) restart()

  FrameAnimation {
    running: root.running && root.autoDrive && root.parts.length > 0
    onTriggered: root.advance(Math.min(frameTime, 0.1))
  }

  SequentialAnimation on breath {
    running: root.running && root.glow
    loops: Animation.Infinite
    NumberAnimation { to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0.7; duration: 3800; easing.type: Easing.InOutSine }
  }

  Behavior on flicker { NumberAnimation { duration: 140 } }

  Timer {
    interval: 110
    running: root.running && root.glow
    repeat: true
    onTriggered: root.flicker = Math.random() < 0.025 ? 0.5 : 0.88 + Math.random() * 0.12
  }

  component PartText: Text {
    required property var crawl
    required property string line

    text: line
    textFormat: Text.PlainText
    wrapMode: Text.NoWrap
    font.family: crawl.fontFamily
    font.variableAxes: crawl.fontAxes
    font.capitalization: crawl.capitals ? Font.AllUppercase : Font.MixedCase
    font.pixelSize: crawl.pixelSize
    font.letterSpacing: crawl.letterSpacing
  }

  // Alpha mask: transparent at both ends, a ramp inside each, opaque between.
  Item {
    id: fadeMask
    anchors.fill: parent
    visible: false
    layer.enabled: root.fade

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#00ffffff" }
        GradientStop { position: root.fadeInset; color: "#00ffffff" }
        GradientStop { position: root.fadeInset + root.fadeWidth; color: "#ffffffff" }
        GradientStop { position: 1.0 - root.fadeInset - root.fadeWidth; color: "#ffffffff" }
        GradientStop { position: 1.0 - root.fadeInset; color: "#00ffffff" }
        GradientStop { position: 1.0; color: "#00ffffff" }
      }
    }
  }

  Item {
    id: strip
    anchors.fill: parent

    layer.enabled: root.fade
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: fadeMask
    }

    Row {
      id: ribbon
      objectName: "crawlRibbon"
      x: root.ribbonX
      height: strip.height
      spacing: root.gap

      Repeater {
        id: partRepeater
        model: ListModel { id: partModel }

        Item {
          id: part
          objectName: "crawlPart"
          required property string line

          width: measure.implicitWidth
          height: ribbon.height

          // Sizes the part; the layers below draw it.
          PartText { id: measure; crawl: root; line: part.line; visible: false }

          Repeater {
            model: root.glow ? root.glowLayers : root.plainLayers

            PartText {
              id: layerText
              required property var modelData

              crawl: root
              line: part.line
              anchors.verticalCenter: parent.verticalCenter
              color: modelData.tint
              opacity: modelData.alpha * (modelData.kind === "halo" ? root.breath
                : modelData.kind === "core" ? root.flicker : 1)

              layer.enabled: modelData.blur > 0
              layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: layerText.modelData.blur
              }
            }
          }
        }
      }
    }
  }
}
