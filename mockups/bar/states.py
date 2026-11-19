"""Hover and alert states, each a close-up of the section it happens in (see scene.scene's `state`)."""
BUDS = lambda lobes: dict(lobes=lobes, neck=13.0)

STATES = [
    dict(id="hover-icon", view="0 930 230 270", title="Hover on a status icon",
         blurb="Light pools behind the icon and it brightens. The tooltip is the shell's own, in the theme's card colours.",
         state=dict(only=("bot",), window=False, hover="audio", tooltip=("Volume 62%", "audio"))),
    dict(id="hover-ws", view="0 0 230 270", title="Hover on a workspace",
         blurb="The same pooled light, so it never competes with the active workspace's coloured cluster.",
         state=dict(only=("top",), window=False, hover=("ws", 4))),
    dict(id="hover-bar", view="0 400 230 280", title="Hover on the bar",
         blurb="Resting indicators are hidden. Hovering the bar reveals them at 45%: a daughter cell buds off the clock cell.",
         state=dict(only=("mid",), window=False, specs=dict(mid=BUDS([["dnd", "night", "rec", "awake"], ["clock"], ["weather"]])),
                    dim={"dnd", "night", "rec", "awake"})),
    dict(id="missed", view="0 0 230 270", title="Unseen notifications",
         blurb="Area X's own signal, drawn as the plugin does it: the prism fills in and up to three motes appear. The cell's rim warms to magenta.",
         state=dict(only=("top",), window=False, motes=3, tint={("top", 2): "attn"}, hover="areax", tooltip=("Area X · 3 unseen", "areax"))),
    dict(id="attention", view="0 450 230 280", title="Recording and an update",
         blurb="An active indicator keeps its bud, solid, and its rim takes the shell's attention colour. Updates bud below the weather the same way.",
         state=dict(only=("mid",), window=False, specs=dict(mid=BUDS([["rec"], ["clock"], ["weather"], ["update"]])),
                    tint={("mid", 0): "attn", ("mid", 3): "attn"}, ink={"rec": "#F6D2E4", "update": "#F6D2E4"},
                    hover="rec", tooltip=("Stop recording", "rec"))),
    dict(id="critical", view="0 930 230 270", title="Critical: low battery",
         blurb="Crimson instead of magenta, on that cell only. The rest of the bar stays calm.",
         state=dict(only=("bot",), window=False, tint={("bot", 2): "crit"}, low="power", hover="power", tooltip=("Battery 8%", "power"))),
]
