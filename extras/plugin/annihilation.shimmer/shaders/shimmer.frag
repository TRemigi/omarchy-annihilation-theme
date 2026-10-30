#version 440

// The Shimmer, as it looks in the film: a translucent, silky haze that tints
// whatever is behind it. Soft patches of veil swell, drift and dissolve in
// places that are never the same twice, shaded as stretched folds with glossy
// rims; their colour wanders between teal, periwinkle, violet and rose; warm
// and violet glows wander in from the edges and fade; spores rise through it.
//
// Nothing here is a scheduled sweep. Everything comes from 3D value noise with
// time as the third axis, so the patterns evolve instead of looping, and `seed`
// (random per session) makes every session different. Output is premultiplied
// alpha, kept low so it reads as something seen at the edge of vision.
// Rebuild with shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float motes;
    float seed;
    vec2 resolution;
    vec4 tealColor;
    vec4 slateColor;
    vec4 violetColor;
    vec4 roseColor;
    vec4 aquaColor;
    vec4 peachColor;
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

// teal -> periwinkle -> violet -> rose. Only neighbouring hues are ever
// blended, so a mix never passes through grey.
vec3 palette(float x) {
    float s = clamp(x, 0.0, 0.9999) * 3.0;
    float f = smoothstep(0.0, 1.0, fract(s));
    if (s < 1.0) return mix(ubuf.tealColor.rgb, ubuf.slateColor.rgb, f);
    if (s < 2.0) return mix(ubuf.slateColor.rgb, ubuf.violetColor.rgb, f);
    return mix(ubuf.violetColor.rgb, ubuf.roseColor.rgb, f);
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

    // A slow domain warp, so the folds morph rather than slide.
    float wx = fbm3(vec3(p * 0.85, t * 0.030 + s), 2);
    float wy = fbm3(vec3(p * 0.85 + vec2(7.3, 3.1), t * 0.026 + s * 1.7), 2);
    vec2 q = p + 0.8 * (vec2(wx, wy) - 0.5);

    // Where the veils are: several patches at once, each swelling and dissolving
    // on its own, a little more of them toward the top. `haze` is the broad soft
    // layer, `sheet` the defined silhouettes, `rim` a thin glossy edge.
    float d = fbm3(vec3(q * vec2(2.4, 1.8) + vec2(2.1, 9.4), t * 0.022 + s * 2.3), 3);
    float top = mix(0.5, 1.0, 1.0 - uv.y);
    float haze = smoothstep(0.30, 0.70, d) * top;
    float sheet = smoothstep(0.44, 0.70, d) * top;
    float rimDist = (d - 0.57) / 0.06;
    float rim = exp(-rimDist * rimDist) * top;

    // Silky folds: stretched vertically, with glossy ridge lines.
    float f = fbm3(vec3(q * vec2(2.6, 0.9) + vec2(4.0, 1.0), t * 0.045 + s * 3.1), 3);
    float ridge = 1.0 - abs(2.0 * f - 1.0);
    float sheen = ridge * ridge * ridge;
    float body = 0.4 + 0.6 * smoothstep(0.3, 0.8, f);

    // Which colour: varies slowly across the screen and in time.
    float cf = fbm3(vec3(q * 0.55 + vec2(11.0, 5.0), t * 0.018 + s * 4.7), 2);
    vec3 col = palette(smoothstep(0.28, 0.72, cf));

    float a = haze * 0.20 + sheet * (0.34 * body + 0.16 * sheen) + rim * 0.10;
    vec3 rgb = col * (haze * 0.30 + sheet * body * 0.55)
        + ubuf.aquaColor.rgb * (sheet * sheen * 0.24 + rim * 0.20);

    // Light leaks: a warm glow and a violet one wander in from the edges, and
    // each fades in and out on its own slow clock.
    for (int k = 0; k < 2; k++) {
        float kk = float(k);
        float ph = s * (1.3 + kk);
        vec2 c = vec2(aspect * (0.5 + 0.62 * sin(t * (0.011 + 0.007 * kk) + ph * 3.1)),
                      0.5 + 0.62 * sin(t * (0.009 + 0.0065 * kk) + ph * 5.3 + 1.7));
        vec2 dv = vec2(p.x - c.x, (p.y - c.y) * 1.3);
        float rr = 0.30 + 0.1 * kk;
        float g = exp(-dot(dv, dv) / (rr * rr));
        float amp = smoothstep(0.3, 0.9, 0.5 + 0.5 * sin(t * (0.017 + 0.006 * kk) + ph * 7.7));
        vec3 lc = k == 0 ? ubuf.peachColor.rgb : ubuf.violetColor.rgb;
        rgb += lc * (g * amp * 0.30);
        a += g * amp * 0.22;
    }

    vec4 sp = spores(p, t) * ubuf.motes;
    rgb += sp.rgb;
    a += sp.a;

    float c = caustics(p, t) * smoothstep(0.6, 1.0, uv.y) * 0.05;
    rgb += ubuf.aquaColor.rgb * c;
    a += c;

    vec4 acc = vec4(rgb, a) * ubuf.intensity;
    acc.a = clamp(acc.a, 0.0, 1.0);
    acc.rgb = min(acc.rgb, vec3(acc.a));

    fragColor = acc * ubuf.qt_Opacity;
}
