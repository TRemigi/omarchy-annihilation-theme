// Developer tool, not part of the theme. Why the glow's follow was jerky, and what replaced it.
// A pointer sweeps at constant speed, the poller samples it, and a smoother turns the samples into
// the position drawn each frame. "current" is what WindowGlow.qml used to do (an ease-out
// animation restarted at every sample); the springs are what it does now (springStep). Reports
// the spread of the drawn speed as a percentage of the mean (0 is perfectly even), the worst
// change of speed between two frames, frames running below half speed, and the lag behind the
// pointer. No dependencies:  node extras/dev/pointer-smoothing-sim.js
// Pointer sweeps at constant speed; the poller samples it; a smoother turns samples into the displayed position per frame.
function run(name, pollHz, frameHz, smoother, speed = 1200, jitterMs = 3) {
  const dtF = 1 / frameHz, N = Math.round(2 * frameHz);
  const samples = []; let t = 0, seed = 1; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  for (let s = 0; s < 2 + 1; s += 1 / pollHz) samples.push({ t: s + (rnd() - 0.5) * 2 * jitterMs / 1000, x: speed * s });
  const sm = smoother(); const out = []; let si = 0;
  for (let f = 0; f < N; f++) {
    const tf = f * dtF;
    while (si < samples.length && samples[si].t <= tf) { sm.target(samples[si].x, tf); si++; }
    out.push({ t: tf, x: sm.frame(tf, dtF), truth: speed * tf });
  }
  const sp = []; for (let i = 1; i < out.length; i++) sp.push((out[i].x - out[i - 1].x) / dtF);
  const w = sp.slice(Math.round(0.5 * frameHz)), m = w.reduce((a, b) => a + b) / w.length;
  const sd = Math.sqrt(w.reduce((a, b) => a + (b - m) ** 2, 0) / w.length);
  const lag = out.slice(Math.round(0.5 * frameHz)).reduce((a, o) => a + (o.truth - o.x), 0) / w.length;
  // acceleration: change of speed frame to frame (jerkiness), px/s per frame
  const jerk = Math.max(...w.slice(1).map((v, i) => Math.abs(v - w[i])));
  const stalls = w.filter((v) => v < 0.5 * m).length;
  console.log(`${name.padEnd(34)} poll ${String(pollHz).padStart(3)}Hz frames ${String(frameHz).padStart(3)}Hz: speed ${m.toFixed(0)} px/s, spread ${(100 * sd / m).toFixed(1)}% of mean, worst frame-to-frame change ${(100 * jerk / m).toFixed(0)}%, frames below half speed ${stalls}, lag ${lag.toFixed(1)} px (${(1000 * lag / speed).toFixed(0)} ms)`);
}
// Current: Behavior + NumberAnimation 110 ms OutQuad, restarted from the current value at every sample.
const behavior = () => { let cur = 0, from = 0, to = 0, t0 = 0, active = false; return {
  target(x, t) { from = cur; to = x; t0 = t; active = true; },
  frame(t) { if (active) { const u = Math.min(1, (t - t0) / 0.110); cur = from + (to - from) * (1 - (1 - u) * (1 - u)); } return cur; } }; };
// Proposed: critically damped spring, integrated exactly each frame.
const spring = (w) => () => { let x = 0, v = 0, tg = 0; return {
  target(xx) { tg = xx; },
  frame(t, dt) { const d = x - tg, e = Math.exp(-w * dt), k = v + w * d; x = tg + (d + k * dt) * e; v = (v - k * w * dt) * e; return x; } }; };
for (const [p, f] of [[30, 60], [30, 144], [60, 60], [60, 144]]) {
  run("current (restarted ease-out)", p, f, behavior);
  run("spring w=25", p, f, spring(25));
  run("spring w=32", p, f, spring(32));
}
