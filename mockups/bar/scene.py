#!/usr/bin/env python3
"""Membrane + optional layers drawn from the cell still. Every layer is a <g class="L-name"> the page can toggle."""
import math, random, sys, os
import geometry
from geometry import (CX, FONT, INK, TEAL, BRIGHT, MAG, AMBER, CONCEPTS, section, outline, place_items,
                 light_stops, pores, ico, CLOCK_LINES, b64, SCR)

LAYERS = ["rimcore", "spill", "globs", "glow", "spots", "nucleus", "iri"]

def pits(sec, hw0, seed):
    """soft dark pits in the side bands just inside the rim: mostly small, some medium, a few large (as in the still).
    Kept clear of the icon column; no two touch."""
    rnd = random.Random(seed * 31 + 5)
    placed, out = [], ""
    y = sec["y0"] + 6
    while y < sec["y1"] - 6:
        for side in (-1, 1):
            if rnd.random() > .78: continue
            u = rnd.random()
            r = rnd.uniform(.8, 1.5) if u < .66 else (rnd.uniform(1.7, 2.5) if u < .93 else rnd.uniform(2.7, 3.4))
            w = hw0(y + rnd.uniform(-2, 2))
            e = rnd.uniform(r + 1.0, r + 4.6)            # distance of the centre in from the rim
            x = CX + side * (w - e)
            if abs(x - CX) < 10.8 + r * .35 or w < 12: continue
            yy = y + rnd.uniform(-2.2, 2.2)
            if any((x - px) ** 2 + (yy - py) ** 2 < (r + pr + .9) ** 2 for px, py, pr in placed): continue
            placed.append((x, yy, r))
            out += f'<circle cx="{x:.1f}" cy="{yy:.1f}" r="{r:.2f}" fill="#031018" fill-opacity="{rnd.uniform(.55, .78):.2f}"/>'
            if r > 1.45:   # a lit lower lip, so the larger pits read as hollows
                out += f'<path d="M{x + r*.85:.1f} {yy + r*.5:.1f} A{r:.2f} {r:.2f} 0 0 1 {x - r*.2:.1f} {yy + r*.98:.1f}" fill="none" stroke="#C4F1F4" stroke-opacity=".34" stroke-width=".55"/>'
        y += rnd.uniform(2.6, 5.4)
    return out

def nucleus_cluster(seed=11):
    """the active workspace: a cluster of small coloured pits (deep magenta / very dark blue), big ones first."""
    rnd = random.Random(seed)
    cols = {"m": ("#6E2250", "#D9A2C4"), "M": ("#8E3668", "#E6B4D2"), "b": ("#15288A", "#7C96E6"), "B": ("#2038A6", "#9BB0F2"), "d": ("#050912", "#5A6E90")}
    spec = [(3.0, 3.9, 3), (1.8, 2.7, 5), (1.0, 1.7, 9)]
    BIG = "mbM"   # the three largest: magenta, blue, magenta
    blobs = []
    for lo, hi, n in spec:
        for _ in range(n):
            for _try in range(60):
                r = rnd.uniform(lo, hi)
                ang = rnd.uniform(0, 6.283); rad = rnd.uniform(0, 1) ** .7
                x, y = math.cos(ang) * 10.2 * rad, math.sin(ang) * 8.6 * rad
                if math.hypot(x / 10.2, y / 8.6) + r / 9.5 > 1.08: continue
                if any(math.hypot(x - px, y - py) < (r + pr) * .86 for px, py, pr, _ in blobs): continue
                k = (BIG[len(blobs)] if len(blobs) < 3 else rnd.choices("mMbBd", [.3, .08, .28, .12, .22])[0])
                blobs.append((x, y, r, k)); break
    out = ""
    for x, y, r, k in blobs:
        fill, lip = cols[k]
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{fill}" fill-opacity=".82"/>'
        if r >= 1.8 and k != "d":
            out += f'<circle cx="{x - r*.2:.1f}" cy="{y - r*.22:.1f}" r="{r*.6:.2f}" fill="#050912" fill-opacity=".55"/>'
            out += f'<path d="M{x + r*.86:.1f} {y + r*.5:.1f} A{r:.2f} {r:.2f} 0 0 1 {x - r*.2:.1f} {y + r*.98:.1f}" fill="none" stroke="{lip}" stroke-opacity=".3" stroke-width=".55"/>'
    return out

