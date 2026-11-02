#version 440

// The passage as a living thing. The text, drawn white into `source`, is not
// painted: it is made. Every stroke is packed with tiny hand-shaped creatures (a
// palm and five fingers), in two overlapping layers of a slightly tilted grid, so
// the letters look built of them and the hands spill a little over the edge. Each
// points away from the nearest edge (any way in the thick of a stroke) and waves
// its fingers on its own slow rhythm. Their light is bioluminescent: broad swells
// drift slowly through the words, and now and then one creature flashes on its
// own and fades. A dim body fills the strokes behind them so there are no black
// gaps. Once per part, at one point on the strokes, the creatures near it flare and
// release a few spores, which rise and drift away and go out. `sporeAge` is
// seconds since the release (negative before it); `seed` makes every part
// release somewhere else. Nothing here is on a schedule except that one event.
//
// `cell` is the creature's size in pixels (a hand is about one cell across) and is
// independent of the type size, so the letters can be as big as they like. `unit` is
// the scale of the motions and spores, in pixels, likewise independent. `dims` is the
// texture's size, `bounds` the rectangle x0, y0, x1, y1 holding the text inside the
// texture's padding, where a release may start. The padding must be big enough for the
// spores to rise into. Rebuild with shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 dims;
    float unit;
    float seed;
    float sporeAge;
    float cell;
    vec4 bounds;
    vec4 tint;
    vec4 coreTint;
    vec4 sporeTint;
} ubuf;

layout(binding = 1) uniform sampler2D source;
// A blurred copy of the same words, made by the plugin, for the glow (see main).
layout(binding = 2) uniform sampler2D glowTex;

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

float mask(vec2 px) {
    return texture(source, px / ubuf.dims).a;
}

// How much of the disc of radius r round q is letter (x), and which way the
// letters lie (yz, a vector pointing into them, from nine taps).
vec3 around(vec2 q, float r) {
    float s = mask(q) * 2.0;
    vec2 g = vec2(0.0);
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.7853982;
        vec2 d = vec2(cos(a), sin(a));
        float m = mask(q + d * r);
        s += m;
        g += d * m;
    }
    return vec3(s / 10.0, g * 0.25);
}

float segment(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

// One hand, in the cell's own frame (the cell is one unit across, centred on
// the origin), reaching along +x. `wave` swings the fingers, each a little
// out of step with the others, as if groping.
float hand(vec2 q, float wave, float aa) {
    vec2 palm = vec2(-0.27, 0.0);
    float d = length(q - palm) - 0.19;
    for (int k = 0; k < 5; k++) {
        float fk = float(k) - 2.0;
        float ang = fk * 0.34 + 0.26 * sin(wave + fk * 0.9);
        vec2 dir = vec2(cos(ang), sin(ang));
        float len = 0.74 - 0.12 * abs(fk) + 0.05 * sin(wave * 0.7 + fk * 1.7);
        d = min(d, segment(q, palm + dir * 0.12, palm + dir * len, 0.07));
    }
    return 1.0 - smoothstep(-aa, aa, d);
}

// The swells of light that drift through the words: broad ones, a few words across, that
// come and go over ten seconds or so.
float swell(vec2 q) {
    float t = ubuf.time;
    float w = vnoise(q / (ubuf.unit * 5.0) + vec2(t * 0.13, -t * 0.08)) * 0.65
            + vnoise(q / (ubuf.unit * 1.9) + vec2(-t * 0.18, t * 0.07) + 11.7) * 0.35;
    return smoothstep(0.30, 0.70, w);
}

// And a quicker shimmer on top: clusters of a handful of creatures that brighten together
// for a second or two and let go, sparkling over the surface of the words.
float shimmer(vec2 q) {
    float t = ubuf.time;
    float n = vnoise(q / (ubuf.unit * 0.9) + vec2(t * 0.34, -t * 0.26) + 37.1) * 0.6
            + vnoise(q / (ubuf.unit * 0.45) + vec2(-t * 0.60, t * 0.17) + 5.3) * 0.4;
    return smoothstep(0.50, 0.80, n);
}

// One tilted layer of creatures: premultiplied light in rgb, coverage in a. A cell
// holds a hand if it lies on or near a stroke.
vec4 creatures(vec2 p, float tilt, vec2 shift, float salt, vec2 origin, float released) {
    float c = ubuf.cell;
    float u = ubuf.unit;
    float t = ubuf.time;
    mat2 R = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt));
    vec2 pr = R * p + shift * c;
    vec2 id = floor(pr / c);
    vec2 f = fract(pr / c) - 0.5;
    vec2 cc = transpose(R) * ((id + 0.5) * c - shift * c);

    vec3 fld = around(cc, c * 0.6);
    vec2 h = hash22(id + ubuf.seed * 17.0 + salt);
    float hh = hash12(id * 1.31 + 9.1 + salt);
    // Thinned at random, and never where there is nothing near (h.x can be 0 exactly).
    float present = step(h.x + 1e-3, smoothstep(0.03, 0.2, fld.x));

    // They reach out from the letters; inside a thick stroke, any way.
    float gl = length(fld.yz);
    float a0 = h.y * 6.2831853;
    vec2 away = mix(vec2(cos(a0), sin(a0)), -fld.yz / max(gl, 1e-4), smoothstep(0.01, 0.08, gl));
    float jr = (h.y - 0.5) * 1.0;
    away = vec2(away.x * cos(jr) - away.y * sin(jr), away.x * sin(jr) + away.y * cos(jr));
    vec2 ur = R * normalize(away);
    vec2 q = vec2(dot(f, ur), dot(f, vec2(-ur.y, ur.x)));
    float cover = hand(q, t * (0.55 + 0.5 * hh) + h.y * 6.2831853, 1.2 / c);

    float sw = swell(cc);
    float tw = pow(0.5 + 0.5 * sin(t * (0.9 + 1.8 * h.y) + hh * 40.0), 4.0);
    // Never dimmer than the body behind them, or in a dim swell the hands melt into it; the
    // floor is high enough that the dimmest words are still plainly alive.
    float lum = 0.46 + 0.30 * sw + 0.36 * shimmer(cc) + 0.55 * tw * (0.40 + 0.60 * sw);

    // The creatures round the release flare as it happens.
    if (released > 0.0) {
        vec2 d = cc - origin;
        lum += exp(-dot(d, d) / (1.4 * u * u)) * exp(-max(ubuf.sporeAge, 0.0) / 1.4)
             * smoothstep(-0.3, 0.0, ubuf.sporeAge) * 1.1;
    }

    vec3 col = mix(ubuf.tint.rgb, ubuf.coreTint.rgb, clamp((lum - 0.4) * 1.4, 0.0, 1.0));
    col = mix(col, vec3(0.78, 0.42, 0.66), step(hh, 0.04) * 0.55);
    float a = cover * present;
    return vec4(col * lum * a, a);
}

