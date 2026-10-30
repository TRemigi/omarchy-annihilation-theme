#version 440

// Fades the crawl in and out near the two ends of the screen. Used as the layer
// effect of Crawl's strip, so `source` is the rendered strip. Fully transparent
// for the outer `inset` of the width at each end, a smooth ramp `ramp` wide
// inside that, opaque between. Rebuild with shaders/build-shaders.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float inset;
    float ramp;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    float x = qt_TexCoord0.x;
    float rise = smoothstep(ubuf.inset, ubuf.inset + ubuf.ramp, x);
    float fall = 1.0 - smoothstep(1.0 - ubuf.inset - ubuf.ramp, 1.0 - ubuf.inset, x);
    // The source is premultiplied, so scaling the whole colour scales its alpha.
    fragColor = texture(source, qt_TexCoord0) * rise * fall * ubuf.qt_Opacity;
}
