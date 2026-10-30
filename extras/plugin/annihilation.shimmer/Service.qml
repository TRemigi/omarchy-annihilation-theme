// Annihilation Shimmer: owns the settings, the theme gate, the per-screen
// wallpaper layers and the screensaver. Everything is dormant unless the
// active theme is annihilation, so leaving the plugin enabled across theme
// switches is safe.
//
// Settings are inline fields on this plugin's entry in shell.json `plugins[]`:
//   layerEnabled (bool, true), layerIntensity (0-1, 0.35), layerSpeed (0.1-4, 1),
//   motes (bool, true), windowGlow (bool, true: light spilling over window edges),
//   windowGlowMode ("all", or "cursor": the active window only, pooled near the pointer),
//   windowGlowSpan (0.5-2.5, 1: how much length of edge the pool covers, in cursor mode),
//   windowGlowDepth (0.02-2.5, 1: how far into a window the glow reaches),
//   windowGlowCenter (0-2.5, 1: brightness of the cursor glow's bright centre; "Glow brightness" in the popup),
//   layerAdditive (bool, true),
//   fpsCap (5-60, 30), screensaver (bool, true),
//   screensaverSeconds (0 = follow idle.screensaver in shell.json),
//   screensaverBrightness (0.02-1, 0.08: how much of the photo shows),
//   crawlSpeed (0.5-8, 2.5: type-sizes per second),
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

  // Random per session, so the light is never in the same places twice.
  readonly property real shimmerSeed: Math.random() * 100.0

  property bool themeActive: false

  property bool layerEnabled: true
  // Add the light to the wallpaper (true), or blend it as an ordinary
  // translucent layer. Additive stores colour values above their alpha, which a
  // compositor is free to mishandle; this is the way back if it does.
  property bool layerAdditive: true
  // Light spilling over the edges of windows, from behind them (WindowGlow.qml).
  property bool windowGlow: true
  // "all": every window glows evenly. "cursor": only the active window does, faintly, with the
  // span of its edge nearest the pointer wider and brighter.
  property string windowGlowMode: "all"
  // How much length of edge the pool covers in cursor mode, as a multiple of the default.
  property real windowGlowSpan: 1.0
  // How far into a window the glow reaches, as a multiple of the default.
  property real windowGlowDepth: 1.0
  // How bright the centre of the cursor glow (its core and bright point) is, as a multiple of the default.
  property real windowGlowCenter: 1.0
  property real layerIntensity: 0.35
  // How fast the Shimmer evolves, as a multiple of its natural pace.
  property real layerSpeed: 1.0
  property bool motes: true
  property int fpsCap: 30
  property bool screensaverEnabled: true
  property int screensaverSecondsSetting: 0
  property int idleScreensaverSeconds: 150
  property string passageFont: "jost"
  property real screensaverBrightness: 0.08
  property real crawlSpeed: 2.5

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

  // The passage the screensaver crawls, carrying on from where it stopped the
  // last time (the screensaver writes passageIndex back). passage.txt ships
  // with the plugin; a file at ~/.config/omarchy/annihilation-passage.txt
  // replaces it.
  property var shippedParts: []
  property var customParts: []
  readonly property var passageParts: customParts.length > 0 ? customParts : shippedParts
  property int passageIndex: 0

  // The shader's clock, in seconds, shared by every screen. It is accumulated
  // rather than read from the wall clock, so changing layerSpeed speeds the
  // Shimmer up or slows it down from where it is instead of making it jump. It
  // starts at a random point, so each session begins mid-drift.
  property real shimmerClock: Math.random() * 3600
  property real lastTickMs: 0

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
    layerAdditive = entry.layerAdditive !== false
    windowGlow = entry.windowGlow !== false
    windowGlowMode = entry.windowGlowMode === "cursor" ? "cursor" : "all"
    windowGlowSpan = typeof entry.windowGlowSpan === "number" ? clamp(entry.windowGlowSpan, 0.5, 2.5) : 1.0
    windowGlowDepth = typeof entry.windowGlowDepth === "number" ? clamp(entry.windowGlowDepth, 0.02, 2.5) : 1.0
    windowGlowCenter = typeof entry.windowGlowCenter === "number" ? clamp(entry.windowGlowCenter, 0, 2.5) : 1.0
    motes = entry.motes !== false
    layerIntensity = typeof entry.layerIntensity === "number" ? clamp(entry.layerIntensity, 0, 1) : 0.35
    layerSpeed = typeof entry.layerSpeed === "number" ? clamp(entry.layerSpeed, 0.1, 4) : 1.0
    fpsCap = typeof entry.fpsCap === "number" ? Math.round(clamp(entry.fpsCap, 5, 60)) : 30
    screensaverEnabled = entry.screensaver !== false
    passageFont = typeof entry.passageFont === "string" && entry.passageFont.length > 0 ? entry.passageFont : "jost"
    screensaverBrightness = typeof entry.screensaverBrightness === "number" ? clamp(entry.screensaverBrightness, 0.02, 1) : 0.08
    crawlSpeed = typeof entry.crawlSpeed === "number" ? clamp(entry.crawlSpeed, 0.5, 8) : 2.5
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

  FontLoader {
    id: jostFont
    source: Qt.resolvedUrl("fonts/Jost.ttf")
  }

  FontLoader {
    id: cinzelFont
    source: Qt.resolvedUrl("fonts/Cinzel.ttf")
  }

  // Polled only while something needs the pointer.
  readonly property bool cursorTracking: themeActive && layerEnabled && windowGlow
    && windowGlowMode === "cursor" && !screensaverActive
  readonly property alias pointer: pointerTracker

  CursorTracker {
    id: pointerTracker
    active: root.cursorTracking
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

  // Advances the clock at the frame rate cap. A long gap (the machine slept, the
  // shell stalled) counts as at most a quarter of a second.
  Timer {
    interval: Math.round(1000 / Math.max(5, Math.min(60, root.fpsCap)))
    running: root.running
    repeat: true
    onRunningChanged: if (running) root.lastTickMs = Date.now()
    onTriggered: {
      var now = Date.now()
      root.shimmerClock += Math.min(0.25, (now - root.lastTickMs) / 1000) * root.layerSpeed
      root.lastTickMs = now
    }
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
        layerAdditive: root.layerAdditive,
        windowGlow: root.windowGlow,
        windowGlowMode: root.windowGlowMode,
        windowGlowSpan: root.windowGlowSpan,
        windowGlowDepth: root.windowGlowDepth,
        windowGlowCenter: root.windowGlowCenter,
        cursorSource: pointer.source,
        cursorKnown: pointer.known,
        cursor: [pointer.cursorX, pointer.cursorY],
        layerIntensity: root.layerIntensity,
        layerSpeed: root.layerSpeed,
        motes: root.motes,
        fpsCap: root.fpsCap,
        screensaverEnabled: root.screensaverEnabled,
        screensaverSeconds: root.screensaverSeconds,
        passageFont: root.passageStyle.family,
        screensaverBrightness: root.screensaverBrightness,
        crawlSpeed: root.crawlSpeed,
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

    WindowGlow {
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
