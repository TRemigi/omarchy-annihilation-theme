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
- **What the Shimmer actually looks like** (from the user's reference stills and
  a trailer recording in `~/Videos`, studied with `ffmpeg` frame extraction, and
  with saturation boosted to see structure). The user's words: the air itself
  seems to *refract light like a prism*. In the reference photo the effect is a
  broad sweep of hue (blue, violet, magenta, orange, olive) that shifts the
  colour of the foliage while keeping its brightness and detail: only 0.24
  saturated against 0.42 for clean foliage, no glow, no streaks. In the trailer
  it is also light: a narrow curtain with a warm core made of thin straight
  columns, its colour separating across the width.
- **The current design** (`shimmer.frag`) is a continuous *tint* plus gentle
  *light*:
  - The **tint** has no mask and so no shape. It covers the screen, its strength
    varies smoothly (the floor is 10% of its peak), and its hue is *one smooth
    value* that runs once through the spectrum, from a noise field that is warped
    so that it swirls, plus a finer second field for irregularity. It is blended,
    so the scene keeps its detail.
  - The **light** is a few additive curtains with faint straight columns and a
    weak warm core, as before.
- **Lessons from the versions that were wrong** (each rejected by the user for
  the stated reason): a band crossing on a 90 s schedule (scripted); big pale
  translucent veils (large, pale, a flat layer on the wallpaper); additive
  columns with a domain warp (wavy streaks, no pink); strong hot cores (glowing
  orbs, pale pink blooms); a tint whose *shape* came from thresholding noise
  (`smoothstep` of fbm into a mask), which gave "splotchy, like the goo in a lava
  lamp" (thresholded noise always makes blobs); and **prism fans** from point
  sources beyond the screen edges, with colour by angle, rays and RGB-split
  fringes: physically more literal, but "too spotlight-y, too uniform, very
  artificial" (a single source reads as a spotlight, and every fan has the same
  structure). The user preferred the tint-plus-curtains version, so the final
  design keeps that and removes only what made it blobby. The lesson: for this
  effect, organic irregularity matters more than optical accuracy. Do not use a
  noise threshold as a shape, and do not use a point source.
- **Never make hue cyclic.** If hue wraps through the spectrum repeatedly as a
  function of a noise field (`sin(2*pi*field*k)`), its contours close into
  concentric rings around the peaks (they look like soap bubbles). Adding a
  steady linear ramp to open the rings makes the bands parallel, which reads as
  stripes ("the bands definitely read as stripes"). Both were tried and rejected.
  What works is a single smooth value, mapped once from one end of the spectrum to
  the other, from a warped noise field.
- The colour scale (`washSpectrum`, `lightSpectrum`) has teal, blue, violet,
  magenta, pink, orange and amber, with stops spaced so magenta and pink get the
  widest share. The user asked for "pinkish hues in addition to the ones it has".
  Measured over 15 minutes and four seeds, brightness-weighted: pink and magenta
  about 31%, blue 22%, violet 19%, orange and amber 15%, teal and green 14%
  (`extras/dev/hue-shares.py`, on the real shader). Measure hue shares over
  time rather than trusting a stop list; a mapping's centre and slope decide
  which colours dominate.
- The colour scale (`washSpectrum`, `lightSpectrum`) has teal, blue, violet,
  magenta, pink, orange and amber, with stops spaced so magenta and pink get the
  widest share. The user asked for "pinkish hues in addition to the ones it has".
  Measure hue shares over time rather than trusting a stop list.
- The palette lives in the shader as constants (`W_*` mid-tone colours for the
  tint, `L_*` lighter ones for the light), not as uniforms and not from the shell
  theme. Blend only neighbouring hues; violet with teal passes through grey. Pink
  over a green forest mixes toward grey-mauve (near-complements), so pink reads
  best in the additive light and looks dustier in the tint.
