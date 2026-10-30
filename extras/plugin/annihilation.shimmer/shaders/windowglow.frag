#version 440

// Light spilling over the edges of windows, as if it came from behind them.
//
// This runs in a layer above the windows and draws nothing but a thin band
// hugging each window's edge: inside the window (the light leaking over the
// edge onto it) and a fainter, tighter halo outside it. Everywhere else it is
// transparent, and most pixels are rejected after a few comparisons, so it costs
// next to nothing away from the edges.
//
// The light itself is the prism fans: two fans of dispersed light that enter from
// just beyond the screen edges and wander round them, each with colour following
// the angle, fine rays bent by slow noise, and a life of its own. They are not
// drawn on the wallpaper. They are the source behind the windows, and a window
// edge only lights up where a fan's light reaches it. Across
// the width of the band the hue shifts only a little, the way a bright edge is split by a prism. A faint ambient glow keeps every edge from going completely
// dark.
//
// Windows come in as rectangles (x, y, width, height in logical pixels), topmost
// first; a pixel inside several belongs to the first. Output is added light:
// colour above alpha, as in shimmer.frag, and `additive` off falls back to
// ordinary blending. Rebuild with shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float seed;
    float additive;
    float rimWidth;      // how far the light reaches into a window, in pixels
    float rounding;      // the windows' corner radius, in pixels
    vec2 resolution;
    vec4 usable;         // the part of the screen not reserved by bars: x, y, w, h
    vec4 win0;
    vec4 win1;
    vec4 win2;
    vec4 win3;
    vec4 win4;
    vec4 win5;
} ubuf;

const vec3 L_GREEN = vec3(0.5255, 0.8392, 0.6039);
const vec3 L_TEAL = vec3(0.2000, 0.7686, 0.8157);
const vec3 L_BLUE = vec3(0.3725, 0.5176, 1.0000);
const vec3 L_VIOLET = vec3(0.6039, 0.4000, 0.9490);
const vec3 L_PINK = vec3(0.9490, 0.4784, 0.7843);
const vec3 L_PEACH = vec3(0.9569, 0.6588, 0.4706);
const vec3 AQUA = vec3(0.8314, 0.9176, 0.9255);

// How fast the fans move, as a multiple of the shader clock.
const float FAN_SPEED = 3.0;
const float PI = 3.14159265;

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

