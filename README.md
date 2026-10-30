# omarchy-annihilation-theme

An [Omarchy](https://omarchy.org/) theme based on the
[Swamp Dark](https://tinted-theming.github.io/tinted-gallery/#base16-swamp-dark)
base16 palette, themed after *Annihilation*. The teal accent is the Shimmer
cutting through the brown marsh: muted browns and moss, with iridescence only
at the edges, and every motion slow enough that you only notice it afterwards.

## Install

    omarchy theme install https://github.com/TRemigi/omarchy-annihilation-theme
    omarchy theme set annihilation

or copy this directory to `~/.config/omarchy/themes/annihilation` and run
`omarchy theme set annihilation`.

That gets you the palette, backgrounds, a hand-tuned `shell.toml` (translucent
bar, gradient borders on popups, notifications, menus and the lock screen), a
`btop.theme`, and the recolored disk-unlock wordmark. Hyprland borders pick up
the Shimmer gradient from `colors.toml`.

## Extras

Omarchy drops `*.lua` and shell plugins from themes installed out of a git
repo, so the live parts ship separately. Clone the repo somewhere permanent
(they are symlinked, not copied) and run:

    extras/install link

| Part | What it does |
| --- | --- |
| Hyprland | A border gradient that slowly turns, a faint teal shadow on the focused window, blur on shell surfaces, 6% dimming of inactive windows, slower open/close and workspace motion. |
| Shimmer layer | A click-through layer between wallpaper and windows, modelled on how the film shows it: the air seems to bend light. A translucent film of spectral colour (teal, blue, violet, magenta, pink, orange) drifts over the whole scene, its colour flowing and swirling into other colour and shifting the hue of whatever is behind it while keeping its detail, with the occasional faint curtain of light and warm glows drifting in from the edges. Its strength and colour vary from place to place and from moment to moment, nothing is scripted, and every session is different. Pauses under fullscreen windows. |
| Window glow | Light spilling over the edges of your windows, as if it came from behind them. Two fans of prism light enter from beyond the screen edges and wander slowly around them; a window edge lights up where a fan's light reaches it, in a soft blended band a few dozen pixels deep that dissolves smoothly inward and follows the window's real corner radius, with a faint halo just outside and a few soft bright glints drifting along the edges. In cursor mode only the active window glows, faintly, and the part of its edge nearest your pointer pools the light, spilling in outward from the pointer when it takes over from another edge. It lives in a click-through layer above the windows, hides under fullscreen windows, and follows windows as they open, close, move and change workspace (an interactive resize catches up when you let go). |
| Screensaver | After `idle.screensaver` seconds the wallpaper slowly warps, its colour channels drift apart, and a lattice of glowing cells grows over it. A passage crawls right to left as living light in one continuous line, fading in near the right of the screen and out near the left, picking up where it left off. Replaces Omarchy's text screensaver while this theme is active. |
| Bar glyph | A prism whose edge shifts teal, magenta, amber. Click for "Day N inside Area X" (uptime), the day's log entry and the controls; right click toggles the layer; middle click starts the screensaver. |

Everything is tied to the theme: switch to another theme and the extras go
dormant, and Omarchy's own screensaver is restored if this theme turned it off.

    extras/install status     # what is installed
    extras/install unlink     # remove everything, restore the stock screensaver

If the shell is not running when you link, run
`omarchy plugin enable annihilation.shimmer` after login. After editing the
plugin in the repo, run `omarchy-shell shell rescanPlugins`; the shell's file
watcher does not follow symlinks.

### Settings

Fields on the plugin's entry in `~/.config/omarchy/shell.json` (the bar glyph's
entry under `bar.layout`, or `plugins[]` if you run it without the glyph):

| Field | Default | |
| --- | --- | --- |
| `layerEnabled` | `true` | the wallpaper layer |
| `layerIntensity` | `0.35` | 0 to 1 |
| `layerSpeed` | `1` | how fast the Shimmer evolves, 0.1 to 4 times its natural pace (the popup's slider covers 0.25 to 3) |
| `windowGlow` | `true` | the light on window edges; `false` turns just that off |
| `windowGlowSpan` | `1` | in cursor mode, how much length of edge the pool covers, 0.5 to 2.5 times the default (also a slider in the popup) |
| `windowGlowDepth` | `1` | how far into a window the glow reaches, 0.5 to 2.5 times the default; the bright spot at the base of the cursor glow grows with it and with the span (also a slider in the popup) |
| `windowGlowMode` | `"all"` | `"all"`: every window glows evenly. `"cursor"`: only the active window, faintly, with the span of its edge nearest the pointer wider and brighter (also a toggle in the bar popup) |
| `layerAdditive` | `true` | add the light to the wallpaper; `false` blends it as an ordinary translucent layer if your compositor mishandles that |
| `motes` | `true` | the spores |
| `fpsCap` | `30` | 5 to 60 |
| `screensaver` | `true` | set `false` to keep Omarchy's idle behavior without it |
| `screensaverSeconds` | `0` | `0` follows `idle.screensaver` |
| `screensaverBrightness` | `0.08` | how much of the photo shows, 0.02 to 1 |
| `crawlSpeed` | `2.5` | type-sizes per second, 0.5 to 8 |
| `passageFont` | `"jost"` | `"jost"`, `"cinzel"`, or the name of any installed font |

### Commands

    omarchy-shell shimmer pulse          # a slow swell of intensity
    omarchy-shell shimmer toggleLayer
    omarchy-shell shimmer screensaver    # start it now; any key or click ends it
    omarchy-shell shimmer dismiss
    omarchy-shell shimmer status

### The screensaver passage

`passage.txt` ships original text in the manner of the tower wall writing. To
spell out something else, such as the passage from the book, put it in
`~/.config/omarchy/annihilation-passage.txt`, one part per line. That file
replaces the shipped one and is picked up as soon as you save it. Lines too
long for the screen are broken at word boundaries, preferably after
punctuation, so a pasted paragraph still reads in turn.

### Fonts

The film's logotype is custom and no free font matches it exactly. The passage
is set in thin, widely tracked capitals in Jost (a Futura-like geometric sans),
the nearest freely licensed look. `"cinzel"` gives classical Roman capitals
instead. Any other value is taken as the name of an installed font, so a
lookalike you install yourself, such as Kiona, works too. Jost and Cinzel are
bundled under the SIL Open Font License; the licences are in
`extras/plugin/annihilation.shimmer/fonts/`.

### Editing the shaders

`extras/plugin/annihilation.shimmer/shaders/*.frag` are compiled to the
committed `.qsb` files with `build-shaders.sh` (needs `qt6-shadertools`).
`journal.txt` holds the bar popup's daily entries, one per line.
