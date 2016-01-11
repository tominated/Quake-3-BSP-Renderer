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
    packed_float4 position [[attribute(0)]];
    packed_float4 normal [[attribute(1)]];
    packed_float4 color [[attribute(2)]];
    packed_float2 textureCoord [[attribute(3)]];
    packed_float2 lightMapCoord [[attribute(4)]];
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

vertex VertexOut renderVert(const device VertexIn* vertices [[buffer(0)]],
                            constant Uniforms &uniforms     [[buffer(1)]],
                            uint vid [[vertex_id]])
{
    VertexIn in = vertices[vid];
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
                          texture2d<half> lm [[texture(1)]])
{
    constexpr sampler s(coord::normalized,
                        address::repeat,
                        filter::linear,
                        mip_filter::linear);
    constexpr float2 x = float2(1, 1);
    
    half4 diffuseColor = tex.sample(s, x - vert.textureCoord);
    half4 lightColor = lm.sample(s, vert.lightMapCoord);
    
    return half4(half3(diffuseColor) * half3(lightColor * 2), diffuseColor[3]) ;
}