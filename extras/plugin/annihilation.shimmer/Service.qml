// Annihilation Shimmer: owns the settings, the theme gate, the per-screen
// wallpaper layers and the screensaver. Everything is dormant unless the
// active theme is annihilation, so leaving the plugin enabled across theme
// switches is safe.
//
// Settings are inline fields on this plugin's entry in shell.json `plugins[]`:
//   layerEnabled (bool, true), layerIntensity (0-1, 0.35), motes (bool, true),
//   fpsCap (5-60, 30), screensaver (bool, true),
//   screensaverSeconds (0 = follow idle.screensaver in shell.json).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""
  property var pluginRegistry: null
  property var barWidgetRegistry: null

  readonly property string pluginId: "annihilation.shimmer"
  readonly property string home: Quickshell.env("HOME")
  readonly property string dir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

  // The palette's teal and magenta come from the shell theme (Color.accent,
  // Color.bar.active); amber is not exposed there, so it lives here.
  readonly property color amber: "#db930d"

  property bool themeActive: false

  property bool layerEnabled: true
  property real layerIntensity: 0.35
  property bool motes: true
  property int fpsCap: 30
  property bool screensaverEnabled: true
  property int screensaverSecondsSetting: 0
  property int idleScreensaverSeconds: 150

  readonly property int screensaverSeconds: screensaverSecondsSetting > 0
    ? screensaverSecondsSetting : idleScreensaverSeconds

  // A transient swell on top of layerIntensity; see pulse().
  property real pulseBoost: 0
  readonly property real effectiveIntensity: Math.min(1, layerIntensity + pulseBoost)

  readonly property bool running: themeActive && layerEnabled && effectiveIntensity > 0

  // True when the screensaver was summoned over IPC rather than by idling. It
  // then grabs input so a key or click can dismiss it; idle-driven ones end
  // when the idle monitor sees any input.
  property bool screensaverForced: false
  readonly property bool screensaverActive: themeActive
    && (screensaverForced || (screensaverEnabled && idleMonitor.isIdle))

  property var journalLines: []

  // Shared clock origin, randomised so each session starts mid-drift rather
  // than with the band in the same place every login.
  readonly property real startedAt: Date.now() - Math.random() * 3600000

  function clamp(value, low, high) {
    return Math.min(high, Math.max(low, value))
  }

  function applyConfig(raw) {
    var cfg = ({})
    var entry = ({})
    function collect(item) {
      if (!item || item.id !== root.pluginId) return
      for (var key in item) entry[key] = item[key]
    }
    // The settings live on whichever entry enabled the plugin: plugins[] for
    // the bare service, or the bar layout entry once the widget is placed.
    try {
      cfg = JSON.parse(raw)
      if (Array.isArray(cfg.plugins)) cfg.plugins.forEach(collect)
      var layout = cfg.bar && cfg.bar.layout ? cfg.bar.layout : ({})
      for (var section in layout) {
        if (Array.isArray(layout[section])) layout[section].forEach(collect)
      }
    } catch (e) {}

    layerEnabled = entry.layerEnabled !== false
    motes = entry.motes !== false
    layerIntensity = typeof entry.layerIntensity === "number" ? clamp(entry.layerIntensity, 0, 1) : 0.35
    fpsCap = typeof entry.fpsCap === "number" ? Math.round(clamp(entry.fpsCap, 5, 60)) : 30
    screensaverEnabled = entry.screensaver !== false
    screensaverSecondsSetting = typeof entry.screensaverSeconds === "number"
      ? Math.max(0, Math.round(entry.screensaverSeconds)) : 0

    var idle = cfg && cfg.idle && typeof cfg.idle.screensaver === "number" ? cfg.idle.screensaver : 150
    idleScreensaverSeconds = Math.max(10, Math.round(idle))
  }

  function applyJournal(raw) {
    journalLines = String(raw || "").split("\n")
      .map(function(line) { return line.trim() })
      .filter(function(line) { return line.length > 0 && line.charAt(0) !== "#" })
  }

  function randomLine(previous) {
    var lines = journalLines
    if (lines.length === 0) return ""
    if (lines.length === 1) return lines[0]
    var pick = previous
    while (pick === previous) pick = lines[Math.floor(Math.random() * lines.length)]
    return pick
  }

  // Apply locally first so the change is instant, then persist it.
  function setSetting(key, value) {
    root[key] = value
    if (!root.shell || !root.shell.updateEntryInline) return
    var patch = ({})
    patch[key] = value
    root.shell.updateEntryInline(root.pluginId, patch)
  }

  function pulse() {
    pulseAnimation.restart()
  }

  // Same mechanism as omarchy-screensaver: newer Hyprland takes Lua, older
  // takes a keyword.
  function setCursorHidden(hidden) {
    var v = hidden ? "true" : "false"
    Quickshell.execDetached(["bash", "-c",
      "hyprctl eval 'hl.config({ cursor = { invisible = " + v + " } })' &>/dev/null"
      + " || hyprctl keyword cursor:invisible " + v + " &>/dev/null || true"])
  }

  onScreensaverActiveChanged: {
    setCursorHidden(screensaverActive)
    if (!screensaverActive) screensaverForced = false
  }

  Component.onDestruction: if (screensaverActive) setCursorHidden(false)

  FileView {
    id: themeFile
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeActive = text().trim() === "annihilation"
    onFileChanged: reload()
    onLoadFailed: root.themeActive = false
  }

  FileView {
    id: configFile
    path: root.home + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
    onLoadFailed: root.applyConfig("")
  }

  FileView {
    id: journalFile
    path: root.dir + "journal.txt"
    printErrors: false
    onLoaded: root.applyJournal(text())
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.themeActive && root.screensaverEnabled
    timeout: root.screensaverSeconds
    respectInhibitors: true
  }

  SequentialAnimation {
    id: pulseAnimation
    NumberAnimation { target: root; property: "pulseBoost"; to: 0.4; duration: 2000; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "pulseBoost"; to: 0; duration: 6000; easing.type: Easing.InOutSine }
  }

  IpcHandler {
    target: "shimmer"

    function toggleLayer(): void {
      root.setSetting("layerEnabled", !root.layerEnabled)
    }

    function pulse(): void {
      root.pulse()
    }

    function screensaver(): void {
      if (root.themeActive) root.screensaverForced = true
    }

    function dismiss(): void {
      root.screensaverForced = false
    }

    function status(): string {
      return JSON.stringify({
        themeActive: root.themeActive,
        running: root.running,
        layerEnabled: root.layerEnabled,
        layerIntensity: root.layerIntensity,
        motes: root.motes,
        fpsCap: root.fpsCap,
        screensaverEnabled: root.screensaverEnabled,
        screensaverSeconds: root.screensaverSeconds,
        screensaverActive: root.screensaverActive,
        journalLines: root.journalLines.length
      })
    }
  }

  Variants {
    model: Quickshell.screens

    ShimmerLayer {
      required property var modelData
      screen: modelData
      service: root
    }
  }

  Variants {
    model: Quickshell.screens

    Screensaver {
      required property var modelData
      screen: modelData
      service: root
    }
  }
}
