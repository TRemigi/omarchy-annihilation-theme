// Bar glyph for the Annihilation theme: a small prism whose edge slowly shifts
// teal -> magenta -> amber. Left click opens the expedition log, right click
// turns the wallpaper layer on or off, middle click starts the screensaver.
// Hidden on every other theme.
//
// Independent of Service.qml on purpose: it reads the theme itself and writes
// settings to its own entry in shell.json, which the service watches.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "annihilation.shimmer"

  // Injected by the bar for widget entry points.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""
  property var pluginRegistry: null
  property var barWidgetRegistry: null

  readonly property color amber: "#db930d"
  readonly property bool layerEnabled: setting("layerEnabled", true) !== false

  property bool themeActive: false

  // Position in the 60 s colour cycle, 0..1.
  property real phase: 0

  function mixColor(a, b, f) {
    return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1)
  }

  // teal -> magenta -> amber -> teal
  function cycleColor(t) {
    var stops = [Color.accent, Color.bar.active, Qt.color(root.amber), Color.accent]
    var x = (t - Math.floor(t)) * 3
    var i = Math.min(2, Math.floor(x))
    return mixColor(stops[i], stops[i + 1], x - i)
  }

  readonly property color glyphColor: cycleColor(phase)

  // Written like the clock does: applied locally so the UI answers the click,
  // then persisted; the service picks it up from shell.json.
  function updateSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function startScreensaver() {
    Quickshell.execDetached(["omarchy-shell", "shimmer", "screensaver"])
  }

  // ---- Popup contract for the bar's popout routing: open/close/opened on the
  //      widget root, forwarded to the panel below.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: Math.round(Style.bar.iconSlot * 0.62)
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeActive = text().trim() === "annihilation"
    onFileChanged: reload()
    onLoadFailed: root.themeActive = false
  }

  // One step a second is plenty for a 60 s cycle, and keeps the bar from
  // repainting every frame the way a running animation would.
  Timer {
    interval: 1000
    running: root.themeActive && root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.phase = ((Date.now() / 1000) % 60) / 60
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: root.themeActive
    dimmed: !root.layerEnabled
    tooltipText: "Area X"
    fixedWidth: root.vertical ? -1 : Style.bar.iconSlot + Style.space(10)
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    onPressed: function(b) {
      if (b === Qt.RightButton) root.updateSetting("layerEnabled", !root.layerEnabled)
      else if (b === Qt.MiddleButton) root.startScreensaver()
      else root.togglePanel()
    }

    Item {
      id: glyph
      anchors.centerIn: parent
      width: Math.round(Style.bar.iconSlot * 0.62)
      height: width

      Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeColor: root.glyphColor
          strokeWidth: 1.5
          fillColor: Qt.rgba(root.glyphColor.r, root.glyphColor.g, root.glyphColor.b, 0.14)
          joinStyle: ShapePath.RoundJoin
          startX: glyph.width * 0.5
          startY: glyph.height * 0.08
          PathLine { x: glyph.width * 0.94; y: glyph.height * 0.88 }
          PathLine { x: glyph.width * 0.06; y: glyph.height * 0.88 }
          PathLine { x: glyph.width * 0.5; y: glyph.height * 0.08 }
        }
      }

      // A spore caught in the prism.
      Rectangle {
        width: 3
        height: 3
        radius: 1.5
        x: glyph.width * 0.62
        y: glyph.height * 0.52
        color: root.amber
        opacity: 0.8
      }
    }
  }
}
