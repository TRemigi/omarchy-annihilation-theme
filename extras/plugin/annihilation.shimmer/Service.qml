// Annihilation Shimmer: owns the settings, the theme gate and the per-screen
// wallpaper layers. Everything is dormant unless the active theme is
// annihilation, so leaving the plugin enabled across theme switches is safe.
//
// Settings are inline fields on this plugin's entry in shell.json `plugins[]`:
//   layerEnabled (bool, true), layerIntensity (0-1, 0.35), motes (bool, true),
//   fpsCap (5-60, 30).

import QtQuick
import Quickshell
import Quickshell.Io

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

  // The palette's teal and magenta come from the shell theme (Color.accent,
  // Color.bar.active); amber is not exposed there, so it lives here.
  readonly property color amber: "#db930d"

  property bool themeActive: false

  property bool layerEnabled: true
  property real layerIntensity: 0.35
  property bool motes: true
  property int fpsCap: 30

  // A transient swell on top of layerIntensity; see pulse().
  property real pulseBoost: 0
  readonly property real effectiveIntensity: Math.min(1, layerIntensity + pulseBoost)

  readonly property bool running: themeActive && layerEnabled && effectiveIntensity > 0

  // Shared clock origin, randomised so each session starts mid-drift rather
  // than with the band in the same place every login.
  readonly property real startedAt: Date.now() - Math.random() * 3600000

  function clamp(value, low, high) {
    return Math.min(high, Math.max(low, value))
  }

  function applyConfig(raw) {
    var entry = ({})
    try {
      var list = JSON.parse(raw).plugins
      if (Array.isArray(list)) {
        for (var i = 0; i < list.length; i++) {
          if (list[i] && list[i].id === root.pluginId) entry = list[i]
        }
      }
    } catch (e) {}

    layerEnabled = entry.layerEnabled !== false
    motes = entry.motes !== false
    layerIntensity = typeof entry.layerIntensity === "number" ? clamp(entry.layerIntensity, 0, 1) : 0.35
    fpsCap = typeof entry.fpsCap === "number" ? Math.round(clamp(entry.fpsCap, 5, 60)) : 30
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

    function status(): string {
      return JSON.stringify({
        themeActive: root.themeActive,
        running: root.running,
        layerEnabled: root.layerEnabled,
        layerIntensity: root.layerIntensity,
        motes: root.motes,
        fpsCap: root.fpsCap
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
}