void main() {
    float u = ubuf.unit;
    vec2 p = qt_TexCoord0 * ubuf.dims;

    // Where the spores start: the first of up to sixty-four random points in the
    // text's box that lies on a stroke (every pixel finds the same one, so the
    // search stops early). None on a stroke, no release.
    vec2 origin = vec2(0.0);
    float released = 0.0;
    if (ubuf.sporeAge > -0.5 && ubuf.sporeAge < 14.0) {
        for (int j = 0; j < 64; j++) {
            vec2 hj = hash22(vec2(ubuf.seed * 3.1 + float(j) * 1.37, 5.3));
            vec2 o = mix(ubuf.bounds.xy, ubuf.bounds.zw, hj);
            if (mask(o) > 0.35) {
                origin = o;
                released = 1.0;
                break;
            }
        }
    }

    // Two layers of creatures, tilted differently and offset, so they overlap and fill.
    vec4 la = creatures(p, 0.38, vec2(0.0), 0.0, origin, released);
    vec4 lb = creatures(p, -0.55, vec2(0.37, 0.61), 31.0, origin, released);
    // The second layer sits a little behind, so overlapping hands can be told apart.
    vec3 rgb = la.rgb + lb.rgb * 0.72 * (1.0 - la.a);

    // The body behind them, and a faint swelling light round the words.
    float m0 = mask(p);
    rgb += ubuf.tint.rgb * m0 * 0.10 * (0.7 + 0.6 * swell(p)) * (1.0 - la.a);
    // The glow is the blurred copy, lit by the same swell that lights the hands, so where the
    // hands dim the glow dims with them. A fixed glow made dim words look blurred.
    float sp0 = clamp(swell(p) + 0.5 * shimmer(p), 0.0, 1.0);
    rgb += ubuf.tint.rgb * texture(glowTex, qt_TexCoord0).a * (0.22 + 0.78 * sp0 * sp0) * 0.85;

    // Spores: a few, from one point, rising and wandering off.
    if (released > 0.0) {
        vec3 sp = vec3(0.0);
        for (int i = 0; i < 7; i++) {
            float fi = float(i);
            vec2 hs = hash22(vec2(ubuf.seed * 3.7 + fi, 2.9));
            float a = ubuf.sporeAge - (fi * 0.45 + hs.x * 0.3);
            if (a > 0.0 && a < 9.0) {
                vec2 pos = origin + u * vec2((hs.x - 0.5) * 0.55 * sqrt(a) + 0.25 * sin(a * 0.55 + fi * 2.1),
                                             -(0.22 + 0.16 * hs.y) * a);
                float s = ubuf.cell * (0.14 + 0.09 * hs.y);
                vec2 d = p - pos;
                float r2 = dot(d, d);
                float env = smoothstep(0.0, 1.0, a) * (1.0 - smoothstep(5.5, 9.0, a))
                          * (0.7 + 0.3 * sin(a * 1.9 + fi * 3.0));
                sp += ubuf.sporeTint.rgb * (exp(-r2 / (2.0 * s * s)) + 0.12 * exp(-r2 / (32.0 * s * s))) * env;
            }
        }
        rgb += sp * 1.3;
    }

    rgb = clamp(rgb, 0.0, 1.0);
    float alpha = max(max(rgb.r, rgb.g), rgb.b);
    fragColor = vec4(rgb, alpha) * ubuf.qt_Opacity;
}