def smax(a, b, k=1.7):
    h = max(k - abs(a - b), 0) / k
    return max(a, b) + h * h * k / 4

def globby(sec, c, seed, hw0, gap=(5.5, 14)):
    """Globs all the way round: the approved outline is resampled by arc length and pushed out along its own normal.
    Round and slightly pointed bumps of mixed size, spaced unevenly, merged by a smooth max. Returns (path d, lights)."""
    tex = c["tex"]; ph = random.Random(seed * 7).uniform(0, 6.28)
    P1, P2 = tex.get("per", (31, 13.7)); u = tex["und"]
    y0, y1 = sec["y0"], sec["y1"]
    n = int((y1 - y0) / .3); N = 70
    ys = sorted(set([round(y0 + (y1 - y0) * k / n, 2) for k in range(n + 1)] +
                    [round(y0 + (y1 - y0) * (1 - math.cos(math.pi * k / N)) / 2, 2) for k in range(N + 1)]))
    R_pts, L_pts = [], []
    for y in ys:
        base = hw0(y)
        fade = min(1.0, base / 9) ** 2 if base > 0 else 0
        eR = u * (0.6 * math.sin(y / P1 * 6.283 + ph) + 0.4 * math.sin(y / P2 * 6.283 + 2 * ph))
        eL = u * (0.6 * math.sin(y / (P1 * .87) * 6.283 + 3 * ph) + 0.4 * math.sin(y / (P2 * 1.3) * 6.283 + ph))
        R_pts.append((CX + base + eR * fade, y)); L_pts.append((CX - base - eL * fade, y))
    poly = R_pts + L_pts[::-1]
    # resample by arc length
    cum = [0.0]
    for (x0, y0_), (x1, y1_) in zip(poly, poly[1:] + poly[:1]):
        cum.append(cum[-1] + math.hypot(x1 - x0, y1_ - y0_))
    per = cum[-1]; ds = .35; m = int(per / ds)
    pts, j = [], 0
    closed = poly + poly[:1]
    for k in range(m):
        sk = k * per / m
        while cum[j + 1] < sk: j += 1
        t = (sk - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
        pts.append((closed[j][0] + (closed[j + 1][0] - closed[j][0]) * t, closed[j][1] + (closed[j + 1][1] - closed[j][1]) * t))
    K = 4
    nrm = []
    for i in range(m):
        ax, ay = pts[(i - K) % m]; bx, by = pts[(i + K) % m]
        tx, ty = bx - ax, by - ay; l = math.hypot(tx, ty) or 1
        nrm.append((ty / l, -tx / l))            # outward for this winding (right side down, left side up)
    # globs along the perimeter
    rnd = random.Random(seed * 101 + 9)
    globs, s_ = [], rnd.uniform(2, 6)
    while s_ < per - 3:
        uu = rnd.random()
        rho = rnd.uniform(1.4, 2.1) if uu < .48 else (rnd.uniform(2.3, 3.2) if uu < .84 else rnd.uniform(3.5, 4.7))
        pr = rho * rnd.uniform(.6, .97)
        e = rnd.uniform(.5, .82)                  # .5 round ... .82 blunt and pointier
        globs.append((s_, rho, pr, e))
        s_ += rnd.uniform(2.2, 3.6) if rnd.random() < .2 else rnd.uniform(*gap)
    necks = [(b + a2) / 2 for (a_, b, r_), (a2, b2, r2) in zip(sec["lobes"], sec["lobes"][1:])]
    def clear(i):
        if not necks: return 1.0
        dn = min(abs(pts[i][1] - yj) for yj in necks) / 9.0
        return 0.0 if dn <= .35 else min(1.0, (dn - .35) / .65)
    D = [0.0] * m
    for (sb, rho, pr, e) in globs:
        i0, i1 = int((sb - rho) / ds), int((sb + rho) / ds) + 1
        for i in range(max(i0, 0), min(i1, m)):
            d_ = abs(i * ds - sb) * (per / (m * ds))
            if d_ < rho:
                D[i] = smax(D[i], pr * (1 - (d_ / rho) ** 2) ** e * clear(int(sb / ds) % m), 1.7)
    out = [(x + nx * D[i], y + ny * D[i]) for i, ((x, y), (nx, ny)) in enumerate(zip(pts, nrm))]
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in out) + " Z"
    lights = []
    for (sb, rho, pr, e) in globs:
        i = min(m - 1, int(sb / ds))
        (x, y), (nx, ny) = pts[i], nrm[i]
        lights.append((x + nx * pr * .75, y + ny * pr * .75, rho))
    return d, lights

