#!/usr/bin/env python3
"""Developer tool, not part of the theme. Where does a window-glow shader have hard edges?

Renders the shader with extras/dev/shader-harness (see its header for how to build it and
extract the shader) at a real screen size, and prints the largest steps between neighbouring
pixels where both are bright: in normalised colour (a hue jump) and in brightness. It skips
16 px around each window edge, where the soft bright line of the rim lives. Compare the
numbers between versions; a smooth glow is under about 0.15 per pixel in colour. A hard
edge shows as a few pixels of 0.5 to 1.0, which is how the colour switch along every fan's
edge (0.87) was found, then traced by printing the profile across it. Needs numpy.

  edge-scan.py HARNESS SHADER.frag [x,y,d]     (the optional pointer turns cursor mode on)
"""
import os, subprocess, sys, tempfile
import numpy as np

W, H, RIM = 1142, 1190, 31
RECTS = [(12, 12, 930, 1166), (950, 12, 180, 570), (950, 596, 180, 582)]      # roughly a two-column tiling

def render(harness, frag, t, seed, pointer, rects, tmp):
    env = {**os.environ, "EGL_PLATFORM": "surfaceless", "LIBGL_ALWAYS_SOFTWARE": "1", "RIM": str(RIM), "ROUNDING": "4",
           "RECTS": ";".join(",".join(map(str, r)) for r in rects)}
    if pointer: env["CURSOR"] = pointer
    path = os.path.join(tmp, "frame.pam")
    subprocess.run([harness, frag, str(W), str(H), str(t), str(seed), "0.35", "0.0", path], env=env, capture_output=True, check=True)
    data = open(path, "rb").read(); start = data.index(b"ENDHDR\n") + 7
    return np.frombuffer(data[start:], dtype=np.uint8).reshape(H, W, 4)[..., :3].astype(np.float64) / 255

def edge_mask(rects, margin=16):
    yy, xx = np.mgrid[0:H, 0:W]; m = np.zeros((H, W), bool)
    for x, y, w, h in rects:
        outer = (xx >= x - margin) & (xx <= x + w + margin) & (yy >= y - margin) & (yy <= y + h + margin)
        inner = (xx > x + margin) & (xx < x + w - margin) & (yy > y + margin) & (yy < y + h - margin)
        m |= outer & ~inner
    return m

def steps(c):
    mx = c.max(-1); n = c / np.maximum(mx[..., None], 1e-6); bright = mx > 0.16
    cs = np.zeros((H, W)); bs = np.zeros((H, W))
    for ax in (0, 1):
        a = (slice(0, -1), slice(None)) if ax == 0 else (slice(None), slice(0, -1))
        b = (slice(1, None), slice(None)) if ax == 0 else (slice(None), slice(1, None))
        ok = bright[a] & bright[b]
        cs[a] = np.maximum(cs[a], np.abs(n[a] - n[b]).sum(-1) * ok); bs[a] = np.maximum(bs[a], np.abs(mx[a] - mx[b]) * ok)
    return cs, bs

if __name__ == "__main__":
    if len(sys.argv) < 3: sys.exit(__doc__)
    harness, frag = sys.argv[1], sys.argv[2]; pointer = sys.argv[3] if len(sys.argv) > 3 else None
    rects = RECTS[:1] if pointer else RECTS                    # cursor mode draws only the active window
    skip = edge_mask(rects); colour, bright, where = [], [], []
    with tempfile.TemporaryDirectory() as tmp:
        for seed in (3.7, 11.2, 27.5, 51.0, 8.8, 33.3):
            for t in range(10, 600, 55):
                cs, bs = steps(render(harness, frag, t, seed, pointer, rects, tmp)); cs[skip] = 0; bs[skip] = 0
                colour.append(cs.max()); bright.append(bs.max()); y, x = np.unravel_index(cs.argmax(), cs.shape); where.append((cs.max(), t, seed, int(x), int(y)))
    print(f"colour step per pixel: worst {max(colour):.3f}, median moment {np.median(colour):.3f}; brightness: worst {max(bright):.3f}")
    print("worst colour steps (step, t, seed, x, y):", [(round(float(a), 3), t, s, x, y) for a, t, s, x, y in sorted(where, reverse=True)[:3]])
