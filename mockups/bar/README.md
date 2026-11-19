# Cell bar mockups

Design-stage mockups for a custom Omarchy bar: floating, rounded sections shaped after the blue cell
division still (`backgrounds/annihilation-119.jpg`). **Nothing here is implemented in the shell yet.**

```
./prep-images.sh      wallpaper backdrops + the reference still -> img/ (ImageMagick)
python3 build.py      -> page.html, one self-contained page (view it, or publish it as an artifact)
geometry.py           section outlines (lobes joined by a smooth union), icons, palette, parameters
scene.py              the scene: window stand-in, three sections, and every optional layer
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

Layers, all on by default (`template.html` has the switches and presets):

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
normals, which cannot overhang), a top or bottom bar (the geometry would be transposed), hover and alert states.

## Building it for real

- The shell takes a replacement bar as a plugin with `kind: "bar"`. Stock `omarchy.bar` paints one rectangle
  behind the whole strip (`Bar.qml`, in `BarPanel`) and lays the sections inside it, so the replacement is a
  fork of that file with one shaped background per section. The cost is following upstream bar changes.
- Outlines are polygons of about 1,500 points per section, regenerated when a section resizes, from fixed
  seeds so the globs and pits do not reshuffle.
- The rim bloom and spill extend about 25px past each section; the bar window already spans the screen.
- A shaped bar needs a layer rule on `omarchy-bar` with `ignore_alpha` so Hyprland's blur follows the outlines.
- Unmeasured: the cost of the blurs in Quickshell.
