# Cell bar mockups

Design-stage mockups for a custom Omarchy bar: floating, rounded sections shaped after the blue cell
division still (`backgrounds/annihilation-119.jpg`). **Nothing here is implemented in the shell yet.**

```
./prep-images.sh      wallpaper backdrops + the reference still -> img/ (ImageMagick)
python3 build.py      -> page.html, one self-contained page (view it, or publish it as an artifact)
geometry.py           section outlines (lobes joined by a smooth union), icons, palette, parameters
scene.py              the scene: window stand-in, three sections, every optional layer, and `state` (hover, buds, tints)
states.py             the hover and alert states, one close-up each
template.html         the page: ingredient switches, approved-vs-yours comparison, wallpaper/view controls
```

The build is deterministic (fixed seeds), so the same sources give a byte-identical page.
`python3 scene.py <layers|-> <w1|w2|w3> "<viewBox>" out.svg` renders a static SVG of chosen layers
(`rsvg-convert` turns it into a PNG); that is how shapes were checked, since this sandbox has no
compositor and no browser.

## Where the design stands

Drawn for the bar on the **left** (as `shell.json` has it), 1920x1200, sections 36px wide.
Three sections: menu + workspaces + Area X glyph, clock + weather, status icons. Each is one cell with a
waist wherever the content changes group. Of three directions tried (Waist, Mitosis, Membrane) Membrane
was chosen: a clean silhouette with a slow swell, the organic quality carried by light and texture.

Layers. **The full set was chosen** (the page's Calm and Approved presets are the lighter alternatives that were
rejected; `template.html` still has the switches):

| Layer | From the still |
| --- | --- |
| Lit rim | thin, feathered band of light, brighter in some places than others |
| Light spill | glow bleeding onto the wallpaper, stronger where the rim is brighter |
| Edge globs | lumpy rim, nodules of mixed size round the whole perimeter, cleared at the necks |
| Inner glow | body lit from the rim inward, dark centre so icons keep contrast |
| Dark pits | soft pits in a ring inside the rim, about 25 to 40 per section |
| Nucleus | active workspace: a cluster of pits, deep magenta + very dark blue, no outline |
| Shimmer core | the same two colours, faint, behind the clock and the Area X glyph |

Tried and dropped, so nobody repeats it:

- a regular scalloped edge (stamped, cheap), then a wobbly outline, tiny beads and large blebs (glitchy);
- pits on a dark interior (they read as dirt; they work once the inner glow lights the body);
- spindle fibres fanning from each neck (they cut through the icons);
- a hard circle around the active workspace, and a rainbow of colours behind it (deep magenta and very dark
  blue only);
- crisp rim strokes (they read as a line; the rim is blurred bands now).

Not done: spikes, bulbs that overhang the edge (the outline is built by pushing a resampled path along its
normals, which cannot overhang), a top or bottom bar (the geometry would be transposed), the bar hidden or
auto-peeking, and a notification toast arriving.

## States

Drawn in `states.py`, each as a close-up of the section where it happens. **Approved as drawn, colours included**
(magenta for attention, red for critical):

- **Hover** on a status icon or a workspace: light pools behind it and it brightens; the tooltip is the shell's own
  card (`[tooltip]` colours).
- **Hover on the bar**: the stock bar shows inactive indicators (do-not-disturb, night light, recording, stay awake) at
  45%. Here they appear as a lobe budding off the clock cell.
- **Unseen notifications**: the Area X glyph is drawn the way the plugin draws it (`BarWidget.qml`: filled prism, one to
  three 3px motes, an amber spore). The cell's rim warms to the shell's attention colour.
- **Attention** (recording, update available): the indicator's cell stays as a solid bud with a magenta rim.
- **Critical** (low battery): the same, in red, on that cell only. Red is deliberately apart from the magenta.

The rest-state Area X glyph elsewhere on the page has refraction rays the plugin does not draw; icons on the page are
placeholders.

## Building it for real

- The shell takes a replacement bar as a plugin with `kind: "bar"`. Stock `omarchy.bar` paints one rectangle
  behind the whole strip (`Bar.qml`, in `BarPanel`) and lays the sections inside it, so the replacement is a
  fork of that file with one shaped background per section. The cost is following upstream bar changes.
- Outlines are polygons of about 1,500 points per section, regenerated when a section resizes, from fixed
  seeds so the globs and pits do not reshuffle.
- The rim bloom and spill extend about 25px past each section; the bar window already spans the screen.
- A shaped bar needs a layer rule on `omarchy-bar` with `ignore_alpha` so Hyprland's blur follows the outlines.
- Unmeasured: the cost of the blurs in Quickshell.