def scene(pf, wall_ref, flags=None, alt=False, gap=(5.5, 14)):
    """flags=None: emit every layer (page toggles them with CSS). flags=set(...): static render of just those."""
    c = CONCEPTS["quiet"]
    def L(name, content, neg=False):
        if not content: return ""
        if flags is None: return f'<g class="L-{name}">{content}</g>'
        return content if ((name in flags) != neg) else ""

    secs = [("top", section(c["top"], c, "top", 10.0)),
            ("mid", section(c["mid"], c, "center", 600.0)),
            ("bot", section(c["bot"], c, "bottom", 1190.0))]
    defs, body = [], []
    defs.append(f'''
<linearGradient id="{pf}rim" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="1200">
  <stop offset="0" stop-color="{BRIGHT}"/><stop offset=".5" stop-color="{TEAL}"/><stop offset="1" stop-color="{BRIGHT}"/></linearGradient>
<linearGradient id="{pf}win" x1="0" y1="1" x2="1" y2="0">
  <stop offset="0" stop-color="#61a0a8"/><stop offset=".38" stop-color="#91506c"/><stop offset=".7" stop-color="#db930d"/><stop offset="1" stop-color="#7a7653"/></linearGradient>
<radialGradient id="{pf}cell" cx=".5" cy=".5" r=".75">
  <stop offset="0" stop-color="#2f4a52" stop-opacity="{c['inner']:.2f}"/><stop offset="1" stop-color="#0b1115" stop-opacity=".30"/></radialGradient>
<radialGradient id="{pf}hot"><stop offset="0" stop-color="#E4FAFC" stop-opacity="{c['neck_hot']}"/><stop offset=".45" stop-color="{BRIGHT}" stop-opacity="{c['neck_hot']*.55:.2f}"/><stop offset="1" stop-color="{TEAL}" stop-opacity="0"/></radialGradient>
<radialGradient id="{pf}nucg"><stop offset=".5" stop-color="#B06C8A" stop-opacity=".55"/><stop offset="1" stop-color="{TEAL}" stop-opacity="0"/></radialGradient>
<radialGradient id="{pf}nuc"><stop offset="0" stop-color="#140f14" stop-opacity=".62"/><stop offset=".42" stop-color="#140f14" stop-opacity=".4"/><stop offset=".62" stop-color="#9A3F78" stop-opacity=".8"/><stop offset=".82" stop-color="#5E86B0" stop-opacity=".85"/><stop offset="1" stop-color="#9FA84C" stop-opacity=".8"/></radialGradient>
<radialGradient id="{pf}iM"><stop offset="0" stop-color="#8A2D5E" stop-opacity=".62"/><stop offset="1" stop-color="#8A2D5E" stop-opacity="0"/></radialGradient>
<radialGradient id="{pf}iA"><stop offset="0" stop-color="#12206A" stop-opacity=".7"/><stop offset="1" stop-color="#12206A" stop-opacity="0"/></radialGradient>
<radialGradient id="{pf}iT"><stop offset="0" stop-color="{BRIGHT}" stop-opacity=".32"/><stop offset="1" stop-color="{TEAL}" stop-opacity="0"/></radialGradient>
<filter id="{pf}g1" x="-60%" y="-35%" width="220%" height="170%"><feGaussianBlur stdDeviation="{c['glow']}"/></filter>
<filter id="{pf}g2" x="-80%" y="-35%" width="260%" height="170%"><feGaussianBlur stdDeviation="3.2"/></filter>
<radialGradient id="{pf}body" cx=".5" cy=".5" r=".72"><stop offset="0" stop-color="#1f6f7c" stop-opacity="0"/><stop offset=".5" stop-color="#1f7f8c" stop-opacity=".05"/><stop offset=".82" stop-color="#2a9fb0" stop-opacity=".2"/><stop offset="1" stop-color="#3fb8c8" stop-opacity=".32"/></radialGradient>
<filter id="{pf}gi" x="-300%" y="-35%" width="700%" height="170%"><feGaussianBlur stdDeviation="6"/></filter>
<filter id="{pf}nb" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation=".75"/></filter>
<filter id="{pf}spb" x="-20%" y="-5%" width="140%" height="110%"><feGaussianBlur stdDeviation=".5"/></filter>
<filter id="{pf}fs" x="-200%" y="-35%" width="500%" height="170%"><feGaussianBlur stdDeviation=".8"/></filter>
<filter id="{pf}fs2" x="-200%" y="-35%" width="500%" height="170%"><feGaussianBlur stdDeviation="1.05"/></filter>
<filter id="{pf}g3" x="-120%" y="-35%" width="340%" height="170%"><feGaussianBlur stdDeviation="2"/></filter>
<filter id="{pf}sp" x="-200%" y="-35%" width="500%" height="170%"><feGaussianBlur stdDeviation="8"/></filter>
<filter id="{pf}ws" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="14"/></filter>
<filter id="{pf}sh" x="-80%" y="-35%" width="260%" height="170%"><feGaussianBlur stdDeviation="3.5"/></filter>''')
    body.append(f'''<g>
<rect x="820" y="150" width="1000" height="900" rx="4" fill="#150f13" fill-opacity=".94"/>
<rect x="821" y="151" width="998" height="898" rx="3.5" fill="none" stroke="url(#{pf}win)" stroke-width="2" stroke-opacity=".95"/>
<g font-family="{FONT}" font-size="15" fill="{INK}" fill-opacity=".8">
<text x="852" y="194" fill="{TEAL}">~/dev/omarchy-annihilation-theme</text><text x="1180" y="194" fill="{MAG}" fill-opacity=".9">main</text>
<text x="852" y="232">&gt; omarchy bar position left</text>
<text x="852" y="262">&gt; omarchy-shell shimmer status</text>
<text x="852" y="292" fill-opacity=".55">  shimmer on   intensity 0.44   glow 1.98</text>
<text x="852" y="322">&gt; hyprctl configerrors</text>
<text x="852" y="352" fill-opacity=".55">  (none)</text>
<text x="852" y="382">&gt; <tspan fill="{BRIGHT}">█</tspan></text></g></g>''')

    for si, (nm, sec) in enumerate(secs):
        d, hw0, beads = outline(sec, c, seed=si + 2)
        i = f"{pf}{nm}"
        U = lambda extra: f'<use href="#{i}p" {extra}/>'
        d1, glights = globby(sec, c, si + 2, hw0, gap) if (alt or (flags is not None and "globs" in flags)) else (None, [])
        if flags is not None and "globs" in flags: d = d1
        defs.append(f'<path id="{i}p" d="{d}"' + (f' data-d1="{d1}"' if (alt and flags is None) else '') + '/>')
        defs.append(f'<clipPath id="{i}c"><use href="#{i}p"/></clipPath>')
        defs.append(f'<linearGradient id="{i}hl" gradientUnits="userSpaceOnUse" x1="0" y1="{sec["y0"]:.1f}" x2="0" y2="{sec["y1"]:.1f}">{light_stops(sec, si + 2, *c["hl"])}</linearGradient>')

        body.append(U('fill="#000" fill-opacity=".55" transform="translate(0 2.5)" filter="url(#%ssh)"' % pf))
        body.append(L("spill", U(f'fill="none" stroke="url(#{i}hl)" stroke-width="13" stroke-opacity=".42" filter="url(#{pf}sp)"')
                      + U(f'fill="none" stroke="{TEAL}" stroke-width="9" stroke-opacity=".10" filter="url(#{pf}sp)"')))

        # inside the cell
        inner = [f'<use class="wallb" href="{wall_ref[1]}" width="1920" height="1200" filter="url(#{pf}ws)"/>',
                 U(f'fill="#1A1518" fill-opacity="{c["tint"]}"'),
                 U(f'fill="url(#{pf}cell)"'),
                 U(f'fill="none" stroke="{TEAL}" stroke-width="7" stroke-opacity="{c["inner"]*1.6:.2f}" filter="url(#{pf}g2)"')]
        # interior glow: the body lifts toward the rim, as the cell in the still does
        inner.append(L("glow", U(f'fill="url(#{pf}body)"')
                       + U(f'fill="none" stroke="#2AA9BC" stroke-width="15" stroke-opacity=".3" filter="url(#{pf}gi)"')
                       + U(f'fill="none" stroke="#8FE6EE" stroke-width="6" stroke-opacity=".13" filter="url(#{pf}g2)"')))
        inner.append(L("spots", f'<g filter="url(#{pf}spb)">{pits(sec, hw0, si + 2)}</g>'))
        # shimmer core behind the clock and the Area X glyph
        iri = ""
        for (a, b, r), g in zip(sec["lobes"], sec["groups"]):
            if "clock" in g or "areax" in g:
                cy = (a + b) / 2; h = b - a
                iri += (f'<ellipse cx="{CX-3}" cy="{cy:.1f}" rx="16" ry="{h*.55:.1f}" fill="url(#{pf}iM)"/>'
                        f'<ellipse cx="{CX+6}" cy="{cy+h*.14:.1f}" rx="13" ry="{h*.4:.1f}" fill="url(#{pf}iA)"/>')
        inner.append(L("iri", iri))
        inner.append(U(f'fill="none" stroke="#070b0e" stroke-width="{c["shoulder"]}" stroke-opacity=".42" filter="url(#{pf}fs)"'))
        body.append(f'<g clip-path="url(#{i}c)">{"".join(inner)}</g>')

        # rim: the approved one, or the lit one
        base = (U(f'fill="none" stroke="{TEAL}" stroke-width="3.4" stroke-opacity="{c["glow_op"]}" filter="url(#{pf}g1)"')
                + U(f'fill="none" stroke="url(#{pf}rim)" stroke-width="{c["rim"]}" stroke-opacity="{c["rim_op"]}" stroke-linejoin="round"')
                + U(f'fill="none" stroke="url(#{i}hl)" stroke-width="{c["hl_w"]}" stroke-linejoin="round"')
                + U(f'fill="none" stroke="url(#{i}hl)" stroke-width="3" stroke-opacity=".35" filter="url(#{pf}g1)"'))
        lit = (U(f'fill="none" stroke="{TEAL}" stroke-width="3.4" stroke-opacity=".36" filter="url(#{pf}g2)"')
               + U(f'fill="none" stroke="url(#{i}hl)" stroke-width="6" stroke-opacity=".5" filter="url(#{pf}g2)"')
               + U(f'fill="none" stroke="{BRIGHT}" stroke-width="2" stroke-opacity=".42" filter="url(#{pf}fs2)"')
               + U(f'fill="none" stroke="url(#{i}hl)" stroke-width="1.5" stroke-opacity=".8" filter="url(#{pf}fs2)"'))
        if flags is None:
            body.append(f'<g class="L-rimbase">{base}</g>' + L("rimcore", lit))
        else:
            body.append(lit if "rimcore" in flags else base)

        gl = ""
        grnd = random.Random(si + 70)
        for (tx, ty, rho) in glights:
            if rho >= 2.3 or grnd.random() < .3:
                gl += f'<circle cx="{tx:.1f}" cy="{ty:.1f}" r="{rho*2.3:.1f}" fill="url(#{pf}hot)" opacity="{grnd.uniform(.35, .75):.2f}"/>'
        body.append(L("globs", gl))
        for (a, b, r), (a2, b2, r2) in zip(sec["lobes"], sec["lobes"][1:]):
            yj = (b + a2) / 2; w = hw0(yj)
            body.append(f'<ellipse cx="{CX}" cy="{yj:.1f}" rx="{w+7:.1f}" ry="7" fill="url(#{pf}hot)"/>')

        wsn = 0
        for it, x, y in place_items(sec):
            if it == "ws":
                wsn += 1
                if wsn == 2:
                    # no outline: the active workspace is marked by light, an uneven soft glow behind the number
                    ring = (f'<g transform="translate({x:.1f} {y:.1f})" filter="url(#{pf}g3)">'
                            f'<ellipse cx="-.5" cy=".6" rx="9.5" ry="8.2" fill="{TEAL}" fill-opacity=".5"/>'
                            f'<ellipse cx="2" cy="-1" rx="6.5" ry="6" fill="{BRIGHT}" fill-opacity=".28"/></g>')
                    nuc = (f'<g transform="translate({x:.1f} {y:.1f})">'
                           f'<ellipse rx="11" ry="9.5" fill="#6E2250" fill-opacity=".34" filter="url(#{pf}g3)"/>'
                           f'<g filter="url(#{pf}nb)">{nucleus_cluster()}</g></g>')
                    if flags is None:
                        body.append(f'<g class="L-wsbase">{ring}</g>' + L("nucleus", nuc))
                    else:
                        body.append(nuc if "nucleus" in flags else ring)
                    body.append(f'<g transform="translate({x:.1f} {y:.1f})"><text y="4.4" text-anchor="middle" font-family="{FONT}" font-size="12.5" font-weight="500" fill="#F1E9D0" '
                                f'paint-order="stroke" stroke="#130f12" stroke-opacity=".32" stroke-width="1.7" stroke-linejoin="round">2</text></g>')
                else:
                    body.append(ico("ws", x, y, active=False, label=str(wsn)))
            elif it == "clock":
                body.append(ico("clock", x, y, label=CLOCK_LINES))
            else:
                body.append(ico(it, x, y))
    return f'<defs>{"".join(defs)}</defs>' + f'<use class="wall" href="{wall_ref[0]}" width="1920" height="1200"/>' + "".join(body)

if __name__ == "__main__":
    flags = set(sys.argv[1].split(",")) if len(sys.argv) > 1 and sys.argv[1] != "-" else set()
    w = sys.argv[2] if len(sys.argv) > 2 else "w3"
    vb = sys.argv[3] if len(sys.argv) > 3 else "0 0 150 270"
    out = sys.argv[4] if len(sys.argv) > 4 else f"{SCR}/g2.svg"
    inner = scene("x-", ("#wi", "#wb"), flags)
    vw, vh = [float(v) for v in vb.split()[2:]]
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{int(vw*700/vh)}" height="700">'
           f'<defs><image id="wi" width="1920" height="1200" href="data:image/jpeg;base64,{b64(f"{SCR}/img/{w}.jpg")}" preserveAspectRatio="none"/>'
           f'<image id="wb" width="1920" height="1200" href="data:image/jpeg;base64,{b64(f"{SCR}/img/{w}-b.jpg")}" preserveAspectRatio="none"/></defs>{inner}</svg>')
    open(out, "w").write(svg); print(out, len(svg))
