#version 440

// The Shimmer, as it looks in the film: not a veil laid over the picture but
// light. A few narrow curtains of it appear at a time, in different places and
// for different lengths of time; each is built from thin vertical columns that
// slide and shimmer at their own speeds, its colour disperses across its width
// (lavender, blue, teal, green, peach) like light through a prism, and its
// brightest part burns warm white. It is added to what is behind it, so the
// wallpaper keeps its contrast instead of being washed out.
//
// Nothing is scheduled. Everything comes from 3D value noise with time as the
// third axis, so the patterns evolve instead of looping, and `seed` (random per
// session) makes every session different. A couple of warm and violet glows
// wander in from the screen edges, and spores rise through it all.
//
// The output is premultiplied alpha. In the default additive mode the colour is
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
    vec4 tealColor;
    vec4 blueColor;
    vec4 violetColor;
    vec4 greenColor;
    vec4 peachColor;
    vec4 warmColor;
    vec4 aquaColor;
} ubuf;

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

// violet -> blue -> teal -> green -> peach, the order in which the film's light
// separates. Only neighbours are ever blended, so a mix never passes through grey.
vec3 palette(float x) {
    float s = clamp(x, 0.0, 0.9999) * 4.0;
    float f = smoothstep(0.0, 1.0, fract(s));
    if (s < 1.0) return mix(ubuf.violetColor.rgb, ubuf.blueColor.rgb, f);
    if (s < 2.0) return mix(ubuf.blueColor.rgb, ubuf.tealColor.rgb, f);
    if (s < 3.0) return mix(ubuf.tealColor.rgb, ubuf.greenColor.rgb, f);
    return mix(ubuf.greenColor.rgb, ubuf.peachColor.rgb, f);
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
            vec3 col = mix(ubuf.peachColor.rgb, ubuf.aquaColor.rgb, step(0.8, fract(h * 13.0)));
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

    // A slow domain warp, so the curtains lean and bend rather than stand rigid.
    float wx = fbm3(vec3(p * 0.9, t * 0.060 + s), 2);
    float wy = fbm3(vec3(p * 0.9 + vec2(7.3, 3.1), t * 0.0522 + s * 1.7), 2);
    vec2 q = p + 0.6 * (vec2(wx, wy) - 0.5);

    // Where the light is: small patches, taller than wide, each swelling and
    // dying on its own. `core` is the curtain, `halo` a soft glow around it and
    // `hot` its brightest part.
    float d = fbm3(vec3(q * vec2(3.4, 1.5) + vec2(2.1, 9.4), t * 0.045 + s * 2.3), 3);
    float core = smoothstep(0.54, 0.72, d);
    float halo = smoothstep(0.44, 0.68, d);
    float hot = smoothstep(0.60, 0.76, d);

    // Thin vertical columns that slide sideways and shimmer, each at its own pace.
    float drift = 0.35 * fbm3(vec3(q.x * 3.0 + 5.0, q.y * 0.5, t * 0.05 + s), 2);
    float sx = fbm3(vec3((q.x + drift) * 16.0, q.y * 0.7 + 3.0, t * 0.14 + s * 3.1), 3);
    float streak = smoothstep(0.32, 0.82, sx);
    float colIdx = floor(q.x * 16.0);
    float fine = 0.88 + 0.12 * sin(t * (0.5 + 1.2 * fract(colIdx * 0.37)) + colIdx * 5.1);

    // Dispersion: the colour runs across each curtain, like light through a prism.
    float hf = fbm3(vec3(q.x * 1.7 + 0.5 * sx, q.y * 0.45 + 11.0, t * 0.030 + s * 4.7), 2);
    vec3 col = palette(smoothstep(0.30, 0.72, hf));

    float light = core * (0.30 + 0.70 * streak) * fine;
    vec3 rgb = col * (light * 0.70 + halo * 0.10)
        + ubuf.warmColor.rgb * (hot * (0.35 + 0.65 * streak) * 0.85);
    float a = (halo * 0.6 + core * 0.4) * 0.10;

    // Light leaks: a warm glow and a violet one wander in from the edges, and
    // each fades in and out on its own slow clock.
    for (int k = 0; k < 2; k++) {
        float kk = float(k);
        float ph = s * (1.3 + kk);
        vec2 c = vec2(aspect * (0.5 + 0.62 * sin(t * (0.011 + 0.007 * kk) * 2.0 + ph * 3.1)),
                      0.5 + 0.62 * sin(t * (0.009 + 0.0065 * kk) * 2.0 + ph * 5.3 + 1.7));
        vec2 dv = vec2(p.x - c.x, (p.y - c.y) * 1.3);
        float rr = 0.20 + 0.05 * kk;
        float g = exp(-dot(dv, dv) / (rr * rr));
        float amp = smoothstep(0.3, 0.9, 0.5 + 0.5 * sin(t * (0.017 + 0.006 * kk) * 2.0 + ph * 7.7));
        vec3 lc = k == 0 ? ubuf.peachColor.rgb : ubuf.violetColor.rgb;
        rgb += lc * (g * amp * 0.20);
    }

    vec4 sp = spores(p, t) * ubuf.motes;
    rgb += sp.rgb * 0.8;
    a += sp.a * 0.15;

    float c = caustics(p, t) * smoothstep(0.6, 1.0, uv.y) * 0.04;
    rgb += ubuf.aquaColor.rgb * c;

    // intensity 0.35 (the default) is the strength this was designed at.
    vec4 acc = vec4(rgb, a) * (ubuf.intensity * 2.0);
    if (ubuf.additive < 0.5) acc.a = max(acc.a, max(acc.r, max(acc.g, acc.b)));
    acc = clamp(acc, 0.0, 1.0);

    fragColor = acc * ubuf.qt_Opacity;
}
