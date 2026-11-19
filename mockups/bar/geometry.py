#!/usr/bin/env python3
"""Cell-bar geometry: section outlines from a lobe profile (smooth union of squircles), icons, helpers.
The live scene is scene.py; CONCEPTS["quiet"] is the Membrane parameter set it uses."""
import math, base64, sys, os

SCR = os.path.dirname(os.path.abspath(__file__))
CX, R = 28.0, 18.0          # bar column centre x, half-width (36px sections, 10px from the screen edge)
H = 1200
INK, DIM = "#D2C3A4", "#D2C3A4"
TEAL, BRIGHT, MAG, AMBER = "#61A0A8", "#84BDC4", "#91506C", "#DB930D"
FONT = "'IBM Plex Mono','CaskaydiaMono Nerd Font','DejaVu Sans Mono',monospace"

# ---------- profile ----------------------------------------------------------
def squircle(u, p):
    u = abs(u)
    return 0.0 if u >= 1 else (1 - u ** p) ** (1 / p)

def make_hw(lobes, ov, p, q=3.0, R_=R):
    """half-width function of y for lobes [(a,b,R)], smooth-unioned (p-norm)."""
    def hw(y):
        s = 0.0
        for a, b, r in lobes:
            c, h = (a + b) / 2, (b - a) / 2
            s += (r * squircle((y - c) / h, p)) ** q
        return s ** (1 / q)
    return hw

def layout(heights, ov, y0, rs=None):
    rs = rs or [R] * len(heights)
    lobes, y = [], y0
    for h, r in zip(heights, rs):
        lobes.append((y, y + h, r))
        y += h - ov
    return lobes

def solve_ov(heights, neck, p, q=3.0, rs=None):
    """overlap so that the first junction's half-width equals `neck`."""
    rs = rs or [R] * len(heights)
    if len(heights) < 2:
        return 0.0
    lo, hi = 0.0, min(heights[:2]) * 0.9
    for _ in range(50):
        ov = (lo + hi) / 2
        lobes = layout(heights[:2], ov, 0, rs[:2])
        yj = lobes[0][1] - ov / 2
        w = make_hw(lobes, ov, p, q)(yj)
        if w < neck: lo = ov
        else: hi = ov
    return (lo + hi) / 2

# ---------- icons (centred on 0,0, ~14px box) -------------------------------
def ico(name, x, y, active=False, label=""):
    g = f'<g transform="translate({x:.1f} {y:.1f})" fill="none" stroke="{INK}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round">'
    if name == "menu":
        g += f'<circle r="6" /><circle r="1.9" fill="{TEAL}" stroke="none"/>'
    elif name == "areax":
        g += (f'<path d="M0 -6 L6 5 L-6 5 Z"/>'
              f'<path d="M-8.6 -0.5 L-2.6 1" stroke="{BRIGHT}"/>'
              f'<path d="M3 0.4 L8.6 -3" stroke="{TEAL}"/><path d="M3.4 1.8 L8.8 1.6" stroke="{MAG}" stroke-width="1.5"/>'
              f'<path d="M3.2 3.2 L8.6 6" stroke="{AMBER}"/>')
    elif name == "ws":
        if active:
            g += f'<circle r="10" fill="{TEAL}" fill-opacity=".22" stroke="{BRIGHT}" stroke-opacity=".9" stroke-width="1"/>'
        col = "#F1E9D0" if active else INK
        op = 1 if active else (.85 if label in "13" else .42)
        g += f'<text y="4.2" text-anchor="middle" font-family="{FONT}" font-size="12.5" font-weight="500" fill="{col}" fill-opacity="{op}" stroke="none">{label}</text>'
    elif name == "tray":
        g += '<path d="M-3.5 -2 L0 2 L3.5 -2"/>'
    elif name == "kb":
        g += f'<text y="3.6" text-anchor="middle" font-family="{FONT}" font-size="10" fill="{INK}" stroke="none">US</text>'
    elif name == "agents":
        g += ''.join(f'<path d="M0 0 L{6*math.cos(a):.2f} {6*math.sin(a):.2f}"/>' for a in [i*math.pi/3 + math.pi/6 for i in range(6)])
    elif name == "bt":
        g += '<path d="M-3.6 -3.6 L3.6 3.4 L0 6.6 L0 -6.6 L3.6 -3.4 L-3.6 3.6"/>'
    elif name == "net":
        for r in (3.2, 6.4, 9.6):
            dx, dy = r * math.sin(math.radians(40)), 4.5 - r * math.cos(math.radians(40))
            g += f'<path d="M{-dx:.2f} {dy:.2f} A{r} {r} 0 0 1 {dx:.2f} {dy:.2f}"/>'
        g += f'<circle cy="4.5" r="1" fill="{INK}"/>'
    elif name == "audio":
        g += '<path d="M-6.5 -2.4 H-3.4 L0.8 -6 V6 L-3.4 2.4 H-6.5 Z"/><path d="M3.2 -3 A4.2 4.2 0 0 1 3.2 3"/><path d="M5.6 -5 A7.4 7.4 0 0 1 5.6 5"/>'
    elif name == "mon":
        g += '<rect x="-6.5" y="-5" width="13" height="8.5" rx="1.4"/><path d="M-3 6.2 H3 M0 3.5 V6.2"/>'
    elif name == "power":
        g += (f'<rect x="-4" y="-5.5" width="8" height="12.5" rx="1.8"/><path d="M-1.6 -7.6 H1.6" stroke-width="1.6"/>'
              f'<rect x="-2.4" y="0" width="4.8" height="5.2" rx=".8" fill="{TEAL}" stroke="none"/>')
    elif name == "weather":
        g += ''.join(f'<path d="M{5.2*math.cos(a):.2f} {5.2*math.sin(a):.2f} L{7.4*math.cos(a):.2f} {7.4*math.sin(a):.2f}"/>' for a in [i*math.pi/4 for i in range(8)])
        g += '<circle r="3"/>'
    elif name == "clock":
        for i, t in enumerate(label):
            ty = -22.5 + i * 15
            fs = 13 if t not in ("—",) else 12
            g += f'<text y="{ty+4.4:.1f}" text-anchor="middle" font-family="{FONT}" font-size="{fs}" font-weight="500" fill="#EBE0BB" stroke="none" fill-opacity="{.5 if t == chr(8212) else 1}">{t}</text>'
    return g + '</g>'

