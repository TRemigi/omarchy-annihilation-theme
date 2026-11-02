#version 440

// The screensaver: the wallpaper, slowly taken. `time` is seconds since the
// screensaver appeared. The photo is dimmed to `brightness` of itself, then
// over two minutes it warps like heat over water, its colour channels drift
// apart, and a fungus grows in from the edges of the screen, keeping to the
// background and away from the middle, where the words are:
//   - pale root-like veins, drawn by veins.js into the `veins` texture (red: how
//     far along its vein a pixel is, green: thickness, blue: a tint; alpha:
//     coverage). They are revealed along their length, each with a faint lit tip.
//   - patches of mould, olive and moss with yellow spots and a little purple,
//     that spread inward from the edges and gather round the veins.
// The image is cropped to cover the screen, not stretched: `imageAspect` is its
// width over height. Rebuild with shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    float imageAspect;
    float brightness;
    float seed;
    vec4 tealColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D veins;

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

// One vein sample: x how far along its vein, y thickness, z tint, w coverage. The
// canvas holds premultiplied colour, so divide the coverage back out.
vec4 veinAt(vec2 uv) {
    vec4 v = texture(veins, uv);
    return vec4(v.rgb / max(v.a, 1e-3), v.a);
}

// Coverage of the veins that have grown by now, at uv; `front` is how far along their
// length every vein has got (0 to 1).
float grownAt(vec2 uv, float front) {
    vec4 v = veinAt(uv);
    return v.w * smoothstep(0.0, 0.012, front - v.x);
}

