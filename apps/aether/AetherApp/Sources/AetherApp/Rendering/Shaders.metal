#include <metal_stdlib>
using namespace metal;

// Vertex input for each glyph instance
struct GlyphInstance {
    float2 position;      // Screen position (normalized)
    float2 size;          // Glyph size
    float2 texCoord;      // Atlas UV origin
    float2 texSize;       // Atlas UV size
    float4 fgColor;       // Foreground RGBA
    float4 bgColor;       // Background RGBA
    uint flags;           // Bold, underline, etc. + Bit 31 for Powerline
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float2 localPos;      // 0..1 across the quad
    float4 fgColor;
    float4 bgColor;
    uint flags;
};

// Quad vertices (instanced)
constant float2 quadVertices[] = {
    float2(0, 0), float2(1, 0), float2(0, 1),
    float2(1, 0), float2(1, 1), float2(0, 1)
};

vertex VertexOut vertex_main(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant GlyphInstance* instances [[buffer(0)]],
    constant float2& viewportSize [[buffer(1)]]
) {
    GlyphInstance inst = instances[instanceID];
    float2 quadPos = quadVertices[vertexID];

    // Calculate screen position
    float2 pos = inst.position + quadPos * inst.size;
    pos = pos / viewportSize * 2.0 - 1.0;
    pos.y = -pos.y;  // Flip Y

    VertexOut out;
    out.position = float4(pos, 0, 1);
    out.texCoord = inst.texCoord + quadPos * inst.texSize;
    out.localPos = quadPos;
    out.fgColor = inst.fgColor;
    out.bgColor = inst.bgColor;
    out.flags = inst.flags;
    return out;
}

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]]
) {
    // Bit 31 set -> Procedural Powerline Shape
    if ((in.flags & 0x80000000) != 0) {
        // Shape ID in bits 28-30
        uint shape = (in.flags >> 28) & 0x7;
        float2 p = in.localPos;
        float dist = abs(p.y - 0.5);

        // 0: Right Arrow Filled (0xE0B0)
        // Triangle pointing right: base at x=0, tip at x=1
        if (shape == 0) {
            if (p.x > 1.0 - 2.0 * dist) discard_fragment();
            return in.fgColor;
        }

        // 1: Right Arrow Thin (0xE0B1) - Chevron
        if (shape == 1) {
            float xr = 1.0 - 2.0 * dist;
            // Draw line around xr
            // This is pixel-width dependent, tricky in UV space without derivatives
            // Approximation:
            if (p.x > xr || p.x < xr - 0.1) discard_fragment();
            return in.fgColor;
        }

        // 2: Left Arrow Filled (0xE0B2)
        // Triangle pointing left: base at x=1, tip at x=0
        if (shape == 2) {
            if (p.x < 2.0 * dist) discard_fragment();
            return in.fgColor;
        }

        // 3: Left Arrow Thin (0xE0B3)
        if (shape == 3) {
            float xl = 2.0 * dist;
            if (p.x < xl || p.x > xl + 0.1) discard_fragment();
            return in.fgColor;
        }

        return in.fgColor;
    }

    // Nearest-neighbor sampling for pixel-perfect glyph rendering at native resolution.
    // Glyphs are pre-rasterized at exact Retina scale, so no interpolation is needed.
    constexpr sampler s(mag_filter::nearest, min_filter::nearest);
    float4 texel = atlas.sample(s, in.texCoord);

    // The atlas stores white-on-black BGRA glyphs. The RGB channels contain
    // per-channel font coverage (subpixel AA data on older macOS, identical
    // grayscale values on macOS 10.14+). Use the red channel as alpha —
    // this is correct for both grayscale and subpixel smoothing modes.
    float alpha = texel.r;

    // Blend foreground over background
    return mix(in.bgColor, in.fgColor, alpha);
}
