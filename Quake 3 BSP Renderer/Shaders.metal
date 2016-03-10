//
//  Shaders.metal
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 26/08/2015.
//  Copyright (c) 2015 Thomas Brunoli. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn
{
    float4 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
    float2 textureCoord [[attribute(3)]];
    float2 lightMapCoord [[attribute(4)]];
};

struct VertexOut
{
    float4 position [[position]];
    float4 normal;
    float4 color;
    float2 textureCoord;
    float2 lightMapCoord;
};

struct Uniforms
{
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

enum AlphaFunc: uchar { gt0, lt128, ge128 };
struct StageUniforms
{
    bool hasAlphafunc;
    AlphaFunc alphafunc;
};

vertex VertexOut renderVert(VertexIn in [[stage_in]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint vid [[vertex_id]])
{
    VertexOut out;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position);
    out.normal = float4(in.normal);
    out.color = float4(in.color);
    out.textureCoord = float2(in.textureCoord);
    out.lightMapCoord = float2(in.lightMapCoord);
    
    return out;
}

fragment half4 renderFrag(VertexOut vert [[stage_in]],
                          texture2d<half> tex [[texture(0)]],
                          sampler smp [[sampler(0)]],
                          constant StageUniforms &stageUniforms [[buffer(0)]])
{
    vert.textureCoord[1] = 1 - vert.textureCoord[1];
    half4 diffuse = half4(vert.color) * tex.sample(smp, vert.textureCoord);
    
    if (stageUniforms.hasAlphafunc) {
        bool discard = false;
        switch (stageUniforms.alphafunc) {
            case gt0: discard = diffuse[3] <= 0; break;
            case lt128: discard = diffuse[3] >= 0.5; break;
            case ge128: discard = diffuse[3] < 0.5; break;
        }
        if (discard) discard_fragment();
    }
    
    return diffuse;
}

fragment half4 renderFragLM(VertexOut vert [[stage_in]],
                            texture2d<half> lm [[texture(0)]],
                            sampler smp [[sampler(0)]])
{
    return half4(vert.color) * lm.sample(smp, vert.lightMapCoord);
}