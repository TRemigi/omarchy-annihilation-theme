// The expedition log popup: how long you have been inside Area X (uptime in
// days), today's journal entry, and the Shimmer's controls. BarWidget.qml owns
// the glyph, hands this panel the button to anchor against, and persists the
// settings this panel asks it to change.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "annihilation.shimmer"
  ipcTarget: "annihilation.shimmer"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot, not this nested panel, so
  // everything it identifies a panel by has to be that widget.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property real uptimeSeconds: 0
  property var lines: []
  property int dayOfYear: 0

  readonly property int day: Math.floor(uptimeSeconds / 86400) + 1
  readonly property string entry: lines.length > 0 ? lines[dayOfYear % lines.length] : ""
  readonly property real intensity: Number(setting("layerIntensity", 0.35))
  readonly property real speed: Number(setting("layerSpeed", 1.0))
  readonly property bool layerEnabled: setting("layerEnabled", true) !== false
  readonly property bool motes: setting("motes", true) !== false
  readonly property bool glowFollows: setting("windowGlowMode", "all") === "cursor"
  readonly property real span: Number(setting("windowGlowSpan", 1.0))
  readonly property real depth: Number(setting("windowGlowDepth", 1.0))
  readonly property real center: Number(setting("windowGlowCenter", 1.0))
  readonly property real notifyStrength: Number(setting("notifyGlowStrength", 1.0))
  readonly property bool notifyGlow: setting("notifyGlow", true) !== false
  readonly property real soundVolume: Number(setting("notifySoundVolume", 0.5))
  readonly property bool notifySound: setting("notifySound", false) === true

  function sliderValue(key) {
    switch (key) {
    case "layerSpeed": return speed
    case "windowGlowSpan": return span
    case "windowGlowDepth": return depth
    case "windowGlowCenter": return center
    case "notifyGlowStrength": return notifyStrength
    case "notifySoundVolume": return soundVolume
    default: return intensity
    }
  }

  function change(key, value) {
    if (root.hostWidget && typeof root.hostWidget.updateSetting === "function")
      root.hostWidget.updateSetting(key, value)
  }

  function refreshDay() {
    var now = new Date()
    dayOfYear = Math.floor((now - new Date(now.getFullYear(), 0, 0)) / 86400000)
  }

  onOpenedChanged: if (opened) refreshDay()

  FileView {
    path: Qt.resolvedUrl("journal.txt").toString().replace(/^file:\/\//, "")
    printErrors: false
    onLoaded: root.lines = String(text()).split("\n")
      .map(function(line) { return line.trim() })
      .filter(function(line) { return line.length > 0 && line.charAt(0) !== "#" })
  }

  Process {
    id: uptimeProcess
    command: ["cat", "/proc/uptime"]
    stdout: StdioCollector {
      onStreamFinished: root.uptimeSeconds = parseFloat(String(text).split(" ")[0]) || 0
    }
  }

  Timer {
    interval: 60000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!uptimeProcess.running) uptimeProcess.running = true
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Day " + root.day
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.display
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "inside Area X"
            color: Qt.darker(Color.foreground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator { width: parent.width }

        PanelSectionHeader { text: "TODAY'S ENTRY" }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.entry
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.italic: true
        }

        PanelSeparator { width: parent.width }

        PanelSectionHeader { text: "THE SHIMMER" }

        // The longest slider label, so that the common column fits it.
        TextMetrics {
          id: labelMetrics
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          text: "Glow brightness"
        }

        // The sliders, with their labels in a common column, so they line up.
        Repeater {
          model: [
            { label: "Intensity", key: "layerIntensity", min: 0, max: 1, step: 0.05 },
            { label: "Speed", key: "layerSpeed", min: 0.25, max: 3, step: 0.05 },
            { label: "Glow span", key: "windowGlowSpan", min: 0.5, max: 2.5, step: 0.05 },
            { label: "Glow depth", key: "windowGlowDepth", min: 0.05, max: 2.5, step: 0.05 },
            { label: "Glow brightness", key: "windowGlowCenter", min: 0, max: 2.5, step: 0.05 },
            { label: "Arrival glow", key: "notifyGlowStrength", min: 0.1, max: 2, step: 0.05 },
            { label: "Sound volume", key: "notifySoundVolume", min: 0.05, max: 1, step: 0.05 }
          ]

          Row {
            id: sliderRow
            required property var modelData
            width: content.width
            spacing: Style.space(10)
            // The span and the centre only do anything while the glow follows the cursor.
            opacity: ((sliderRow.modelData.key === "windowGlowSpan" || sliderRow.modelData.key === "windowGlowCenter")
              && !root.glowFollows) || (sliderRow.modelData.key === "notifyGlowStrength" && !root.notifyGlow)
              || (sliderRow.modelData.key === "notifySoundVolume" && !root.notifySound) ? 0.45 : 1

            Text {
              id: sliderLabel
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(Style.space(84), Math.ceil(labelMetrics.advanceWidth))
              text: sliderRow.modelData.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            PanelSlider {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - sliderLabel.width - parent.spacing
              bar: root.bar
              minimum: sliderRow.modelData.min
              maximum: sliderRow.modelData.max
              step: sliderRow.modelData.step
              value: root.sliderValue(sliderRow.modelData.key)
              onReleased: function(v) { root.change(sliderRow.modelData.key, Math.round(v * 100) / 100) }
            }
          }
        }

        Repeater {
          model: [
            { label: "Wallpaper layer", key: "layerEnabled" },
            { label: "Spores", key: "motes" },
            { label: "Glow follows cursor", key: "windowGlowMode" },
            { label: "Glow on notifications", key: "notifyGlow" },
            { label: "Sound on notifications", key: "notifySound" }
          ]

          Item {
            id: row
            required property var modelData
            width: content.width
            height: Math.max(toggle.height, label.implicitHeight)

            Text {
              id: label
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            ToggleSwitch {
              id: toggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: row.modelData.key === "layerEnabled" ? root.layerEnabled
                : row.modelData.key === "windowGlowMode" ? root.glowFollows
                : row.modelData.key === "notifyGlow" ? root.notifyGlow
                : row.modelData.key === "notifySound" ? root.notifySound : root.motes
              // windowGlowMode is a word, not a switch: "cursor" (active window, pooled at the
              // pointer) or "all" (every window, evenly).
              onToggled: root.change(row.modelData.key,
                row.modelData.key === "windowGlowMode" ? (checked ? "all" : "cursor") : !checked)
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: beginArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent"
          border.width: 1
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.25)

          Text {
            anchors.centerIn: parent
            text: "Begin screensaver"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: beginArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              Quickshell.execDetached(["omarchy-shell", "shimmer", "screensaver"])
            }
          }
        }
      }
    }
  }
}
