// ===============================================================================================
// PS1 effect full-screen post-processing shader
// Emulates the dithering and color quantization style of the original PlayStation.
// ===============================================================================================

shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float dither_strength : hint_range(0.0, 1.0, 0.05) = 1.0;

const float BAYER[16] = float[16](
0.0, 8.0, 2.0, 10.0,
12.0, 4.0, 14.0, 6.0,
3.0, 11.0, 1.0, 9.0,
15.0, 7.0, 13.0, 5.0
);

void fragment()
{
    vec4 out_color = textureLod(screen_texture, SCREEN_UV, 0.0);

    ivec2 pixel = ivec2(FRAGCOORD.xy);
    int index =(pixel.y % 4) * 4 +(pixel.x % 4);
    float dither =(BAYER[index] + 0.5) / 16.0 - 0.5;

    out_color.rgb = clamp(
    out_color.rgb + dither * dither_strength / 31.0,
    0.0,
    1.0
    );
    out_color.rgb = round(out_color.rgb * 31.0) / 31.0;

    COLOR = out_color;
}
