#version 440
// Liquid Glass edge light, after the liquid-glass GNOME extension's glass.frag (rim + inner AO part):
// a thin rim lit where the edge faces the light (top and bottom by default), fading through the
// corners to nothing on the sides, and a 1px inner shadow where the rim is dark. No uniform border.
// Rebuild after editing: qsb --qt6 -o glassrim.frag.qsb glassrim.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // px
    float radius;     // px
    float rimWidth;   // px
    float rimIntensity;
    float rimPower;   // directional falloff
    float aoIntensity;
    float aoRadius;   // px
    float lightAngle; // radians, screen space (y down); pi/2 lights top and bottom
};

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    vec2 b = size * 0.5;
    float r = min(radius, min(b.x, b.y));
    float d = sdRoundRect(p, b, r);
    // Outward normal from the distance field's gradient.
    float e = 0.5;
    vec2 n = normalize(vec2(sdRoundRect(p + vec2(e, 0.0), b, r) - sdRoundRect(p - vec2(e, 0.0), b, r),
                            sdRoundRect(p + vec2(0.0, e), b, r) - sdRoundRect(p - vec2(0.0, e), b, r)) + 1e-6);
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);
    vec2 L = vec2(cos(lightAngle), sin(lightAngle));
    float lightMask = pow(abs(dot(n, L)), rimPower);
    float band = 1.0 - smoothstep(0.0, rimWidth, -d);
    float rim = pow(band, 0.85) * lightMask * rimIntensity * inside;
    float ao = (1.0 - smoothstep(0.0, aoRadius, -d)) * aoIntensity * (1.0 - lightMask) * inside;
    // Premultiplied: white light over a black inner shadow.
    float a = rim + ao * (1.0 - rim);
    fragColor = vec4(vec3(rim), a) * qt_Opacity;
}
