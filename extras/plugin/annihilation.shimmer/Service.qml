// Annihilation Shimmer: owns the settings, the theme gate, the per-screen
// wallpaper layers and the screensaver. Everything is dormant unless the
// active theme is annihilation, so leaving the plugin enabled across theme
// switches is safe.
//
// Settings are inline fields on this plugin's entry in shell.json `plugins[]`:
//   layerEnabled (bool, true), layerIntensity (0-1, 0.35), motes (bool, true),
//   fpsCap (5-60, 30), screensaver (bool, true),
//   screensaverSeconds (0 = follow idle.screensaver in shell.json),
//   screensaverBrightness (0.02-1, 0.16: how much of the photo shows),
//   passageFont ("jost", "cinzel", or any installed family name).

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
  property string passageFont: "jost"
  property real screensaverBrightness: 0.16

  // Typography for the passage. The bundled fonts load from fonts/ (SIL OFL,
  // licences alongside); any other value is the name of an installed family.
  // `tracking` is letter-spacing in ems, `scale` the type size as a fraction
  // of screen height.
  readonly property var passageStyle: {
    if (passageFont === "jost") {
      return {
        family: jostFont.status === FontLoader.Ready ? jostFont.name : "sans-serif",
        axes: { "wght": 250 }, caps: true, tracking: 0.22, scale: 0.032
      }
    }
    if (passageFont === "cinzel") {
      return {
        family: cinzelFont.status === FontLoader.Ready ? cinzelFont.name : "serif",
        axes: { "wght": 400 }, caps: true, tracking: 0.12, scale: 0.036
      }
    }
    return { family: passageFont, axes: {}, caps: false, tracking: 0.04, scale: 0.042 }
  }

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

  // The passage the screensaver spells out, one part every ten seconds,
  // carrying on from where it stopped the last time. passage.txt ships with
  // the plugin; a file at ~/.config/omarchy/annihilation-passage.txt replaces it.
  property var shippedParts: []
  property var customParts: []
  readonly property var passageParts: customParts.length > 0 ? customParts : shippedParts
  property int passageIndex: 0
  property string passageText: ""
  property real passageOpacity: 0

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
    passageFont = typeof entry.passageFont === "string" && entry.passageFont.length > 0 ? entry.passageFont : "jost"
    screensaverBrightness = typeof entry.screensaverBrightness === "number" ? clamp(entry.screensaverBrightness, 0.02, 1) : 0.16
    screensaverSecondsSetting = typeof entry.screensaverSeconds === "number"
      ? Math.max(0, Math.round(entry.screensaverSeconds)) : 0

    var idle = cfg && cfg.idle && typeof cfg.idle.screensaver === "number" ? cfg.idle.screensaver : 150
    idleScreensaverSeconds = Math.max(10, Math.round(idle))
  }

  // One part per line. A line too long for the screen is broken at a word,
  // preferably after punctuation, so a pasted paragraph still reads in turn.
  // Ellipsis dots (". . .") stay with the word before them: never a break
  // point, and never a part of their own.
  function partsFrom(raw) {
    var parts = []
    String(raw || "").split("\n").forEach(function(line) {
      line = line.trim()
      if (line.length === 0 || line.charAt(0) === "#") return
      var words = line.split(/\s+/)
      var chunk = ""
      for (var i = 0; i < words.length; i++) {
        var word = words[i]
        var isDots = /^[.\u2026]+$/.test(word)
        if (!isDots && chunk.length > 0 && chunk.length + word.length + 1 > 90) {
          parts.push(chunk)
          chunk = word
        } else {
          chunk = chunk.length > 0 ? chunk + " " + word : word
        }
        var dotsFollow = i + 1 < words.length && /^[.\u2026]+$/.test(words[i + 1])
        if (chunk.length > 55 && /[.;:!?,\u2026]$/.test(word) && !dotsFollow) {
          parts.push(chunk)
          chunk = ""
        }
      }
      if (chunk.length > 0) parts.push(chunk)
    })
    return parts
  }

  function advancePassage() {
    var parts = passageParts
    if (parts.length === 0) {
      passageText = ""
      return
    }
    passageIndex = passageIndex % parts.length
    passageText = parts[passageIndex]
    passageIndex = (passageIndex + 1) % parts.length
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
    if (screensaverActive) {
      passageStart.restart()
    } else {
      passageStart.stop()
      passageCycle.stop()
      passageOpacity = 0
      screensaverForced = false
    }
  }

  Component.onDestruction: if (screensaverActive) setCursorHidden(false)

  FontLoader {
    id: jostFont
    source: Qt.resolvedUrl("fonts/Jost.ttf")
  }

  FontLoader {
    id: cinzelFont
    source: Qt.resolvedUrl("fonts/Cinzel.ttf")
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

  FileView {
    id: passageFile
    path: root.dir + "passage.txt"
    printErrors: false
    onLoaded: root.shippedParts = root.partsFrom(text())
  }

  FileView {
    id: customPassageFile
    path: root.home + "/.config/omarchy/annihilation-passage.txt"
    watchChanges: true
    printErrors: false
    onLoaded: root.customParts = root.partsFrom(text())
    onFileChanged: reload()
    onLoadFailed: root.customParts = []
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.themeActive && root.screensaverEnabled
    timeout: root.screensaverSeconds
    respectInhibitors: true
  }

  // Wait out the wallpaper's fade-in, then show a part every ten seconds:
  // kindle for 2.5 s, hold for 5, fade for 2.5.
  SequentialAnimation {
    id: passageStart
    PauseAnimation { duration: 3000 }
    ScriptAction { script: passageCycle.start() }
  }

  SequentialAnimation {
    id: passageCycle
    loops: Animation.Infinite
    ScriptAction { script: root.advancePassage() }
    NumberAnimation { target: root; property: "passageOpacity"; from: 0; to: 1; duration: 2500; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 5000 }
    NumberAnimation { target: root; property: "passageOpacity"; to: 0; duration: 2500; easing.type: Easing.InOutSine }
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
        passageFont: root.passageStyle.family,
        screensaverBrightness: root.screensaverBrightness,
        screensaverActive: root.screensaverActive,
        passageParts: root.passageParts.length,
        customPassage: root.customParts.length > 0
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
