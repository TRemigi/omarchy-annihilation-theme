#version 440

// The screensaver: the wallpaper, slowly taken. `time` is seconds since the
// screensaver appeared. The photo is dimmed to `brightness` of itself, then
// over two minutes it warps like heat over water, its colour channels drift
// apart, and a Voronoi lattice of cells (the refracted organism dividing)
// glows faintly along its seams. The image is cropped to cover the screen,
// not stretched: `imageAspect` is its width over height. Rebuild with
// shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    float imageAspect;
    float brightness;
    vec4 tealColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;

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

// x: distance to the nearest cell centre, y: gap to the second nearest (0 on a
// seam), z: a per-cell random value. Centres drift slowly.
vec3 cells(vec2 p, float t) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float d1 = 8.0;
    float d2 = 8.0;
    float id = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 o = vec2(float(i), float(j));
            vec2 h = hash22(g + o);
            vec2 pt = o + 0.5 + 0.4 * sin(t * 0.05 + 6.2831853 * h);
            float d = length(pt - f);
            if (d < d1) {
                d2 = d1;
                d1 = d;
                id = hash12(g + o);
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    return vec3(d1, d2 - d1, id);
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

    float on = smoothstep(15.0, 100.0, t);
    vec3 c = cells(p * 3.5, t);
    float seam = 1.0 - smoothstep(0.0, 0.04, c.y);
    col *= 1.0 + (c.z - 0.5) * 0.25 * on;
    col += ubuf.tealColor.rgb * seam * 0.1 * on;

    float edge = length((uv - 0.5) * vec2(aspect * 0.6, 1.0));
    float vignette = 1.0 - smoothstep(0.35, 1.1, edge);
    col *= mix(0.6, 1.0, vignette);

    float fadeIn = smoothstep(0.0, 3.0, t);
    fragColor = vec4(col * fadeIn, 1.0) * ubuf.qt_Opacity;
}
