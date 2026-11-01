// The passage, one part at a time, in the middle of the screen. Each part fades
// up out of the dark, holds long enough to read, fades out, and after a pause
// the next one comes. When the last part has gone the first returns.
//
// What is showing is a pure function of `time` (seconds since the screensaver
// began), so every screen agrees and a run always starts at the first part.
// The text only changes while the strength is zero (the pause ends each part),
// so the blurred glow layers are never re-rendered where anyone could see it.
//
// A part too long for one line is wrapped inside maxWidth and its width is
// narrowed to balance the lines, rather than leaving a short last one.

import QtQuick
import QtQuick.Effects

Item {
  id: root

  property var parts: []
  property real time: 0

  // Seconds. A part holds for holdBase plus holdPerChar for each character.
  property real fadeSeconds: 4
  property real pauseSeconds: 1.5
  property real holdBase: 3
  property real holdPerChar: 0.045
  // Widest a line may be, as a fraction of this item's width.
  property real maxWidthFraction: 0.78

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
  property bool glow: true   // false lets a test render the plain text

  // Slow swell of the halos and an occasional gutter of the core.
  property real breath: 0.85
  property real flicker: 1

  // Back to front. The glow of thin letters is faint once blurred, so the
  // bloom is built up from several layers of staggered radius (blurMax, in
  // pixels). The wide and mid ones are drawn with a 1 px outline for roughly
  // twice the light from the same letters: a heavier font weight would do it
  // too, but it changes the letter widths and the halo would drift off the text.
  // The near bloom and core are left plain so the letterforms stay thin.
  readonly property var glowLayers: [
    { kind: "shadow", blur: 40, tint: shadowColor, alpha: 0.7, outline: false },
    { kind: "halo", blur: 64, tint: wideColor, alpha: 1.0, outline: true },
    { kind: "halo", blur: 52, tint: wideColor, alpha: 1.0, outline: true },
    { kind: "halo", blur: 40, tint: wideColor, alpha: 1.0, outline: true },
    { kind: "halo", blur: 32, tint: midColor, alpha: 1.0, outline: true },
    { kind: "halo", blur: 24, tint: midColor, alpha: 1.0, outline: true },
    { kind: "halo", blur: 14, tint: nearColor, alpha: 1.0, outline: false },
    { kind: "core", blur: 0, tint: coreColor, alpha: 0.95, outline: false }
  ]
  readonly property var plainLayers: [{ kind: "core", blur: 0, tint: coreColor, alpha: 0.95 }]

  function holdFor(line) {
    return holdBase + String(line).length * holdPerChar
  }

  function spanFor(line) {
    return 2 * fadeSeconds + holdFor(line) + pauseSeconds
  }

  // Where each part begins in one pass through the passage, and the length of the pass.
  function buildSchedule(list) {
    var starts = []
    var t = 0
    for (var i = 0; i < list.length; i++) {
      starts.push(t)
      t += spanFor(list[i])
    }
    return { starts: starts, total: t }
  }

  // Which part is showing at t, and how strongly (0 to 1). Opacity is linear
  // light and bright text on near-black looks far stronger than its number, so
  // a smoothstep ramp is squared to keep pace with the dim photo behind it.
  function locate(t) {
    var s = schedule
    if (parts.length === 0 || s.total <= 0) return { index: 0, strength: 0 }
    var u = Math.max(0, t) % s.total
    var i = 0
    while (i + 1 < s.starts.length && s.starts[i + 1] <= u) i++
    var local = u - s.starts[i]
    var hold = holdFor(parts[i])
    var a = 0
    if (local < fadeSeconds) a = local / fadeSeconds
    else if (local < fadeSeconds + hold) a = 1
    else if (local < 2 * fadeSeconds + hold) a = 1 - (local - fadeSeconds - hold) / fadeSeconds
    a = a * a * (3 - 2 * a)
    return { index: i, strength: a * a }
  }

  readonly property var schedule: buildSchedule(parts)
  readonly property var moment: locate(time)
  readonly property string currentLine: parts.length > 0 ? String(parts[moment.index]) : ""

  // One line's width if nothing wrapped, then the width that balances the
  // lines it has to be broken into.
  readonly property real maxWidth: width * maxWidthFraction
  readonly property int lineCount: maxWidth > 0 ? Math.max(1, Math.ceil(measure.implicitWidth / maxWidth)) : 1
  readonly property real textWidth: lineCount <= 1 ? maxWidth
    : Math.min(maxWidth, measure.implicitWidth / lineCount * 1.12 + pixelSize * 3)

  visible: moment.strength > 0.001
  opacity: moment.strength

  SequentialAnimation on breath {
    running: root.running && root.glow
    loops: Animation.Infinite
    NumberAnimation { to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0.85; duration: 3800; easing.type: Easing.InOutSine }
  }

  Behavior on flicker { NumberAnimation { duration: 140 } }

  Timer {
    interval: 110
    running: root.running && root.glow
    repeat: true
    onTriggered: root.flicker = Math.random() < 0.025 ? 0.5 : 0.88 + Math.random() * 0.12
  }

  component PartText: Text {
    required property var passage

    text: passage.currentLine
    textFormat: Text.PlainText
    font.family: passage.fontFamily
    font.variableAxes: passage.fontAxes
    font.capitalization: passage.capitals ? Font.AllUppercase : Font.MixedCase
    font.pixelSize: passage.pixelSize
    font.letterSpacing: passage.letterSpacing
  }

  // Sizes the lines; the layers below draw them.
  PartText { id: measure; passage: root; visible: false; wrapMode: Text.NoWrap }

  Repeater {
    model: root.glow ? root.glowLayers : root.plainLayers

    PartText {
      id: layerText
      objectName: "passageLayer"
      required property var modelData

      passage: root
      anchors.centerIn: parent
      width: root.textWidth
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      // Letter-spacing trails the last glyph of each line; this puts it back.
      leftPadding: font.letterSpacing
      color: modelData.tint
      style: modelData.outline === true ? Text.Outline : Text.Normal
      styleColor: modelData.tint
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