vec3 seg(vec3 a, vec3 b, float pa, float pb, float x) {
    return mix(a, b, smoothstep(0.0, 1.0, (x - pa) / (pb - pa)));
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

float wrapAngle(float a) {
    return mod(a + PI, 2.0 * PI) - PI;
}

// The two fans, at p (screen height = 1). Returns their combined strength and the
// strength-weighted mean of their hues. They are blended, never chosen between:
// picking the stronger one makes colour and strength jump in a hard line wherever
// the two cross, and that line drifts as the fans wander.
vec2 fanField(vec2 p, float aspect, float t, float s) {
    float ft = t * FAN_SPEED;
    float sumE = 0.0;
    float sumH = 0.0;
    for (int k = 0; k < 2; k++) {
        float kk = float(k);
        float alpha = s * (2.3 + 1.7 * kk)
            + 0.55 * sin(ft * (0.021 + 0.011 * kk) + s * (1.9 + kk))
            + ft * (0.0035 + 0.003 * kk);
        float rk = 1.38 + 0.12 * sin(ft * (0.013 + 0.005 * kk) + s * 4.1);
        vec2 src = vec2(aspect * 0.5 + cos(alpha) * aspect * 0.5 * rk,
                        0.5 + sin(alpha) * 0.5 * rk);
        float phi0 = atan(0.5 - src.y, aspect * 0.5 - src.x)
            + 0.22 * sin(ft * (0.027 + 0.006 * kk) + s * (3.3 + kk));
        vec2 dv = p - src;
        float dist = length(dv);
        float ang = atan(dv.y, dv.x);
        float bend = 0.05 * (fbm3(vec3(dist * 1.7 + 5.0 * kk, ang * 2.0 + 3.0 * kk,
                                       ft * 0.12 + s * 3.0), 2) - 0.5) * 2.0;
        float delta = wrapAngle(ang - phi0 + bend);
        float hw = 0.40 + 0.12 * sin(ft * (0.017 + 0.004 * kk) + s * (2.7 + kk));
        float u = delta / hw;
        float env = 1.0 - smoothstep(0.25, 1.0, abs(u));
        float reach = exp(-(dist / 1.5) * (dist / 1.5));
        float life = 0.22 + 0.78 * smoothstep(0.15, 0.85,
            0.5 + 0.5 * sin(ft * (0.017 + 0.007 * kk) + s * (5.7 + kk)));
        float n1 = fbm3(vec3(u * 7.0 + 13.0 * kk, 0.5 + kk, ft * 0.09 + s * 7.0), 2);
        float ray = 0.35 + 0.65 * smoothstep(0.25, 0.85, n1);
        // A narrower slice of the spectrum than on the wallpaper: along a window edge,
        // colours should blend into one another, not read as separate strips.
        float hx = clamp(0.5 + 0.20 * u + 0.16 * sin(ft * 0.02 + s * (1.3 + kk)) + 0.12 * kk, 0.0, 1.0);
        // Only a trace of the rays: they are what made the glow read as a beam.
        float e = env * reach * life * (0.85 + 0.15 * ray);
        sumE += e;
        sumH += e * hx;
    }
    return vec2(sumE > 0.0001 ? sumH / sumE : 0.5, min(sumE, 1.0));
}

// Bright spots: a few soft round glints that drift and twinkle. Each is a plain
// Gaussian blob, the same in every direction, so nothing is projected from it; the
// caller only lets them show close to a window edge. About one cell in seven of a
// coarse grid hosts one, so at any moment there are only a few.
vec3 glints(vec2 px, float w, float t, float s) {
    float cs = 4.6 * w;
    vec2 id = floor(px / cs);
    vec3 acc = vec3(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = id + vec2(float(i), float(j));
            float h = hash12(c + s * 3.1);
            if (h < 0.86) continue;
            vec2 o = hash22(c + s * 1.7);
            vec2 pos = (c + 0.15 + 0.7 * o) * cs
                + 0.28 * cs * vec2(sin(t * (0.13 + 0.10 * h) + h * 31.0), cos(t * (0.10 + 0.09 * h) + h * 17.0));
            vec2 dv = px - pos;
            float r = w * (0.85 + 0.9 * fract(h * 9.0));
            float g = exp(-dot(dv, dv) / (r * r));
            float tw = 0.30 + 0.70 * smoothstep(0.15, 0.95, 0.5 + 0.5 * sin(t * (0.22 + 0.35 * h) + h * 47.0));
            vec3 col = mix(lightSpectrum(0.28 + 0.52 * fract(h * 13.0)), AQUA, 0.35);
            acc += col * g * tw;
        }
    }
    return acc;
}

// Signed distance from px to a window's rounded rectangle: negative inside.
// A rectangle with no width means no window.
float winSd(vec4 r, vec2 px) {
    if (r.z <= 0.0) return 1.0e5;
    vec2 hs = r.zw * 0.5;
    float rad = min(ubuf.rounding, min(hs.x, hs.y));
    vec2 q = abs(px - (r.xy + hs)) - hs + vec2(rad);
    // Inside, a plain max(q.x, q.y) creases along the diagonals from each corner.
    // A smooth max agrees with it on the diagonal and away from it, and rounds the
    // crease off; the edge itself and its true corner radius are untouched.
    float k = max(ubuf.rimWidth, 1.0);
    float smax = 0.5 * (q.x + q.y + sqrt((q.x - q.y) * (q.x - q.y) + k * k)) - 0.5 * k;
    return length(max(q, 0.0)) + min(smax, 0.0) - rad;
}

