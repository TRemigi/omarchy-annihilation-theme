import geometry as gen, scene as gen2, states as states_mod
SCR = gen.SCR
def img(n): return f'data:image/jpeg;base64,{gen.b64(f"{SCR}/img/{n}.jpg")}'
defs = ""
for i, w in enumerate(["w1", "w2", "w3"], 1):
    defs += f'<image id="wi-{i}" width="1920" height="1200" preserveAspectRatio="none" href="{img(w)}"/>'
    defs += f'<image id="wb-{i}" width="1920" height="1200" preserveAspectRatio="none" href="{img(w+"-b")}"/>'
ref = ("#wi-1", "#wb-1")
figs = (f'<figure class="panel base"><svg class="scene" viewBox="0 0 1920 1200" role="img" aria-label="Approved Membrane bar mockup">{gen2.scene("b-", ref)}</svg>'
        f'<figcaption><strong>Approved Membrane</strong><span>Where we left it, minus the ring around the active workspace.</span></figcaption></figure>'
        f'<figure class="panel mine on"><svg class="scene f-rimcore f-spill f-globs f-glow f-spots f-nucleus f-iri" id="mine" viewBox="0 0 1920 1200" role="img" aria-label="Membrane with the chosen layers">{gen2.scene("c-", ref, alt=True)}</svg>'
        f'<figcaption><strong>With your layers</strong><span id="mineNote">Everything on.</span></figcaption></figure>')
cards = ""
for n, s in enumerate(states_mod.STATES, 1):
    cards += (f'<figure class="panel"><svg class="scene" viewBox="{s["view"]}" role="img" aria-label="{s["title"]}">'
              f'{gen2.scene(f"s{n}-", ref, set(gen2.LAYERS), state=s["state"])}</svg>'
              f'<figcaption><strong>{s["title"]}</strong><span>{s["blurb"]}</span></figcaption></figure>')
html = open(f"{SCR}/template.html").read()
html = html.replace("{{DEFS}}", defs).replace("{{STATES}}", cards).replace("{{FIGS}}", figs).replace("{{REF}}", img("ref119"))
open(f"{SCR}/page.html", "w").write(html); print(len(html))
