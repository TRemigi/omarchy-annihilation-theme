# AGENTS.md

Guide for an agent continuing work on **omarchy-annihilation-theme**. Read this
before changing anything. `README.md` is the user-facing doc; this file is the
why, the gotchas, and how to verify your work.

## What this is

An [Omarchy](https://omarchy.org/) (Arch + Hyprland + a Quickshell-based shell)
theme themed after *Annihilation* (Alex Garland's 2018 film, from Jeff
VanderMeer's novel). It has two tiers:

1. **Portable theme**, at the repo root. Installs with `omarchy theme install`.
2. **Extras**, in `extras/`. Hyprland Lua plus a Quickshell plugin, symlinked
   into `~/.config` by `extras/install link`. Omarchy cannot carry these inside
   a repo-installed theme (see Gotchas).

```
colors.toml            palette (Swamp Dark base16) + hyprland_{active,inactive}_border
shell.toml             hand-tuned shell surfaces; REPLACES the generated one
btop.theme             hand-tuned
unlock.png             the Omarchy wordmark recolored #61A0A8 (disk-unlock screen)
preview-unlock.png     composed mock of the above
backgrounds/           film stills (1-, 3-); 2- was deliberately dropped
extras/install         link | unlink | status (idempotent bash)
extras/hypr/annihilation.lua        border/shadow/blur/dim/animation tweaks
extras/hooks/theme-set.sh           loads the Lua; toggles the stock screensaver
extras/plugin/annihilation.shimmer/ the Quickshell plugin (see below)
```

Plugin files: `manifest.json` (service + bar-widget), `Service.qml` (settings,
theme gate, IPC, idle monitor, passage parts, font loading), `ShimmerLayer.qml`
(wallpaper overlay per screen), `Screensaver.qml` (overlay per screen),
`Crawl.qml` (the scrolling, glowing text line),
`BarWidget.qml` + `Panel.qml` (prism glyph and popup), `shaders/*.frag` and the
committed compiled `*.frag.qsb`, `fonts/` (Jost, Cinzel + OFL licences),
`passage.txt` (screensaver text), `journal.txt` (popup daily entries).

## Design approach and inspiration

The brief: **subdued psychedelic horror mixed with the beauty of nature.**

- The palette is the brown marsh. The Shimmer (teal `#61A0A8`, bruised magenta
  `#91506C`, amber `#DB930D`, moss `#7A7653`) shows up only at edges: borders,
  halos, a faint band, spores. Never a rainbow, never saturated fill.
- **Everything is slow and low-alpha.** Periods of 20 to 90 s, intensities that
  you notice only afterwards. If a change makes something louder, it is
  probably wrong. Defaults: layer intensity 0.35, spores faint, caustics
  barely there.
- Beauty with wrongness: oil-slick thin-film colour, spores rising, a cell
  lattice (Lena's cells under the microscope) growing over the screensaver,
  text that glows like the fungal writing on the tower wall.
- **Dormant elsewhere.** Every extra gates on `theme.name == "annihilation"`
  and goes inert on other themes. Keep that property for anything new.
- Cheap by design: layer shader renders at half resolution at 30 fps and
  pauses under fullscreen windows. The glow layers are static textures.

Inspiration and context: the film and novel; Swamp Dark base16
(`tinted-theming.github.io/tinted-gallery/#base16-swamp-dark`); thin-film
iridescence (oil on water); bioluminescent fungi.

## Copyright and content rules

- The screensaver text in `passage.txt` and the entries in `journal.txt` are
  **original** writing in the manner of the book. Do not paste the novel's
  tower-wall passage (or other long passages) into the repo.
- The user can drop the real text in `~/.config/omarchy/annihilation-passage.txt`
  (local, not tracked); the service prefers it automatically.
  The user has done this with the book's opening passage. That file lives
  outside the repo and must stay out of it: never copy it into the tree, the
  tests or a commit message.
- `Service.partsFrom` splits that file into screensaver parts. Ellipsis dots
  (`. . .`) must stay attached to the preceding word and are never a break
  point; without that rule each ellipsis became a stray part of its own.
- The film's logotype is custom and unconfirmed. Jost is the nearest free look,
  not a match; say so rather than claiming otherwise.
- Only bundle fonts with clear licences (SIL OFL here). Expedition Annihilation
  and Kiona have unclear licences, so they are not bundled; users can install
  them and set `passageFont` to the family name.

## Gotchas (each of these cost real time)

### Omarchy theming

- `omarchy theme install` (any theme dir with `.git`) **drops `*.lua`, terminal
  configs and `vscode.json`**. `hyprland.lua` is regenerated from `colors.toml`
  via `$OMARCHY_PATH/default/themed/*.tpl`. Hence the extras tier.
- `hyprland_active_border` / `hyprland_inactive_border` in `colors.toml` feed
  both the Hyprland and the shell border templates, with no Lua needed.
- A theme's own `shell.toml` replaces the generated one wholesale, so it must
  contain every section (copy `~/.local/state/omarchy/current/theme/shell.toml`
  as a base). Gradient strings use the Hyprland form
  (`"rgba(..) rgba(..) 50deg"`). That form follows the template comments; it was
  never confirmed against the renderer.
- `unlock.png` is the 800x188 Omarchy **wordmark** for the disk-unlock screen,
  not a lock-screen background.
- Never edit `/usr/share/omarchy`. It is read-only reference (and safe to read).
- `omarchy-theme-set` runs `omarchy-restart-hyprctl` **before** the `theme-set`
  hooks, so the hook must `hyprctl reload` again after touching the Lua.
- The `theme-set` runner executes `~/.config/omarchy/hooks/theme-set.d/*.sh` and
  aborts on a non-zero exit. The hook always `exit 0`.
- `omarchy hook install` **copies** the file. We symlink instead so the hook can
  resolve the repo path with `readlink -f`.
- `omarchy-toggle <flag> on|off` is explicit; bare `toggle` flips. The stock
  screensaver is disabled by the flag file `screensaver-off`. The hook sets it
  only while annihilation is active, records a marker
  (`~/.local/state/annihilation-theme/screensaver-off-by-us`), and restores it
  only if it set it. A flag the user set themselves is left alone.

### Hyprland (Lua config, v0.56)

- `hl.animation` **speed is capped at 100** (deciseconds). `borderangle` with
  `style = "loop"` at 100 is the slowest rotation available; the real period is
  unverified. Check with `hyprctl reload && hyprctl configerrors`.
- `windowsOut`/`windowsIn` styles are `popin`/`slide`/`gnomed`, never `fade`.
- Layer rules: `hl.layer_rule({ match = { namespace = ... }, blur = true,
  ignore_alpha = 0.3 })`, plus `no_anim`. Field names come from
  `/usr/share/hypr/stubs/hl.meta.lua` (the best offline API reference). The
  animation functions are not in the stubs; copy usage from
  `/usr/share/omarchy/default/hypr/looknfeel.lua`.
- The extras are appended as `pcall(dofile, "...") -- annihilation-extras` to
  the staged `~/.local/state/omarchy/current/theme/hyprland.lua`. The marker is
  how the hook and installer stay idempotent. It starts with `--`, so use
  `grep -qF -- "$MARK"`.
- Namespaces in play: `omarchy-bar`, `-menu`, `-notifications`, `-osd`,
  `-polkit`, `-reminders`, `-clipboard`, `-emojis`, `-image-selector`,
  `-background`; ours are `annihilation-shimmer` and `annihilation-screensaver`.

### Quickshell plugin

- **`keepLoaded: true` blocks hot reload of a service.** It was removed from the
  manifest. If you ever see old behaviour after `rescanPlugins`, check this,
  then fall back to `omarchy restart shell`.
- The plugin dir is **symlinked**. The shell's watcher (`inotifywait -r`) does
  not follow symlinks, so after editing run `omarchy-shell shell rescanPlugins`.
  Discovery (`for sub in "$dir"/*/`) does follow them.
- `omarchy plugin validate` rejects a symlinked plugin folder; validate the real
  path (`omarchy plugin validate extras/plugin/annihilation.shimmer`).
  `plugin add/update` are the only callers; symlinks are otherwise supported.
- `omarchy plugin enable/disable` go through shell IPC, so the shell must be
  running. The installer tolerates it not running and prints what to run later.
- Third-party services are created with a null parent and get `shell` as a
  scoped facade. `shell.idleConfig` is `{}` for anything that is not an idle
  clone, so the service reads `idle.screensaver` from `shell.json` itself.
  Settings live on the plugin's entry in `plugins[]` **or** in its
  `bar.layout.*` entry once the widget is placed. `Service.applyConfig` reads both.
- `shell.updateEntryInline(id, patch)` persists settings (the clock widget uses
  `root.bar.shell.updateEntryInline`).
- A file named `BarWidget.qml` that extends `BarWidget` (and `Panel.qml` extends
  `Panel`) works because the first-party clock does the same. `qmllint` calls it
  an inheritance cycle; ignore that.
- `FileView`: use `onLoaded: x(text())` plus `onFileChanged: reload()`;
  `text()` is stale inside the change signal.
- `/proc` files and `FileView` are untested; the popup uses `cat /proc/uptime`
  through `Process`.
- Do not use a running `ColorAnimation`/`NumberAnimation` for something that
  just changes slowly in the bar; it forces a repaint every frame. The glyph
  uses a 1 s `Timer` instead.
- `Screensaver` is driven by `IdleMonitor` (respects inhibitors), so idle-driven
  instances end on any input. IPC-summoned ones set `screensaverForced`, take
  keyboard focus and end on key or click.
- The cursor is hidden through `hyprctl eval 'hl.config({ cursor = { invisible
  = true } })'`, falling back to `hyprctl keyword`. `Component.onDestruction`
  restores it, so a reload mid-screensaver does not strand a hidden cursor.

### Shaders and rendering

- `ShaderEffect` needs compiled `.qsb`. Edit `shaders/*.frag`, then run
  `extras/plugin/annihilation.shimmer/build-shaders.sh` (needs
  `qt6-shadertools`, at `/usr/lib/qt6/bin/qsb`). **Commit the `.qsb`** so
  installs do not need it.
- GLSL: `smoothstep(e0, e1, x)` needs `e0 < e1`. The vignette is written as
  `1.0 - smoothstep(0.35, 1.1, d)` for that reason.
- **A shader sampling an `Image` gets the whole texture and ignores
  `fillMode`.** That is why the screensaver stretched. `bloom.frag` does its own
  cover crop from the `imageAspect` uniform. Do not "fix" it back to `fillMode`.
- Output is premultiplied alpha. Qt `property color` becomes `vec4`;
  `property size` becomes `vec2`.
- `MultiEffect` as `layer.effect` makes the blurred glow layers; `blurMax` is
  the radius.
- **Glow strength** is the layer list `Crawl.glowLayers`: staggered blur radii
  (blurMax is pixels, keep it at or under 64) rather than one big blur, because
  thin letters carry little light once blurred. The wide and mid layers use
  `Text.Outline` (1 px) for roughly double the ink. Do not get the same effect
  with a heavier font weight on the halo copies: Jost's letter widths change
  with weight, so the halos drift off the real letters along a long line. Each
  blurred layer is a GPU texture per part (about 4.5 MB for the widest part on
  an ultrawide), so add layers sparingly.
- **Do not use `MultiEffect`'s mask for a soft fade.** With a gradient mask and
  default thresholds it produced a hard straight edge where the gradient starts
  (text looked "revealed from under a line"). The crawl's edge fade is
  `shaders/edgefade.frag`, used as the strip's `layer.effect` with `inset` and
  `ramp` uniforms. Anything involving layers, blur or masks is invisible to the
  offscreen tests, so screenshots from the user are the only real check; ask for
  one (`~/Pictures/screenshot-*.png`) after changing them.
- Variable fonts: set the weight with `font.variableAxes: ({ "wght": 250 })`
  (Qt >= 6.7). `FontLoader.name` is the family to use.
- The crawl is **one item per part, not one long strip**: a strip holding the
  whole passage would be tens of thousands of pixels wide, beyond GPU texture
  limits (often 8192) once blurred. The widest part (65 type-sizes) is about
  5,100 px on an ultrawide, which fits. Keep parts short if you change them.
- **A layer-shell window is often zero-wide the instant it becomes visible.**
  `Crawl` therefore sets its start position on the first `advance()` with a real
  width (`primed`), not in `restart()`. Reading `width` too early started the
  text at the left edge, so the first words crawled away unseen. A zero-width
  regression test (a Crawl with `width: 0`, widened a few steps later)
  reproduces the old failure.
- **The screensaver is one transition.** The photo fades from black with
  `smoothstep(0, 3, t)` straight to its dark level (`bloom.frag`), and the crawl
  starts fading at the same moment (`Screensaver.crawlIn`, a smoothstep Bezier).
  Do not reintroduce a delay or a separate dimming ramp: that showed up as a
  double fade. Matching the photo's *curve* was not enough, though: the photo
  only reaches 16% brightness while the text goes to full, and opacity is linear
  light, so the text looked like it popped in. It now takes 6 s and its opacity
  is `reveal^2`, which keeps pace with the photo perceptually (see the table in
  the commit message). Judge fades by perceived brightness (about `x^(1/2.2)`),
  not by the number. The first part starts at the inner end of the fade-in zone
  so it is already in view.
- Recycling in `Crawl.advance` must add the removed part's width plus the gap
  back onto `ribbonX`, or everything visibly jumps. The simulation test below
  catches that.
- Letter-spacing trails the last glyph; the text layers add
  `leftPadding: font.letterSpacing` so the ink is truly centred.
- `Text.AllUppercase` is applied through `font.capitalization`, not by
  upper-casing the string.

## How to verify (this sandbox has no GPU or compositor)

What the agent environment could not do: run Hyprland, Quickshell, or a GPU
render. The user is the only one who can confirm anything live. What works:

- Syntax and validation:
  `bash -n extras/install extras/hooks/theme-set.sh`,
  `luac -p extras/hypr/annihilation.lua`,
  `python3 -c 'import tomllib; ...'` for the TOML files,
  `omarchy plugin validate extras/plugin/annihilation.shimmer`.
- QML lint with real types: make `qs -> /usr/share/omarchy/shell` in a temp dir
  and run `/usr/lib/qt6/bin/qmllint -I <tmp> -I /usr/lib/qt6/qml file.qml`.
  Remaining `Member "x" not found on type "QObject"` warnings (for `Style.font.*`,
  `Color.bar.*`, `Style.bar.iconSlot`) are noise that first-party code also gets.
- Installer and hook: run them with `HOME=$TMPDIR/fakehome` and a copied
  `~/.local/state/omarchy/current/theme/hyprland.lua`. This is how idempotency,
  conflicts and the screensaver marker were tested.
- Shaders: compile with `qsb`; judge composition with a small pure-Python port
  of the GLSL over the real wallpaper (no NumPy was available). Port the exact
  math, resize small, and view the PNG. This tests the maths, not Qt.
- Text and fonts: `/usr/bin/qml` is **Qt5**; use `/usr/lib/qt6/bin/qml` with
  `env -u DISPLAY -u WAYLAND_DISPLAY QT_QPA_PLATFORMTHEME=
  QT_QPA_PLATFORM=offscreen` and pass args after `--`. The software renderer
  draws `Text` (so centring, wrapping, fonts and weights are testable via
  `grabToImage` and an ImageMagick `-trim` bounding box) but **not**
  `ShaderEffect` or `MultiEffect`.
- **`console.log` prints nothing in this sandbox** unless you set
  `QT_LOGGING_TO_CONSOLE=1 QT_FORCE_STDERR_LOGGING=1`. Without them a test looks
  like it silently did nothing. Reading a file from QML also needs
  `QML_XHR_ALLOW_FILE_READ=1`.
- `Crawl.qml` has `autoDrive`, `glow` and `fade` switches for tests. A harness
  that sets `autoDrive: false`, `glow: false`, `fade: false`, calls
  `advance(dt)` from a `Timer`, calls `forceLayout()` on the Row (found by
  `objectName: "crawlRibbon"`; parts are `"crawlPart"`) and checks per-step
  invariants (constant step, exact gaps, nothing popping in, ribbon reaching the
  right edge, correct cyclic order) is how the crawl was verified. Mutation
  check: removing the `ribbonX += first.width + gap` line makes it fail loudly.
- Screenshots land in `~/Pictures/screenshot-*.png`; the user can point you at
  one. The first one showed old code still running (the `keepLoaded` problem),
  so confirm the version with `omarchy-shell shimmer status` (new fields appear
  there) before debugging visuals.

Live checks for the user: `hyprctl configerrors`; `omarchy-shell shimmer
status`; `omarchy-shell shimmer pulse`; `omarchy-shell shimmer screensaver`.

## Plugin reference

Settings (inline on the plugin entry): `layerEnabled`, `layerIntensity` (0.35),
`motes`, `fpsCap` (30), `screensaver`, `screensaverSeconds` (0 follows
`idle.screensaver`), `screensaverBrightness` (0.16), `passageFont` (`jost`,
`cinzel`, or an installed family).

IPC (`omarchy-shell shimmer ...`): `toggleLayer`, `pulse`, `screensaver`,
`dismiss`, `status`.

Also a setting: `crawlSpeed` (0.5 to 8).

The passage is a continuous right-to-left crawl (`Crawl.qml`): parts fade in
near the right and out near the left, with the fades *inside* the screen (fully
transparent for the outer 8% at each end, then a 20% ramp: `fadeInset`,
`fadeWidth`), so text never seems to arrive from or leave to off-screen. Parts
are separated by seven type-sizes. `crawlSpeed` is in
type-sizes per second (default 2.5, so a part takes about 50 s to cross). The
resume index is written back to `Service.passageIndex` when the screensaver
closes, so the next run starts at the first part that was on screen. The glow
layer model is `Crawl.glowLayers`; its colours are set from `Screensaver.qml`.
Typography (family, weight axis, caps, tracking, size as a fraction of height)
is `Service.passageStyle`.

## Conventions

- **Do not `git add -A`.** The working tree contains sandbox mounts
  (`.bashrc`, `.gitconfig`, `.idea`, `.zshrc`, ... are character devices) and
  `.claude/`. Add explicit paths.
- Small, step-sized commits with a message that says why. Follow whatever
  attribution trailers the session instructions require.
- Preferred voice with the user: concise, honest about what is unverified, no
  repeated permission questions once a direction is agreed.
- Match surrounding code style: terse comments that explain why, no tutorials.

## State at the end of the first session

User-confirmed working live: the portable theme, Hyprland extras (after the
speed-cap fix), plugin loading, wallpaper layer, bar glyph and popup, screensaver
(wallpaper effect and journal text, before the passage rework). The user then
approved the direction of: very dark screensaver photo, no stretching, Jost
capitals, a stronger glow. Those last changes were verified by port and by
offscreen text tests, not by sight.

Open items:

- `preview.png` is missing (needs a real screenshot of the finished desktop;
  the user will supply or take one).
- Border rotation period under the 100-speed cap is unconfirmed; the user may
  prefer it static or slower (a slower version would need the plugin to drive
  the angle itself).
- Glow strength, `screensaverBrightness` and seam strength are taste calls and
  may need tuning after the user sees them.
- A themed `[lock]` placeholder phrase was in the original plan and never done.
- The `shell.toml` gradient strings and `updateEntryInline` from a bar widget
  were assumed to work and appeared to, but were never inspected in the source.
- The lighthouse wallpaper already contains baked-in iridescence, so the
  shimmer layer is hardest to see on it; the darker stills show it best.

## Resources

- Omarchy source (read-only): `/usr/share/omarchy/` (`shell/README.md` for the
  plugin contract and IPC, `shell/plugins/README.md`, `default/themed/*.tpl`,
  `themes/*` for examples, `bin/omarchy-theme-set`). Skill: `omarchy` (Claude
  Code), with `theming.md`, `plugins.md`, `hooks.md`, `hyprland.md`.
- Quickshell QML types:
  `/usr/lib/qt6/qml/Quickshell/**/**.qmltypes` and `https://quickshell.org/docs`.
  Hyprland module types are under `Quickshell/Hyprland/_Ipc`; idle under
  `Quickshell/Wayland/_IdleNotify`.
- Hyprland: `https://wiki.hypr.land/` (animations, variables) and
  `/usr/share/hypr/stubs/hl.meta.lua`.
- Fonts: Google Fonts repo, raw files at
  `https://raw.githubusercontent.com/google/fonts/main/ofl/<family>/`
  (remember to fetch and keep the `OFL.txt`). Download into a fresh directory
  and treat as untrusted.
- Base16 palette: `https://tinted-theming.github.io/tinted-gallery/#base16-swamp-dark`.
