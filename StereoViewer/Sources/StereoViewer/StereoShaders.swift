// Shaders are compiled at runtime so the package needs no resource bundle setup.
enum StereoShaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct Vertex { float3 position; float3 normal; };

    struct FrameUniforms {
        float4x4 viewProjection;
        float4 lightDir;   // xyz: direction light travels
        float4 cameraPos;
        float4 fog;        // rgb: color, w: density
    };

    struct NodeUniforms {
        float4x4 model;
        float4 color;
        float4 params;     // x: checker on, y: tile size
    };

    struct VOut {
        float4 position [[position]];
        float3 worldPos;
        float3 normal;
    };

    vertex VOut scene_vertex(uint vid [[vertex_id]],
                             const device Vertex* verts [[buffer(0)]],
                             constant FrameUniforms& frame [[buffer(1)]],
                             constant NodeUniforms& node [[buffer(2)]]) {
        Vertex v = verts[vid];
        float4 world = node.model * float4(v.position, 1.0);
        VOut o;
        o.position = frame.viewProjection * world;
        o.worldPos = world.xyz;
        o.normal = (node.model * float4(v.normal, 0.0)).xyz;
        return o;
    }

    fragment float4 scene_fragment(VOut in [[stage_in]],
                                   constant FrameUniforms& frame [[buffer(1)]],
                                   constant NodeUniforms& node [[buffer(2)]]) {
        float3 base = node.color.rgb;
        if (node.params.x > 0.5) {
            float2 c = floor(in.worldPos.xz / node.params.y);
            float k = fmod(abs(c.x + c.y), 2.0);
            base *= mix(0.6, 1.0, k);
        }
        float3 n = normalize(in.normal);
        float3 l = normalize(-frame.lightDir.xyz);
        float diff = max(dot(n, l), 0.0);
        float3 v = normalize(frame.cameraPos.xyz - in.worldPos);
        float3 h = normalize(l + v);
        float spec = pow(max(dot(n, h), 0.0), 32.0) * 0.2;
        float3 color = base * (0.3 + 0.7 * diff) + spec;
        float d = length(frame.cameraPos.xyz - in.worldPos);
        float f = saturate(1.0 - exp(-d * frame.fog.w));
        return float4(mix(color, frame.fog.rgb, f), 1.0);
    }

    struct QuadOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex QuadOut quad_vertex(uint vid [[vertex_id]]) {
        float2 p = float2(float((vid << 1) & 2), float(vid & 2));
        QuadOut o;
        o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    // params: x k1, y k2, z distortion on, w divider half-width (uv)
    fragment float4 distort_fragment(QuadOut in [[stage_in]],
                                     texture2d<float> tex [[texture(0)]],
                                     constant float4& params [[buffer(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 uv = in.uv;
        if (abs(uv.x - 0.5) < params.w) { return float4(0.35, 0.35, 0.35, 1.0); }
        float side = uv.x < 0.5 ? 0.0 : 1.0;
        float2 local = float2(uv.x * 2.0 - side, uv.y);
        if (params.z > 0.5) {
            float2 c = local * 2.0 - 1.0;
            float r2 = dot(c, c) * 0.5;
            float f = 1.0 + params.x * r2 + params.y * r2 * r2;
            float edge = 1.0 + params.x * 0.5 + params.y * 0.25;
            c = c * f / edge;
            if (any(abs(c) > 1.0)) { return float4(0.0, 0.0, 0.0, 1.0); }
            local = c * 0.5 + 0.5;
        }
        return tex.sample(s, float2((local.x + side) * 0.5, local.y));
    }
    """
}
