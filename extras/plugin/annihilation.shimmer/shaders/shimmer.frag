#version 440

// The Shimmer, as it looks in the film: the air itself seems to bend light.
// Two layers work together.
//
// The TINT is a continuous, translucent film of spectral colour over the whole
// scene, blended so that it shifts the hue of what is behind it while keeping its
// brightness and detail, the way light is dispersed by uneven glass. It has no
// mask and so no shape: its strength varies gently from place to place. Its hue
// is a single smooth value that runs once through the spectrum (teal, blue,
// violet, magenta, pink, orange, amber) and is warped so that it swirls, like
// colour in oil on water. It is deliberately not cyclic: a hue that wraps
// repeatedly gives parallel stripes, or concentric rings around the peaks of the
// noise, and both look artificial.
//
// The LIGHT is added on top: a few curtains at a time, each swelling and fading
// on its own, faintly striated by straight vertical columns, its colour running
// across it in the same spectrum, with a warm white glint in the brightest part.
// Warm and pink glows wander in from the edges, and spores rise through it all.
//
// Nothing is scheduled. Everything comes from 3D value noise with time as the
// third axis, so the patterns evolve instead of looping, and `seed` (random per
// session) makes every session different. The colours are the Shimmer's own, not
// the shell theme's, so they live here.
//
// The output is premultiplied alpha. In the default additive mode the light is
// deliberately allowed to exceed alpha, which a premultiplied "over" blend turns
// into added light; with `additive` off, alpha is raised to cover the colour so
// the result is an ordinary translucent layer. Rebuild with
// shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float motes;
    float seed;
    float additive;
    vec2 resolution;
} ubuf;

// Mid-tone colours for the wash, so that it tints instead of whitening.
const vec3 W_TEAL = vec3(0.2078, 0.6902, 0.7059);  // #35B0B4
const vec3 W_BLUE = vec3(0.2902, 0.3608, 0.8784);  // #4A5CE0
const vec3 W_VIOLET = vec3(0.5098, 0.3137, 0.8235);  // #8250D2
const vec3 W_MAGENTA = vec3(0.8157, 0.2902, 0.6510);  // #D04AA6
const vec3 W_PINK = vec3(0.9333, 0.4980, 0.7490);  // #EE7FBF
const vec3 W_ORANGE = vec3(0.8863, 0.4392, 0.2510);  // #E27040
const vec3 W_AMBER = vec3(0.7843, 0.6275, 0.2196);  // #C8A038

