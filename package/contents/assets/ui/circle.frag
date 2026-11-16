#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float diameter;
    float feather;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * ubuf.diameter;
    float r = ubuf.diameter * 0.5 - 0.5;
    float a = clamp((r - length(p)) / ubuf.feather + 0.5, 0.0, 1.0);
    fragColor = texture(source, qt_TexCoord0) * a * ubuf.qt_Opacity;
}
