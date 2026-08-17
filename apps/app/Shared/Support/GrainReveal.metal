#include <metal_stdlib>
using namespace metal;

// Cheap hash noise. The seed steps in coarse increments of the reveal
// progress so the grain re-rolls a few times per second like StaticField's
// 12fps tiles, instead of shimmering at display rate.
static float hash21(float2 p, float seed) {
    p = fract(p * float2(123.34, 456.21) + seed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Dissolves a view in through its own pixels: covered pixels are either
// dropped or replaced with static, so the grain lives only inside the
// glyphs and never paints the ground behind them.
[[ stitchable ]] half4 grainReveal(float2 position, half4 color, float progress) {
    if (progress >= 1.0 || color.a <= 0.001) { return color; }
    // Grain in ~0.5pt cells: per-pixel noise on a Retina screen averages out
    // to a plain grey and the whole thing reads as a fade.
    float2 cell = floor(position / 0.5);
    // Progress lands in coarse steps: a continuous dissolve of fine grain
    // averages into a smooth fade, and the steps are what read as a signal
    // locking on rather than a gradient.
    float locked = floor(progress * 6.0) / 6.0;
    float seed = floor(progress * 8.0);
    float roll = hash21(cell, seed);
    if (roll <= locked) { return color; }
    if (hash21(cell + 17.0, seed) > 0.5) { return half4(0.0); }
    // Static in the glyph's own colour, not white: brand-red titles would
    // otherwise flash grey-white grain before settling red.
    float level = hash21(cell + 41.0, seed * 1.7 + 3.0);
    return half4(color.rgb * half(0.4 + level * 0.6), color.a);
}
