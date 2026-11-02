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
//
// The words are alive (shaders/alive.frag): every stroke is packed with tiny
// hand-shaped creatures, which wave their fingers and glow in slow swells; once
// per part a few spores are released from one point. Under that, the same blurred glow layers as before. The text is
// drawn once, white, into a texture padded enough for the spores to rise into, and
// the shader does the rest. With `alive` off, or `glow` off, the core is plain text.

import QtQuick
import QtQuick.Effects

Item {
  id: root

  property var parts: []
  property real time: 0

  // Seconds. A part holds for holdBase plus holdPerChar for each character.
  property real fadeSeconds: 2.5
  property real pauseSeconds: 1.5
  property real holdBase: 3
  property real holdPerChar: 0.045
  // Widest a line may be, as a fraction of this item's width.
  property real maxWidthFraction: 0.78

  property string fontFamily: ""
  property var fontAxes: ({})
  property bool capitals: false
  property real pixelSize: 24
  // The size of a creature, in pixels: a hand is about this across. Independent of the
  // type size, so the words can grow without the hands growing with them.
  property real cellSize: pixelSize * 0.2
  property real letterSpacing: 0

  property color shadowColor: "#131109"
  property color wideColor: "#61A0A8"
  property color midColor: "#7bb5bc"
  property color nearColor: "#97c9ce"
  property color coreColor: "#c5e4e7"

  property bool running: false
  property bool glow: true   // false lets a test render the plain text
  property bool alive: true  // the creatures and spores; false draws the plain core
  property color sporeColor: "#e2c981"

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
  // The creatures take the place of the plain core layer.
  readonly property bool creatures: glow && alive
  // The creatures make their own glow (alive.frag), which follows how bright they are; blurred
  // copies of the text cannot, so only the dark shadow behind the words is kept.
  readonly property var shadowLayers: glowLayers.filter(function(l) { return l.kind === "shadow" })

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

  // The spores leave a little after the part has come up, while it is read.
  function releaseAt(line) {
    return fadeSeconds + 0.3 * holdFor(line)
  }

  // Which part is showing at t, and how strongly (0 to 1). Opacity is linear
  // light and bright text on near-black looks far stronger than its number, so
  // a smoothstep ramp is squared to keep pace with the dim photo behind it.
  function locate(t) {
    var s = schedule
    if (parts.length === 0 || s.total <= 0) return { index: 0, strength: 0, local: 0, cycle: 0 }
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
    return { index: i, strength: a * a, local: local, cycle: Math.floor(Math.max(0, t) / s.total) }
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

  // Seconds since the spores left (negative before), and a number that makes each
  // part, and each pass through the passage, release them somewhere else.
  readonly property real sporeAge: moment.local - releaseAt(currentLine)
  readonly property real sporeSeed: moment.index + 1 + 37 * moment.cycle

  // Room round the text for the spores to rise into (they climb about 17 cells).
  readonly property real pad: cellSize * 22

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
    model: root.creatures ? root.shadowLayers : (root.glow ? root.glowLayers : root.plainLayers)

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

  // The words laid out exactly as the layers above (the same wrap width, and the
  // letter-spacing put back on the left), in white, inside padding that is the room for
  // the spores to rise into and the glow to spread into.
  component WordsText: PartText {
    width: passage.textWidth + 2 * passage.pad
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
    leftPadding: passage.pad + font.letterSpacing
    rightPadding: passage.pad
    topPadding: passage.pad
    bottomPadding: passage.pad
    color: "white"
  }

  // The words, drawn once; alive.frag reads where the strokes are. hideSource, not
  // visible: false: an invisible item is not drawn into a texture.
  WordsText { id: aliveText; passage: root }

  ShaderEffectSource {
    id: aliveSource
    sourceItem: aliveText
    hideSource: true
    live: root.creatures
  }

  // A blurred copy, which the shader lights by the same swell that lights the creatures, so
  // the glow dims where they dim. Blurred copies drawn on their own cannot do that, and a
  // word whose hands had dimmed inside an unchanged glow looked blurred.
  Item {
    id: glowItem
    width: aliveText.width
    height: aliveText.height

    WordsText {
      passage: root
      layer.enabled: true
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 64
      }
    }
  }

  ShaderEffectSource {
    id: glowSource
    sourceItem: glowItem
    hideSource: true
    live: root.creatures
  }

  ShaderEffect {
    visible: root.creatures
    anchors.centerIn: parent
    width: aliveText.width
    height: aliveText.height

    property variant source: aliveSource
    property variant glowTex: glowSource
    property real time: root.time
    property size dims: Qt.size(width, height)
    property real unit: root.cellSize * 5
    property real seed: root.sporeSeed
    property real sporeAge: root.sporeAge
    property real cell: root.cellSize
    property vector4d bounds: Qt.vector4d(root.pad, root.pad, width - root.pad, height - root.pad)
    property color tint: root.nearColor
    property color coreTint: root.coreColor
    property color sporeTint: root.sporeColor

    fragmentShader: Qt.resolvedUrl("shaders/alive.frag.qsb")
  }
}