- Nothing about the Shimmer may be a scheduled sweep. It is 3D value noise with
  time as the third axis plus a random per-session `seed`. Check statistics over
  many minutes and seeds, not at one instant. "Dynamic" is measured as the
  overlay's mean change per second relative to its own level
  (`extras/dev/overlay-rate.py`, on the real shader): the veil version was 0.04,
  light curtains about 0.21 and felt alive (0.38 felt like flicker), the first
  tint 0.10-0.14 (the user asked for a little more), and the current one 0.18-0.20.
  Overall overlay brightness (mean of the largest colour channel) has a median of
  about 0.11, against 0.07 for the masked version; a first draft at 0.13 looked
  hazy, so the tint strength is 0.34, and the user can use the intensity slider.
- **Window glow** (`WindowGlow.qml`, `shaders/windowglow.frag`): the user asked to
  take the prism-fan version (the one rejected as a wallpaper effect: "spotlight-y,
  uniform, artificial") and have it spill over window edges as if from behind. So
  the fans are not drawn on the wallpaper at all; they are the light source behind
  the windows, and a window edge lights up where a fan reaches it. It must be a
  layer ABOVE the windows (`WlrLayer.Top`), click-through, additive, drawing only a
  thin band along each edge (inside, plus a tighter halo outside), and hidden under
  fullscreen. Window rectangles come from `Hyprland.toplevels` (`lastIpcObject`:
  `at`, `size`, `workspace.id`, `monitor`, `focusHistoryID`), refreshed on
  Hyprland raw events plus a 1.5 s poll, because an interactive resize raises no
  event; stacking order is approximated by focus history. Outside a window the
  band is clipped to the monitor's `reserved` strips so the halo never paints over
  a bar. Limits: six windows per screen, and the glow lags during a resize or
  drag until it ends. Not seen against a live Hyprland by the agent.
  First live feedback (screenshots from the user): the glow "projected way too far
  into the windows", its colours were "too distinct/separated", and it was "not
  respecting the window corner radius". Causes and fixes: (1) the reach was a
  fraction of screen height tuned on a 540 px preview (about 90 px at 1190 px high,
  and the glow ran to 2.6 times that); it is now `clamp(0.026 * height, 16, 44)`
  with a steeper falloff, so it hugs the edge like a window shadow; judge reach in
  pixels at the user's real resolution, not in a scaled preview. (2) The fans'
  spectrum was as wide as on the wallpaper, and a second hue sweep ran across the
  band's depth, so colour changed quickly along and across every edge. The glow now
  uses a narrow slice of the spectrum (0.20 of the angle, not 0.45) and almost no
  depth sweep (0.06), so neighbouring colours blend. (3) I had given the glow its
  own 40 px corner radius to hide creases, so it drew rounded windows round square
  ones (the user's real radius is 4 px, set in `extras/hypr/annihilation.lua`).
  `WindowGlow.qml` now reads `decoration:rounding` and `general:border_size` with
  `hyprctl getoption ... -j | jq` (failure keeps 4 and 2), inflates each rectangle
  by the border (the border is drawn outside `at`/`size`), and the shader keeps the
  true radius at the edge while a smooth max rounds off the inside diagonal creases.
  Second round of feedback (from a screen recording): the user likes the soft
  shimmering band around the edges, but its inner edge needed to be softer, and the
  bright spots "still need a lot of work": they should look like bright spots,
  "without the spotlighty projecting effect". The spots had come from the fan's
  rays, so they streaked across the edge like beams. They are now `glints()` in
  `windowglow.frag`: plain isotropic Gaussian blobs on a coarse hashed grid (about
  one cell in seven, so a few at a time), drifting and twinkling slowly, with a
  colour from the pink-violet-blue part of the spectrum mixed with a little aqua,
  shown only near an edge and faded to nothing before the shader's cut-offs. The
  band's falloff is now a mix of an exponential and a Gaussian with a long smooth
  tail (no kink, and its end is faded to zero). Rule: anything that should read as a
  *spot* must be radially symmetric; any structure borrowed from the fans (rays,
  angle) reads as a projected beam. Judge counts at the user's size: a few per large
  window, not a string of lights, and keep the peak below white.
  Third round (two screen recordings): it still looked spotlit sometimes, the inner
  edge could be softer still, and "the colours move around and glob with these very
  hard edges". Causes: (1) `fanField` *chose* the stronger of the two fans at each
  pixel, so hue and strength jumped along a line wherever the fans cross, and that
  line drifts as they wander: the hard-edged globs. It now blends them, with a
  strength-weighted mean hue. Never pick between fields with `if (a > b)`; blend.
  (2) The rays were still in the strength (a 50% modulation), which is where the
  residual spotlight came from; they are down to 15%. (3) The brightness was
  hard-clipped with `clamp`, so the brightest patches were flat discs with an edge
  where they dropped below the clip (2.4% of glow pixels after a gain increase). It
  now rolls off with `1 - exp(-x)`, 0% clipped. (4) The inner tail is longer and
  more Gaussian, and the bright line at the edge is fainter. Measured on the real
  shader over a synthetic desktop: clipped 0.5% to 0.0%; colour change along an edge
  0.0010 to 0.0007 per pixel. A "sharpest gradient" metric did NOT show the
  improvement (0.056 to 0.063) because the glints dominate it; metrics must match the
  complaint, and the clipping count did. The glow's rate of change in time is about
  0.05 of its level per second, calmer than the main layer's 0.2, and the user has
  not asked for more.
  Fourth round (a screen recording): "you can still see the sharp edges between
  colors sometimes; whenever that isn't happening it looks great; the colors
  shifting in the soft glowy areas looks awesome". Found by measuring the real
  shader at the user's window size (`edgehunt`-style scan: largest colour step
  between neighbouring pixels where both are bright, skipping 16 px around window
  edges), not by looking at the recording, whose compression hides it. Three causes,
  each a discontinuity: (1) `fanField` defaulted the hue to a constant 0.5 where no
  fan reaches, but a strength-weighted mean over even a trace of a fan takes that
  fan's full hue, and the ambient floor makes the glow visible everywhere, so the
  colour changed in a straight line along every fan's edge (teal to pink, over about
  2 px, 0.87 per pixel). It now has a prior (weight 0.08) pulling toward a base hue
  that drifts smoothly in space and time. A mean needs a prior, or its weights can go
  to zero. (2) Each fan's source orbited on an ellipse 1.38 times the half-extents,
  which at the diagonals passes just inside the screen corner (up to 63 px inside; within
  0.10 screen heights of the screen 38% of the time), so the source showed as the
  sharp tip of a thin wedge lit inside a window: the "spotlight". It is now a circle
  of radius 0.5 * |(aspect, 1)| * (1.28 +- 0.10): at least 0.12 screen heights away,
  always (checked over 60 seeds and 3000 s). (3) The bend noise sampled the raw
  `atan` angle, which jumps a full turn along one ray from the source, so the noise
  jumped there; it is sampled by position now. Also `strength` used sqrt of the fan
  strength, whose slope is infinite at zero (a faint line at each fan's edge); it is
  `1 - exp(-4x)`. Result: worst colour step 0.87 to 0.14, typical 0.36 to 0.07.
  The first fix flattened the colour variety the user likes (hue spread 0.55 to 0.31,
  orange 12% to 2%), so the base hue's gain was raised until the spread came back
  (2.6: spread 0.50, orange 12%). Lesson: when removing a discontinuity, re-measure
  what the user liked, because the discontinuity was carrying some of it. Method
  that worked: scan for the worst step, print the profile across it, trace its
  position row by row (a constant slope means a ray from a source), then fix the
  cause. Rule: any `if (x > 0) mean else default` must be blended, any selection
  between fields must be a blend, and nothing may sample `atan` directly.
  **Cursor mode** (`windowGlowMode: "cursor"`; the user asked for it, and for a
  performance estimate first). Only the active window (`focusHistoryID` 0, if it is on
  this screen) is passed to the shader; the glow is faint and narrow everywhere on it
  (20% gain, 0.8 of the band width) except along the span of edge nearest the pointer
  (full gain, 1.6 of the width, and a bright core). The shader gets the pointer position
  and its SIGNED distance to the nearest edge (`cursor` = x, y, d, on; negative inside).
  "Nearest" is relative: the closest part of the edge pools light even with the pointer
  mid-window, more strongly the closer the pointer is (`peak`, 0.35 to 1 over 22 band
  widths). Cursor off (`cursor.w` = 0) is byte-identical to the old shader, checked at
  several moments each time.
  **The pool is a function of position along the edge, not of distance from the pointer.**
  The first formulation used `exp(-(max(|px - pointer| - d, 0) / R)^2)`, which has a
  plateau inside a circle around the pointer and a crease where it ends: it drew a bright
  crescent when the pointer was mid-window, and bulged into the window as a half-disc dome
  (the spotlight look). Now the along-edge distance is recovered from the two signed
  distances, `lat2 = |px - pointer|^2 - (d_pointer - sd)^2` (exact for a straight edge; max
  with 0 at corners), and the pool is `exp(-lat2 / R^2)`. The bright core is the same with
  `0.25 R^2` and a tighter depth profile (`exp(-1.5 * depth / w0)`) so it sits on the edge,
  plus a warm white added after the gain, and a tighter `hotter` spot (`0.05 R^2`) inside the
  core for the very centre (peak 0.60 to 0.82 after the user asked for more); everything is tone-mapped with `1 - exp(-x)`, so
  nothing clips (0.00% of lit pixels above 0.97).
  **Span** (`windowGlowSpan`, a slider in the popup): `R = span * 8 * w0`. The default was
  chosen by measuring the pool's length (where the glow is above half way between baseline
  and peak) with the core switched off, because a core makes any such measure read its own
  narrow width: the old shader 521 px, R = 7.5 w0 368 px, R = 8 w0 395 px (24% shorter, the
  "bit smaller" the user asked for), R = 9 w0 433 px. Range 0.5 to 2.5: below about 0.5 the
  band's depth changes faster along the edge than the glow can follow, and the pool turns
  into a boxy arrowhead. The core is 30% of the pool's length at every span, and its centre is
  about 2.8x brighter than before this change and nearly white (whiteness 0.9).
  Cost (CPU rasteriser, 1880x1190, ratios only): all mode with three windows 92 ms; cursor
  mode, one window, 47 to 54 ms. Pitfall: the first early exit must allow for the widest
  possible band, so it needs a second, tight one once the local width is known. Hard-edge
  scan with the pointer in five places and the span at 0.5, 1 and 2.5: worst colour step
  0.08 to 0.10, as with it off.
  **The pointer feed** (`CursorTracker.qml`) is the part with real cost and the part that
  could NOT be tested here (the sandbox forbids creating sockets). Hyprland has no pointer
  event and a click-through layer cannot receive hover, so it polls: first over Quickshell's
  `Socket` to `Hyprland.requestSocketPath` (what hyprctl does; no process; sends `cursorpos`;
  Hyprland replies "x, y" and closes the connection), and after six consecutive misses it
  falls back to spawning `hyprctl cursorpos` (about 7 ms of CPU a spawn, so 6 polls a
  second, about 4% of a core), and after six more to "none" (the glow goes uniform).
  `omarchy-shell shimmer status` reports `cursorSource` ("socket", "hyprctl" or "none"),
  `cursorKnown` and `cursor`: **check that first** if cursor mode does nothing. It polls
  only while the glow is visible and in cursor mode, at 30 Hz while the pointer moves and
  about 7 Hz once it has rested. Unverified assumptions, in order of doubt: that
  `SplitParser { splitMarker: "" }` delivers an unterminated reply (the fallback covers
  it failing); that the `connected` property goes false when Hyprland closes the
  connection; that `Socket` is allowed for a third-party plugin (no first-party code uses
  it). A fourth route, not built because it runs user code on the compositor's main
  thread (a bug there stalls the desktop): a Hyprland Lua `hl.timer` calling
  `hl.get_cursor_pos()` and writing to a file the plugin watches. Logic tests (reply parsing,
  the miss and fallback state machine, active-window choice, edge distance, the shader
  uniform) are in `extras/dev/cursor-tracker-test.js` and `extras/dev/window-glow-test.js`,
  which run the real functions from the QML files in node; every check was confirmed to
  fail when its code is broken on purpose. `extras/dev/edge-scan.py` is the hard-edge scan
  that found the colour edges (run it on any change to the glow).
  Other lessons: (a) a "which way does the edge face" term made diagonal
  picture-frame seams at corners, because the nearest edge switches along the
  diagonal; it was removed. (b) A glow cut off at a fixed depth while still bright
  shows as a dark inner rectangle, so fade it to zero. (c) `half` is a reserved
  word in GLSL. Test with `RECTS="x,y,w,h;..." RIM=18 ROUNDING=4 harness ...` (see
  `extras/dev/shader-harness.c`) over a synthetic desktop.