// Lighter colours for the added light.
const vec3 L_GREEN = vec3(0.5255, 0.8392, 0.6039);  // #86D69A
const vec3 L_TEAL = vec3(0.2000, 0.7686, 0.8157);  // #33C4D0
const vec3 L_BLUE = vec3(0.3725, 0.5176, 1.0000);  // #5F84FF
const vec3 L_VIOLET = vec3(0.6039, 0.4000, 0.9490);  // #9A66F2
const vec3 L_PINK = vec3(0.9490, 0.4784, 0.7843);  // #F27AC8
const vec3 L_PEACH = vec3(0.9569, 0.6588, 0.4706);  // #F4A878
const vec3 WARM = vec3(1.0000, 0.9137, 0.8118);  // #FFE9CF
const vec3 AQUA = vec3(0.8314, 0.9176, 0.9255);  // #D4EAEC

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float hash12(vec2 p) {
    return hash13(vec3(p, 1.7));
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float x00 = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
    float x10 = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
    float x01 = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
    float x11 = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

// Fractal noise, normalised to 0..1. `octaves` is 2 or 3; z is time.
float fbm3(vec3 p, int octaves) {
    float a = 0.5;
    float s = 0.0;
    float norm = 0.0;
    for (int i = 0; i < 3; i++) {
        if (i >= octaves) break;
        s += a * noise3(p);
        norm += a;
        p = vec3(p.xy * 2.03 + vec2(17.1, 9.2), p.z * 1.7 + 3.3);
        a *= 0.5;
    }
    return s / norm;
}

// Blend between stop a (at pa) and stop b (at pb) with a smooth ease.
vec3 seg(vec3 a, vec3 b, float pa, float pb, float x) {
    return mix(a, b, smoothstep(0.0, 1.0, (x - pa) / (pb - pa)));
}

// teal, blue, violet, magenta, pink, orange, amber. Magenta and pink get a wide
// share of the range; only neighbouring hues are ever blended.
vec3 washSpectrum(float x) {
    x = clamp(x, 0.0, 0.9999);
    if (x < 0.14) return seg(W_TEAL, W_BLUE, 0.00, 0.14, x);
    if (x < 0.28) return seg(W_BLUE, W_VIOLET, 0.14, 0.28, x);
    if (x < 0.46) return seg(W_VIOLET, W_MAGENTA, 0.28, 0.46, x);
    if (x < 0.62) return seg(W_MAGENTA, W_PINK, 0.46, 0.62, x);
    if (x < 0.80) return seg(W_PINK, W_ORANGE, 0.62, 0.80, x);
    return seg(W_ORANGE, W_AMBER, 0.80, 1.00, x);
}

// green, teal, blue, violet, pink, peach.
vec3 lightSpectrum(float x) {
    x = clamp(x, 0.0, 0.9999);
    if (x < 0.14) return seg(L_GREEN, L_TEAL, 0.00, 0.14, x);
    if (x < 0.30) return seg(L_TEAL, L_BLUE, 0.14, 0.30, x);
    if (x < 0.46) return seg(L_BLUE, L_VIOLET, 0.30, 0.46, x);
    if (x < 0.66) return seg(L_VIOLET, L_PINK, 0.46, 0.66, x);
    return seg(L_PINK, L_PEACH, 0.66, 1.00, x);
}

// Spores: about half the cells of a coarse grid host a drifting, flickering
// point. The grid scrolls upward, so everything rises. Returns premultiplied.
vec4 spores(vec2 p, float t) {
    vec2 q = p * 6.0;
    q.y += t * 0.2;
    vec2 id = floor(q);
    vec3 rgb = vec3(0.0);
    float a = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = id + vec2(float(i), float(j));
            float h = hash12(c);
            if (h < 0.5) continue;
            vec2 o = hash22(c);
            vec2 pos = c + 0.15 + 0.7 * o
                + 0.25 * vec2(sin(t * 0.3 + h * 40.0), cos(t * 0.23 + h * 17.0));
            float dist = length(q - pos);
            float r = mix(0.025, 0.07, fract(h * 7.0));
            float g = exp(-dist * dist / (r * r));
            float tw = 0.55 + 0.45 * sin(t * (0.4 + h) + h * 50.0);
            vec3 col = mix(L_PEACH, AQUA, step(0.8, fract(h * 13.0)));
            rgb += col * g * tw;
            a += g * tw;
        }
    }
    return vec4(rgb, a) * 0.6;
}

