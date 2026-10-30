#!/usr/bin/env python3
"""Developer tool, not part of the theme. How fast does a shader's output change?

Renders a run of frames with extras/dev/shader-harness (see its header for how
to build it and extract the shader) and prints the mean change per second of the
overlay's colour, relative to its own mean level. That makes "more dynamic" a
number: the first veil version scored 0.04, a rate that read as static; the light
curtains scored 0.21 and felt alive, 0.38 felt like flicker; the spectral tint is
tuned to about 0.2. Needs numpy.

  overlay-rate.py HARNESS SHADER.frag [intensity]
"""
import os, subprocess, sys, tempfile
import numpy as np

W, H, T0, DT, N = 400, 225, 60.0, 0.5, 40

def rate(harness, frag, seed, intensity):
    env = {**os.environ, "EGL_PLATFORM": "surfaceless", "LIBGL_ALWAYS_SOFTWARE": "1"}
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "frame.pam"); frames = []
        for i in range(N):
            subprocess.run([harness, frag, str(W), str(H), str(T0 + i * DT), str(seed), intensity, "1.0", path], env=env, capture_output=True, check=True)
            data = open(path, "rb").read(); start = data.index(b"ENDHDR\n") + 7
            frames.append(np.frombuffer(data[start:], dtype=np.uint8).reshape(H, W, 4)[..., :3].astype(np.float64) / 255)
    level = np.mean([f.mean() for f in frames])
    change = np.mean([np.abs(frames[i + 1] - frames[i]).mean() for i in range(N - 1)]) / DT
    return change / level, level

if __name__ == "__main__":
    if len(sys.argv) < 3: sys.exit(__doc__)
    for seed in (11.2, 27.5):
        r, level = rate(sys.argv[1], sys.argv[2], seed, sys.argv[3] if len(sys.argv) > 3 else "0.35")
        print(f"seed {seed}: change per second {r:.3f}x its own level (mean overlay level {level:.3f})")