- **The shader's clock is accumulated, not read from the wall clock**
  (`Service.shimmerClock`, advanced by a service timer by elapsed time times
  `layerSpeed`, with a stall clamped to 0.25 s). Multiplying wall time by a speed
  would make every pattern lurch when the slider moves. All screens share it. If
  you add another time-based control, keep it integrated the same way.
- **Additive blending.** In the default mode the light part of the shader outputs
  colour larger than its alpha, which a premultiplied "over" blend turns into added light.
  That is outside what the Wayland spec promises, so the `layerAdditive` setting
  (and the `additive` uniform) falls back to an ordinary translucent layer. If
  the light ever shows up black or washed out on another compositor, turn it off
  first. `intensity` is multiplied by 2 inside the shader so that the default
  0.35 is the strength the look was designed at.
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
  only reaches a dim level (`screensaverBrightness`, now 0.08) while the text goes to full, and opacity is linear
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
- **Shaders can be run for real here.** `extras/dev/shader-harness.c` runs a
  compiled shader on Mesa's software GL through headless EGL (`gcc`, EGL and
  GLES3 headers and llvmpipe are installed) and writes a PAM frame. Extract the
  GLSL ES variant Qt would use with `qsb -x "glsl,100 es"`; the commands are in
  the file's header. It proved `shimmer.frag` equal to its NumPy preview to a
  mean 0.001-0.003 per channel. Output is **premultiplied**: composite with
  `rgb + bg * (1 - alpha)`, not as straight alpha. It does not test the Qt
  integration (uniform names must match the QML properties by name; check them
  against `qsb --dump`), and its timings are a CPU rasteriser's, not a GPU's.