# item heights (vertical room each takes)
IH = {"menu": 26, "ws": 24, "areax": 28, "tray": 26, "kb": 26, "agents": 26, "bt": 26, "net": 26,
      "audio": 26, "mon": 26, "power": 26, "weather": 26, "clock": 60}
PAD = 18

def lobe_height(items, end=0):
    return sum(IH[i] for i in items) + PAD + (end if len(items) > 1 else 0)

# ---------- concepts ---------------------------------------------------------
WS = ["ws"] * 5
CONCEPTS = {
    "waist": dict(
        name="Waist", p=2.6, q=3.0,
        top=dict(lobes=[["menu"], WS, ["areax"]], neck=12.5),
        mid=dict(lobes=[["clock"], ["weather"]], neck=12.5),
        bot=dict(lobes=[["tray", "kb", "agents"], ["bt", "net", "audio", "mon"], ["power"]], neck=12.5),
        rim=1.15, rim_op=.85, glow=2.2, glow_op=.32, inner=.16, neck_hot=.22, pores=False, 
        tint=.70),
    "mitosis": dict(
        name="Mitosis", p=2.1, q=3.0,
        top=dict(lobes=[["menu"], WS + ["areax"]], neck=3.0),
        mid=dict(lobes=[["clock"], ["weather"]], neck=8.5),
        bot=dict(lobes=[["tray", "kb", "agents", "bt", "net", "audio", "mon"], ["power"]], neck=14.0),
        rim=1.4, rim_op=1.0, glow=3.4, glow_op=.62, inner=.30, neck_hot=.80, pores=True, 
        tint=.66),
    "quiet": dict(
        name="Membrane (soft)", p=2.5, q=3.0,
        top=dict(lobes=[["menu"], WS, ["areax"]], neck=13.0),
        mid=dict(lobes=[["clock"], ["weather"]], neck=13.0),
        bot=dict(lobes=[["tray", "kb", "agents"], ["bt", "net", "audio", "mon"], ["power"]], neck=13.0),
        rim=1.0, rim_op=.5, glow=2.4, glow_op=.28, inner=.22, neck_hot=.40, pores=False, tint=.70, shoulder=5,
        tex=dict(und=1.25, per=(96, 57), beads=False), hl=(.0, .95), hl_w=1.3),
    "beaded": dict(
        name="Membrane (blebbed)", p=2.5, q=3.0,
        top=dict(lobes=[["menu"], WS, ["areax"]], neck=13.0),
        mid=dict(lobes=[["clock"], ["weather"]], neck=13.0),
        bot=dict(lobes=[["tray", "kb", "agents"], ["bt", "net", "audio", "mon"], ["power"]], neck=13.0),
        rim=1.0, rim_op=.5, glow=2.4, glow_op=.28, inner=.22, neck_hot=.40, pores=False, tint=.70, shoulder=5,
        tex=dict(und=1.0, per=(96, 57), beads=True, outer=.85, h=(2.2, 3.2), rho=(8, 11), gap=(48, 90)), hl=(.0, .95), hl_w=1.3),
}

