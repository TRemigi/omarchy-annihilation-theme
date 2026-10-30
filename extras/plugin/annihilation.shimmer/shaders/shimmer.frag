#version 440

// The Shimmer: a slow thin-film band drifting across the desktop, spores rising
// through the dark, and faint caustics along the bottom edge. Output is
// premultiplied alpha, kept low so it reads as something seen at the edge of
// vision. Rebuild with shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float motes;
    vec2 resolution;
    vec4 tealColor;
    vec4 bruiseColor;
    vec4 amberColor;
} ubuf;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float a = 0.5;
    float s = 0.0;
    for (int i = 0; i < 3; i++) {
        s += a * vnoise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return s;
}

// One diagonal band of interference colour. `phase` offsets the cycle so two
// bands can share the screen; each crosses it in 90 s and is fully off-screen
// at the wrap, so there is no pop. Returns premultiplied rgba.
vec4 band(vec2 p, float aspect, float t, float phase) {
    vec2 dir = normalize(vec2(0.82, 0.57));
    float d = dot(p - vec2(aspect * 0.5, 0.5), dir);
    float span = 0.5 * (aspect * dir.x + dir.y) + 0.55;
    float center = mix(-span, span, fract(t / 90.0 + phase));

    float warp = fbm(p * 1.7 + vec2(t * 0.015, -t * 0.010) + phase * 7.0);
    float dd = d - center + (warp - 0.5) * 0.45;
    float body = exp(-dd * dd / 0.0256);

    float s = 0.5 + 0.5 * sin((dd * 5.5 + warp * 3.0 + t * 0.05) * 6.2831853);
    vec3 col = mix(ubuf.tealColor.rgb, ubuf.bruiseColor.rgb, smoothstep(0.0, 0.5, s));
    col = mix(col, ubuf.amberColor.rgb, smoothstep(0.55, 1.0, s) * 0.8);

    float a = body * 0.55;
    return vec4(col * a, a);
}

// Spores: about half the cells of a coarse grid host a drifting, flickering
// point. The grid scrolls upward, so everything rises.
vec4 sporeLayer(vec2 p, float t) {
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
            vec3 col = mix(ubuf.amberColor.rgb, ubuf.tealColor.rgb, step(0.8, fract(h * 13.0)));
            rgb += col * g * tw;
            a += g * tw;
        }
    }
    return vec4(rgb, a) * 0.9;
}

// Marsh-water light, confined to the bottom of the screen.
float caustics(vec2 p, float t) {
    vec2 q = p * vec2(7.0, 9.0);
    float a = sin(q.x + t * 0.35 + 2.0 * vnoise(q * 0.5 + t * 0.05));
    float b = sin(q.y * 1.3 - t * 0.28 + 2.0 * vnoise(q * 0.45 - t * 0.04));
    return pow(clamp(1.0 - abs(a * b), 0.0, 1.0), 6.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.resolution.x / max(ubuf.resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);
    float t = ubuf.time;

    vec4 acc = band(p, aspect, t, 0.0) + band(p, aspect, t, 0.5) * 0.6;

    vec4 sp = sporeLayer(p, t) * ubuf.motes;
    acc += sp;

    float c = caustics(p, t) * smoothstep(0.6, 1.0, uv.y) * 0.16;
    acc += vec4(ubuf.tealColor.rgb * c, c);

    acc *= ubuf.intensity;
    acc.a = clamp(acc.a, 0.0, 1.0);
    acc.rgb = min(acc.rgb, vec3(acc.a));

    fragColor = acc * ubuf.qt_Opacity;
}
