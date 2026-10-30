#version 440

// A notification arrives: light spreads off the toast and fades.
//
// Drawn in a layer above the windows and under the toast overlay (so the card itself hides
// the middle of it), anchored to where toasts land, top right. Two parts per arrival:
//
//   a ring    a soft wavefront that leaves the card's outline and travels outward, widening and
//             dimming as it goes. Colour shifts a little across its width, the way the edge of a
//             prism splits light: inside it is the arrival's own colour, outside it drifts on
//             toward its neighbour. Only a slice of the spectrum, so neighbouring colours blend.
//   a halo    a wide, soft lamp-glow round the card that swells and settles more slowly.
//
// Everything is radially symmetric about the card (distance from a rounded box, not an angle),
// because anything with rays or angle structure reads as a projected beam. The ring's radius is
// bent a few per cent by slow smooth sines of position, so it is not a perfect circle. Nothing
// is selected with a comparison between fields; the one branch is on the arrival's urgency,
// which is constant over the whole screen.
//
// Up to three arrivals at once (ev0..ev2): x = progress 0..1 (outside that range it is off),
// y = urgency (0 low, 1 normal, 2 critical), z = amplitude, w = a per-arrival salt for the bend.
// Output is added light (colour above alpha, as in windowglow.frag), tone-mapped with
// 1 - exp(-x), and `additive` off falls back to ordinary blending.
// Rebuild with shaders/build-shaders.sh after editing.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float seed;
    float strength;
    float additive;
    float reach;      // how far the ring travels from the card's outline, in pixels
    vec2 resolution;
    vec2 origin;      // centre of the card
    vec2 box;         // half width and half height of the light's source, narrower than the card
    vec4 ev0;
    vec4 ev1;
    vec4 ev2;
} ubuf;

// Light colours: the arrival's own colour inside the ring, what it drifts toward outside it.
// Normal is teal to blue, critical amber to pink, low moss to teal.
const vec3 N_IN = vec3(0.2000, 0.7686, 0.8157);
const vec3 N_OUT = vec3(0.4400, 0.4600, 0.9800);
const vec3 C_IN = vec3(0.9569, 0.6200, 0.1800);
const vec3 C_OUT = vec3(0.9490, 0.4784, 0.7000);
const vec3 L_IN = vec3(0.5300, 0.6900, 0.4200);
const vec3 L_OUT = vec3(0.2800, 0.6800, 0.7000);

// Distance from a rounded box centred on the origin; negative inside.
float boxDistance(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - (half_ - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 arrival(vec2 px, vec4 ev, float dist0) {
    float p = ev.x;
    if (p <= 0.0 || p >= 1.0) return vec3(0.0);

    vec3 inner = N_IN;
    vec3 outer = N_OUT;
    if (ev.y > 1.5) { inner = C_IN; outer = C_OUT; }
    else if (ev.y < 0.5) { inner = L_IN; outer = L_OUT; }

    // A few per cent of bend in the radius, smooth in position, so the ring is not a circle.
    vec2 d = (px - ubuf.origin) / ubuf.reach;
    float bend = 1.0 + 0.06 * sin(d.x * 2.3 + ubuf.seed * 3.1 + ev.w) * sin(d.y * 2.9 + ubuf.seed * 1.7 + 2.0 * ev.w);
    float dist = dist0 * bend;

    // The ring: leaves the outline quickly and slows, widening as it goes.
    float travel = 1.0 - pow(1.0 - p, 3.0);
    float r = ubuf.reach * (0.04 + 0.96 * travel);
    float w = ubuf.reach * (0.06 + 0.11 * travel);
    float s = (dist - r) / w;
    float ring = exp(-0.5 * s * s) * (1.0 - smoothstep(3.2, 4.2, abs(s)));
    float ringLife = smoothstep(0.0, 0.07, p) * (1.0 - p) * (1.0 - p);
    vec3 ringCol = mix(inner, outer, smoothstep(-1.2, 1.6, s));

    // The halo: a lamp-glow round the card, slower to rise and to leave.
    float sigma = ubuf.reach * 0.22;
    float h = dist / sigma;
    float halo = exp(-0.5 * h * h) * (1.0 - smoothstep(2.4, 3.4, h));
    float haloLife = smoothstep(0.0, 0.14, p) * pow(1.0 - p, 1.5);
    vec3 haloCol = mix(inner, vec3(1.0, 0.95, 0.88), 0.10);

    return (ringCol * ring * ringLife * 0.30 + haloCol * halo * haloLife * 0.15) * ev.z;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.resolution;
    // Outside the source only; inside it the distance is held at zero. The source is a box narrower
    // than the card, so that the ring is a stadium that rounds off soon, not the card's long outline.
    float dist0 = max(boxDistance(px - ubuf.origin, ubuf.box, 8.0), 0.0);

    vec3 rgb = arrival(px, ubuf.ev0, dist0) + arrival(px, ubuf.ev1, dist0) + arrival(px, ubuf.ev2, dist0);
    // Roll peaks off instead of clipping them.
    rgb = 1.0 - exp(-rgb * ubuf.strength * 2.0);

    vec4 acc = vec4(rgb, 0.0);
    if (ubuf.additive < 0.5) acc.a = max(acc.r, max(acc.g, acc.b));
    acc = clamp(acc, 0.0, 1.0);
    fragColor = acc * ubuf.qt_Opacity;
}