def section(spec, c, anchor, value):
    """Return dict with geometry. anchor: 'top' y0=value | 'bottom' y1=value | 'center' cy=value"""
    groups = spec["lobes"]
    n = len(groups)
    hs = [lobe_height(g, 0) for g in groups]
    # a multi-item lobe at either end of a section needs extra room under its rounded cap
    ends = [(10 if (i == 0 or i == n - 1) and len(g) > 1 else 0) for i, g in enumerate(groups)]
    hs = [h + e for h, e in zip(hs, ends)]
    ov = solve_ov(hs, spec["neck"], c["p"], c["q"]) if len(hs) > 1 else 0
    total = sum(hs) - ov * (len(hs) - 1)
    y0 = value if anchor == "top" else (value - total if anchor == "bottom" else value - total / 2)
    lobes = layout(hs, ov, y0)
    return dict(groups=groups, lobes=lobes, ov=ov, y0=y0, y1=y0 + total)

import random

def make_beads(sec, tex, seed):
    """sparse, irregular round beads: mostly on the outer (right) edge, varied size, uneven spacing."""
    rnd = random.Random(seed)
    beads, y = [], sec["y0"] + rnd.uniform(14, 26)
    while y < sec["y1"] - 14:
        side = 1 if rnd.random() < tex["outer"] else -1
        h = rnd.uniform(*tex["h"]); rho = rnd.uniform(*tex["rho"])
        beads.append((y, side, h, rho))
        y += rnd.uniform(*tex["gap"])
    return beads

def outline(sec, c, seed=1):
    lobes = sec["lobes"]
    hw0 = make_hw(lobes, sec["ov"], c["p"], c["q"])
    y0, y1 = sec["y0"], sec["y1"]
    tex = c.get("tex")
    beads = make_beads(sec, tex, seed) if tex and tex.get("beads") else []
    ph = random.Random(seed * 7).uniform(0, 6.28)
    n = int((y1 - y0) / 0.6)
    R_pts, L_pts = [], []
    for k in range(n + 1):
        y = y0 + (y1 - y0) * (1 - math.cos(math.pi * k / n)) / 2
        base = hw0(y)
        fade = min(1.0, base / 9) ** 2 if base > 0 else 0
        eR = eL = 0.0
        if tex:
            u = tex["und"]   # slow swell: two incommensurate long waves, different on each side
            P1, P2 = tex.get("per", (31, 13.7))
            eR += u * (0.6 * math.sin(y / P1 * 6.283 + ph) + 0.4 * math.sin(y / P2 * 6.283 + 2 * ph))
            eL += u * (0.6 * math.sin(y / (P1 * .87) * 6.283 + 3 * ph) + 0.4 * math.sin(y / (P2 * 1.3) * 6.283 + ph))
            for (by, side, h, rho) in beads:
                d = abs(y - by)
                if d < rho:
                    b = h * math.cos(math.pi * d / (2 * rho)) ** 2
                    if side > 0: eR += b
                    else: eL += b
        R_pts.append((CX + base + eR * fade, y)); L_pts.append((CX - base - eL * fade, y))
    pts = R_pts + L_pts[::-1]
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"
    return d, hw0, beads

def light_stops(sec, seed, lo, hi):
    """uneven light along the rim: stop opacities from a seeded random walk, smoothed."""
    rnd = random.Random(seed * 13)
    h = sec["y1"] - sec["y0"]; n = max(4, int(h / 16))
    v, vals = rnd.random(), []
    for _ in range(n + 1):
        v = max(0, min(1, v + rnd.uniform(-.55, .55)))
        vals.append(lo + (hi - lo) * v)
    return "".join(f'<stop offset="{k/n:.3f}" stop-color="#C9F1F5" stop-opacity="{a:.2f}"/>' for k, a in enumerate(vals))

def place_items(sec):
    out = []
    n = len(sec["groups"])
    for k, ((a, b, r), g) in enumerate(zip(sec["lobes"], sec["groups"])):
        c = (a + b) / 2
        if len(g) > 1 and n > 1:   # the end padding is one-sided: slide content away from the cap
            c += 5 if k == 0 else (-5 if k == n - 1 else 0)
        total = sum(IH[i] for i in g)
        y = c - total / 2
        for it in g:
            out.append((it, CX, y + IH[it] / 2))
            y += IH[it]
    return out

def pores(sec, hw0, seed):
    """staggered pits along both edges, only where the section is full width (the porous cell)."""
    out, y, k = [], sec["y0"] + 12, seed
    while y < sec["y1"] - 10:
        w = hw0(y)
        if w > 16.6:
            side = -1 if (k % 2) else 1
            r = (1.0, 1.6, 1.2, 1.9, 1.1)[k % 5]
            out.append((CX + side * (w - 4.0), y, r))
        y += 8.5
        k += 1
    return out

CLOCK_LINES = ["10", "—", "42", "PM"]

def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()