// Where the image sits under a screen coordinate when it is scaled to cover the
// screen and centred, as Image.PreserveAspectCrop would draw it. A shader
// sampling an Image gets the whole texture whatever the item's fillMode says.
vec2 cover(vec2 uv, float screenAspect) {
    float ia = max(ubuf.imageAspect, 0.01);
    vec2 c = uv - 0.5;
    if (ia > screenAspect) c.x *= screenAspect / ia;
    else c.y *= ia / screenAspect;
    return c + 0.5;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.resolution.x / max(ubuf.resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);
    float t = ubuf.time;

    float grow = smoothstep(0.0, 120.0, t);

    vec2 n = vec2(fbm(p * 2.5 + t * 0.03), fbm(p * 2.5 + 11.3 - t * 0.025)) - 0.5;
    vec2 wuv = uv + n * 0.03 * grow;

    vec2 dir = normalize(uv - 0.5 + vec2(1e-4));
    float sep = 0.004 * grow;
    vec3 col = vec3(texture(source, cover(wuv + dir * sep, aspect)).r,
                    texture(source, cover(wuv, aspect)).g,
                    texture(source, cover(wuv - dir * sep, aspect)).b);

    // Dim the photograph first, so the seams below stay as bright as they are.
    // Dimmed from the first frame: the fade-in below runs black to the dark
    // image, never passing through the photo at full brightness.
    col *= ubuf.brightness;

    // How far along their length the veins have got, and how far in from the edges the mould has.
    float front = clamp((t - 3.0) / 105.0, 0.0, 1.0) * 1.04;
    float reach = smoothstep(8.0, 140.0, t) * 0.34;

    vec2 sp = p + ubuf.seed * 3.7;
    float body = fbm(sp * 3.0);
    float fine = fbm(sp * 26.0);

    // Where the words are: nothing grows there. The edge of that is wobbled by the noise, so
    // it is not a rectangle.
    vec2 bq = max(abs(uv - 0.5) - vec2(0.40, 0.15), 0.0);
    float bd = length(bq) + (body - 0.45) * 0.14;
    float zone = smoothstep(0.0, 0.12, bd);
    float zoneV = smoothstep(0.0, 0.05, bd);

    // Mould first, so the veins lie over it. It starts at the edges (the reach is a distance in
    // screen heights from the nearest edge), where the noise lets it, in patches with bare wall
    // between, and gathers round veins.
    float dEdge = min(min(uv.x * aspect, (1.0 - uv.x) * aspect), min(uv.y, 1.0 - uv.y));
    float prox = grownAt(uv, front);
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.7853982;
        prox += grownAt(uv + 0.03 * vec2(cos(a) / aspect, sin(a)), front);
    }
    prox = clamp(prox * 0.45, 0.0, 1.0);
    float edgeTerm = min((reach - dEdge) * 2.0, 0.35);
    float pot = (body - 0.5) * 2.4 + edgeTerm + prox * 0.8 - 0.2 + (fine - 0.45) * 0.30;
    float mould = smoothstep(0.0, 0.10, pot) * zone;

    // Olive and moss, with lichen-yellow stretches.
    float lichen = smoothstep(0.52, 0.72, fbm(sp * 7.0 + 21.0));
    vec3 mouldCol = mix(vec3(0.15, 0.19, 0.05), vec3(0.46, 0.50, 0.16), smoothstep(0.25, 0.65, fine));
    mouldCol = mix(mouldCol, vec3(0.50, 0.50, 0.12), lichen * 0.55);

    // Yellow spots in clumps, not on a grid: a jittered grid of two sizes, each cell's spot
    // present only where a clumping noise says so, and different in size from its neighbours.
    float clump = smoothstep(0.40, 0.60, fbm(sp * 9.0 + 5.0));
    for (int k = 0; k < 2; k++) {
        float sc = k == 0 ? 34.0 : 78.0;
        vec2 gp = sp * sc;
        vec2 gi = floor(gp);
        vec2 gf = fract(gp) - 0.5 - (hash22(gi + float(k) * 17.0) - 0.5) * 0.6;
        float roll = hash12(gi + ubuf.seed + float(k) * 3.0);
        float rad = 0.14 + 0.24 * hash12(gi * 1.7 + 4.0);
        float spot = (1.0 - smoothstep(rad * 0.5, rad, length(gf))) * step(0.45, roll) * clump;
        mouldCol = mix(mouldCol, vec3(0.88, 0.76, 0.14), spot * (k == 0 ? 0.95 : 0.7));
    }
    // The odd purple lump.
    {
        vec2 gp = sp * 20.0;
        vec2 gi = floor(gp);
        vec2 gf = fract(gp) - 0.5 - (hash22(gi + 9.0) - 0.5) * 0.5;
        float lump = (1.0 - smoothstep(0.15, 0.40, length(gf))) * step(hash12(gi + 2.0), 0.035);
        mouldCol = mix(mouldCol, vec3(0.28, 0.12, 0.34), lump * 0.8);
    }
    col = mix(col, mouldCol * 0.50, mould * 0.85);

    // Veins: pale, a little raised (lit from the upper left), their growing tips faintly lit.
    vec4 vv = veinAt(uv);
    float arrived = front - vv.x;
    float vein = vv.w * smoothstep(0.0, 0.012, arrived) * zoneV;
    float lit = grownAt(uv - vec2(2.0, 2.5) / ubuf.resolution, front);
    float relief = clamp((vein - lit * zoneV) * 2.0, -1.0, 1.0);
    vec3 pale = mix(vec3(0.46, 0.52, 0.46), vec3(0.78, 0.80, 0.68), clamp(vv.y * 2.0, 0.0, 1.0));
    pale = mix(pale, vec3(0.62, 0.48, 0.56), step(0.9, vv.z) * 0.5);
    col = mix(col, pale * 0.42, vein * 0.9);
    col += pale * relief * 0.07;
    float tip = vv.w * zoneV * smoothstep(0.0, 0.004, arrived) * (1.0 - smoothstep(0.0, 0.04, arrived)) * step(front, 1.0);
    col += vec3(0.60, 0.62, 0.40) * tip * 0.20;

    float edge = length((uv - 0.5) * vec2(aspect * 0.6, 1.0));
    float vignette = 1.0 - smoothstep(0.35, 1.1, edge);
    col *= mix(0.6, 1.0, vignette);

    float fadeIn = smoothstep(0.0, 3.0, t);
    fragColor = vec4(col * fadeIn, 1.0) * ubuf.qt_Opacity;
}
