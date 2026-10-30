#!/usr/bin/env python3
"""Developer tool, not part of the theme. Which colours does a shader really produce?

Renders frames across fifteen minutes and four seeds with extras/dev/shader-harness
(see its header for how to build it and extract the shader) and prints the share of
each hue family, weighted by how bright the overlay is, plus the overlay's brightness
and how many hue families are visible in a typical frame. A colour stop list says
little about this: where a hue mapping is centred, and how steeply it runs, decide
which colours dominate (a cyclic mapping once gave pink only 8%, and a first
non-cyclic one starved teal). Needs numpy.

  hue-shares.py HARNESS SHADER.frag [intensity]
"""
import colorsys, os, subprocess, sys, tempfile
import numpy as np

W, H = 96, 54
FAMILIES = (("teal/green", 90, 200), ("blue", 200, 255), ("violet", 255, 295), ("magenta/pink", 295, 345))

def family(hue):
    for name, lo, hi in FAMILIES:
        if lo <= hue < hi: return name
    return "orange/amber"

def measure(harness, frag, intensity):
    env = {**os.environ, "EGL_PLATFORM": "surfaceless", "LIBGL_ALWAYS_SOFTWARE": "1"}
    share = {name: 0.0 for name, _, _ in FAMILIES}; share["orange/amber"] = 0.0
    level, visible = [], []
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "frame.pam")
        for seed in (3.7, 11.2, 27.5, 51.0):
            for t in range(0, 900, 60):
                # motes 0: judge the light and tint, not the spores
                subprocess.run([harness, frag, str(W), str(H), str(t), str(seed), intensity, "0.0", path], env=env, capture_output=True, check=True)
                data = open(path, "rb").read(); start = data.index(b"ENDHDR\n") + 7
                rgb = np.frombuffer(data[start:], dtype=np.uint8).reshape(H, W, 4)[..., :3].reshape(-1, 3).astype(np.float64) / 255
                weight = rgb.max(-1); level.append(weight.mean()); seen = set()
                for colour, w in zip(rgb, weight):
                    if w < 0.02: continue
                    hue = colorsys.rgb_to_hsv(*(colour / colour.max()))[0] * 360
                    share[family(hue)] += w; seen.add(family(hue))
                visible.append(len(seen))
    total = sum(share.values())
    return {k: v / total for k, v in share.items()}, np.percentile(level, [10, 50, 90]), float(np.mean(visible))

if __name__ == "__main__":
    if len(sys.argv) < 3: sys.exit(__doc__)
    shares, level, visible = measure(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "0.35")
    print("hue shares:", {k: f"{v * 100:.0f}%" for k, v in shares.items()})
    print(f"overlay brightness p10/median/p90 = {level[0]:.3f}/{level[1]:.3f}/{level[2]:.3f}")
    print(f"hue families visible in a typical frame: {visible:.1f} of 5")