// Marsh-water light, confined to the bottom of the screen.
float caustics(vec2 p, float t) {
    vec2 q = p * vec2(7.0, 9.0);
    float a = sin(q.x + t * 0.35 + 2.0 * noise3(vec3(q * 0.5 + t * 0.05, 0.5)));
    float b = sin(q.y * 1.3 - t * 0.28 + 2.0 * noise3(vec3(q * 0.45 - t * 0.04, 0.5)));
    return pow(clamp(1.0 - abs(a * b), 0.0, 1.0), 6.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.resolution.x / max(ubuf.resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);
    float t = ubuf.time;
    float s = ubuf.seed;

    // A gentle domain warp, so nothing stands rigid.
    float wx = fbm3(vec3(p * 0.9, t * 0.090 + s), 2);
    float wy = fbm3(vec3(p * 0.9 + vec2(7.3, 3.1), t * 0.0783 + s * 1.7), 2);
    vec2 q = p + 0.30 * (vec2(wx, wy) - 0.5);

    // The tint has no mask, so it has no shape. It covers the screen continuously
    // and its strength varies gently from place to place. `pc` is the older sweep
    // of hue across the screen, which the curtains of light below still use.
    float ang = 0.5 + 0.6 * sin(t * 0.040 + s * 2.1);
    float pc = ((q.x - aspect * 0.5) * cos(ang) + (q.y - 0.5) * sin(ang)) * 0.75
        + 0.5 * (fbm3(vec3(q * 0.7 + vec2(0.0, 4.0), t * 0.06 + s * 5.3), 2) - 0.5)
        + 0.5 + 0.14 * sin(t * 0.026 + s * 3.3);
    // The hue is one smooth value, not a cycle: teal at one extreme and amber at
    // the other, so colour flows into other colour and never repeats as bands or
    // closes into rings. The field is warped so that it swirls, the way colour
    // does in oil on water.
    vec2 hq = q + 0.45 * (vec2(fbm3(vec3(q * 1.3 + vec2(3.1, 7.7), t * 0.1260 + s * 6.7), 2),
                                 fbm3(vec3(q * 1.3 + vec2(9.4, 1.2), t * 0.1120 + s * 7.9), 2)) - 0.5);
    float h1 = fbm3(vec3(hq * vec2(1.6, 1.3) + vec2(6.3, 1.9), t * 0.1862 + s * 1.9), 3);
    float h2 = fbm3(vec3(hq * vec2(3.4, 2.7) + vec2(2.2, 5.1), t * 0.1680 + s * 3.7), 2);
    float hx = 0.46 + 2.0 * (h1 - 0.55) + 0.5 * (h2 - 0.5);
    float ws = fbm3(vec3(q * vec2(1.4, 1.1) + vec2(1.7, 8.3), t * 0.0950 + s * 2.9), 3);
    float wa = 0.34 * (0.1 + 0.90 * smoothstep(0.3, 0.8, ws)) * mix(0.7, 1.0, 1.0 - uv.y);
    vec3 rgb = washSpectrum(hx) * wa;
    float a = wa;

    // The light: small curtains, each born and dying on its own.
    float d = fbm3(vec3(q * vec2(2.5, 1.9) + vec2(2.1, 9.4), t * 0.080 + s * 2.3), 3);
    float core = smoothstep(0.56, 0.76, d);
    float halo = smoothstep(0.44, 0.70, d);
    float hot = smoothstep(0.70, 0.84, d);

    // Faint, straight vertical columns: no warp on x, so they stay vertical.
    float sx = fbm3(vec3((p.x + 0.04 * sin(t * 0.05 + s)) * 9.0, p.y * 0.45 + 3.0, t * 0.12 + s * 3.1), 3);
    float cols = smoothstep(0.25, 0.90, sx);
    float light = core * (0.75 + 0.25 * cols);
    rgb += lightSpectrum(pc) * (light * 0.38 + halo * 0.06) + WARM * (hot * 0.10);

    // Light leaks: a warm glow and a pink one wander in from the edges, and each
    // fades in and out on its own slow clock.
    for (int k = 0; k < 2; k++) {
        float kk = float(k);
        float ph = s * (1.3 + kk);
        vec2 c = vec2(aspect * (0.5 + 0.62 * sin(t * (0.011 + 0.007 * kk) * 2.0 + ph * 3.1)),
                      0.5 + 0.62 * sin(t * (0.009 + 0.0065 * kk) * 2.0 + ph * 5.3 + 1.7));
        vec2 dv = vec2(p.x - c.x, (p.y - c.y) * 1.3);
        float rr = 0.24 + 0.05 * kk;
        float g = exp(-dot(dv, dv) / (rr * rr));
        float amp = smoothstep(0.3, 0.9, 0.5 + 0.5 * sin(t * (0.017 + 0.006 * kk) * 2.0 + ph * 7.7));
        vec3 lc = k == 0 ? L_PEACH : L_PINK;
        rgb += lc * (g * amp * 0.18);
    }

    vec4 sp = spores(p, t) * ubuf.motes;
    rgb += sp.rgb * 0.8;
    a += sp.a * 0.15;

    float c = caustics(p, t) * smoothstep(0.6, 1.0, uv.y) * 0.04;
    rgb += AQUA * c;

    // intensity 0.35 (the default) is the strength this was designed at.
    vec4 acc = vec4(rgb, a) * (ubuf.intensity * 2.0);
    if (ubuf.additive < 0.5) acc.a = max(acc.a, max(acc.r, max(acc.g, acc.b)));
    acc = clamp(acc, 0.0, 1.0);

    fragColor = acc * ubuf.qt_Opacity;
}
