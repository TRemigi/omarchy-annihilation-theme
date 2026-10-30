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
| Shimmer layer | A click-through layer between wallpaper and windows: a slow band of thin-film colour, rising spores, faint caustics along the bottom. Pauses under fullscreen windows. |
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