- For look development, a vectorised NumPy port of the shader in a throwaway
  venv (`python3 -m venv $TMPDIR/venv && pip install numpy pillow`; PyPI is
  reachable) renders a frame in about 2 s, versus minutes in pure Python. Port
  it line for line, then run the real thing through the harness to catch typos.
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

Settings (inline on the plugin entry): `layerEnabled`, `layerIntensity` (0.35), `layerSpeed` (1),
`motes`, `fpsCap` (30), `screensaver`, `screensaverSeconds` (0 follows
`idle.screensaver`), `screensaverBrightness` (0.08), `passageFont` (`jost`,
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

Confirmed by the user by sight: the portable theme, the Hyprland extras, plugin
loading, the bar glyph and popup including the **Speed slider**, the screensaver
(fade-in from black, the crawling passage and its timing, the **stronger text
glow**, and the **darkness at `screensaverBrightness` 0.08**), and the **final
Shimmer layer** ("looking quite good now, keep it"). The Shimmer took seven rounds
of feedback to reach (see the lessons above); do not redesign it without a new
complaint from the user, and if you must change it, change one thing and measure
with `extras/dev/overlay-rate.py` and `extras/dev/hue-shares.py`.

Open items:

- `preview.png` is missing (needs a real screenshot of the finished desktop;
  the user will supply or take one).
- Border rotation period under the 100-speed cap is unconfirmed; the user may
  prefer it static or slower (a slower version would need the plugin to drive
  the angle itself).
- A themed `[lock]` placeholder phrase was in the original plan and never done.
- The `shell.toml` gradient strings and `updateEntryInline` from a bar widget
  were assumed to work and appeared to, but were never inspected in the source.
- Additive blending (`layerAdditive`) is assumed to work on the user's
  compositor; it did, as far as the user has said, but it is outside what the
  Wayland spec promises.
- The film's effect also seems to bend the picture behind it. Doing that would
  mean the layer samples the wallpaper and displaces it: a bigger change that
  risks mismatching the real wallpaper during theme transitions. Only worth
  trying if the user says the Shimmer feels flat.
- The user's wallpaper already contains baked-in iridescence, so the layer is
  hardest to see on that still; the darker stills show it best.

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
