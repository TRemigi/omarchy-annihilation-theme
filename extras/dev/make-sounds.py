#!/usr/bin/env python3
# Developer tool, not part of the theme. Synthesizes the three notification sounds the plugin plays
# (sounds/arrive.ogg, low.ogg, urgent.ogg), so they are original and can be regenerated and tuned
# from the repo. Python's standard library and ffmpeg only.
#
#   python3 extras/dev/make-sounds.py [outdir]     # default: extras/plugin/annihilation.shimmer/sounds
#
# The aim is the Shimmer, not a bell: a soft glass-like tone with a slow attack (about 0.14 s), a long
# decay, and pairs of partials a few cents apart so the tone beats slowly and seems to refract. Higher
# partials die sooner than the fundamental. A little air (ffmpeg's aecho) and a fade at the end.
#   arrive   G4 with its fifth, and a faint octave shimmer a moment later
#   low      C4 alone, quieter and shorter
#   urgent   G3, then C#4 (a tritone): two slow notes, unsettled but not an alarm
# Files are normalised after the air is added: -9 dBFS peak for arrive and urgent, -15 for low (the
# quieter one is quieter on purpose). The plugin's volume setting scales them down from there.
import math, os, struct, subprocess, sys, tempfile, wave

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))


def note(buf, f, start, dur, amp, decay=1.9, attack=0.14, detune=1.004):
    """Add one tone to buf: f and a slightly detuned twin, plus softer, faster-dying partials."""
    partials = [(1.0, 1.0, 1.0), (detune, 0.9, 1.0), (2.0, 0.32, 1.7), (2.0 * detune, 0.22, 1.7), (3.0, 0.10, 2.6)]
    n0 = int(start * RATE)
    for i in range(int(dur * RATE)):
        if n0 + i >= len(buf):
            break
        t = i / RATE
        a = min(1.0, t / attack)
        a = a * a * (3 - 2 * a)                       # smoothstep attack
        s = 0.0
        for ratio, level, speed in partials:
            s += level * math.exp(-t * decay * speed) * math.sin(2 * math.pi * f * ratio * t)
        buf[n0 + i] += amp * a * s


def peak_db(path):
    with wave.open(path, "rb") as w:
        raw = w.readframes(w.getnframes())
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
    return 20 * math.log10(max(1, max(abs(x) for x in samples)) / 32768)


def render(name, seconds, notes, outdir, target_db=-9.0):
    buf = [0.0] * int(seconds * RATE)
    for n in notes:
        note(buf, **n)
    peak = max(abs(x) for x in buf) or 1.0
    with tempfile.TemporaryDirectory() as tmp:
        dry = os.path.join(tmp, name + "-dry.wav")
        wet = os.path.join(tmp, name + "-wet.wav")
        with wave.open(dry, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x / peak * 0.5)) * 32767)) for x in buf))
        # The air first, then measure and set the level, then fade and encode.
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", dry,
                        "-af", "aecho=0.7:0.6:70|130|210:0.30|0.20|0.12", wet], check=True)
        gain = target_db - peak_db(wet)
        out = os.path.join(outdir, name + ".ogg")
        fade = f"afade=t=out:st={seconds - 0.5:.2f}:d=0.5"
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", wet,
                        "-af", f"volume={gain:.2f}dB," + fade,
                        "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    print("wrote", out)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "plugin", "annihilation.shimmer", "sounds")
    os.makedirs(outdir, exist_ok=True)
    render("arrive", 3.0, [
        dict(f=392.0, start=0.0, dur=3.0, amp=1.0),
        dict(f=588.0, start=0.0, dur=3.0, amp=0.55, decay=2.2),
        dict(f=784.0 * 1.002, start=0.09, dur=2.4, amp=0.22, decay=2.6),
    ], outdir)
    render("low", 2.0, [
        dict(f=261.6, start=0.0, dur=2.0, amp=0.7, decay=2.4),
    ], outdir, target_db=-15.0)
    render("urgent", 4.0, [
        dict(f=196.0, start=0.0, dur=3.2, amp=0.9, decay=1.5, attack=0.2),
        dict(f=277.2, start=0.45, dur=3.5, amp=1.0, decay=1.4, attack=0.2),
    ], outdir)


if __name__ == "__main__":
    main()