// The distance used for the glow: inside a window, minus the depth below its
// edge (first window in the list wins); outside all of them, the distance to
// the nearest. Windows are listed topmost first.
float field(vec2 px) {
    float s0 = winSd(ubuf.win0, px);
    float s1 = winSd(ubuf.win1, px);
    float s2 = winSd(ubuf.win2, px);
    float s3 = winSd(ubuf.win3, px);
    float s4 = winSd(ubuf.win4, px);
    float s5 = winSd(ubuf.win5, px);
    if (s0 < 0.0) return s0;
    if (s1 < 0.0) return s1;
    if (s2 < 0.0) return s2;
    if (s3 < 0.0) return s3;
    if (s4 < 0.0) return s4;
    if (s5 < 0.0) return s5;
    return min(min(min(s0, s1), min(s2, s3)), min(s4, s5));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * ubuf.resolution;
    float w = ubuf.rimWidth;

    // Almost every pixel is nowhere near an edge, and stops here.
    float sd = field(px);
    if (sd > 1.6 * w || sd < -3.6 * w) {
        fragColor = vec4(0.0);
        return;
    }
    bool inside = sd < 0.0;
    // Outside a window, keep out of the bars' reserved strips.
    vec4 us = ubuf.usable;
    if (!inside && (px.x < us.x || px.y < us.y || px.x > us.x + us.z || px.y > us.y + us.w)) {
        fragColor = vec4(0.0);
        return;
    }

    float aspect = ubuf.resolution.x / max(ubuf.resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);
    vec2 fan = fanField(p, aspect, ubuf.time, ubuf.seed);

    // Depth below the edge, in band widths: positive inside, negative outside.
    float u = -sd / w;
// Light hugs the edge and dissolves inward: a sharp-ish start, then a long smooth
    // tail with no kink and no end that shows. The halo outside is tighter and weaker.
    float prof = inside ? (0.45 * exp(-u * 1.3) + 0.55 * exp(-u * u / 1.9)) * (1.0 - smoothstep(2.0, 3.4, u))
                        : 0.65 * exp(-(-u) * 4.0);
    // A faint ambient so no edge is ever completely dark.
    // sqrt spreads the lit region out, so its boundary is a slow gradient and not a wedge.
    float strength = 0.30 + 0.70 * sqrt(fan.y);
    // The prism: hue sweeps through the spectrum across the width of the band.
    vec3 col = lightSpectrum(clamp(fan.x + 0.06 * clamp(u, -1.0, 1.5), 0.0, 1.0));
    // A thin bright line right at the edge, like the bright rim of a piece of glass.
    float edge = exp(-(u / 0.20) * (u / 0.20)) * 0.12;

    vec3 rgb = (col * prof + AQUA * edge) * strength * 1.7;

    // The bright spots, shown only near an edge and faded to nothing before the limits above.
    float nearEdge = exp(-abs(sd) / (1.3 * w))
        * (inside ? 1.0 - smoothstep(1.4, 2.4, -sd / w) : 1.0 - smoothstep(0.9, 1.6, sd / w));
    rgb += glints(px, w, ubuf.time, ubuf.seed) * nearEdge * 1.5;

    vec4 acc = vec4(rgb, 0.0) * (ubuf.intensity * 2.0);
    // Roll bright peaks off smoothly instead of clipping them. A spot that is cut off
    // flat at the maximum has a visible edge where it drops below the clip, and reads
    // as a hard-edged disc; this leaves low values almost alone and approaches the
    // maximum gradually.
    acc.rgb = 1.0 - exp(-acc.rgb);
    if (ubuf.additive < 0.5) acc.a = max(acc.r, max(acc.g, acc.b));
    acc = clamp(acc, 0.0, 1.0);
    fragColor = acc * ubuf.qt_Opacity;
}
