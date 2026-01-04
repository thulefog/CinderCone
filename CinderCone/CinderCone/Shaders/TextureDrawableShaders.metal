//
//  TextureDrawableShaders.metal
//
//  Created by John Matthew Weston on 10/9/18.
//  Copyright © 2018 John Matthew Weston. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 renderedCoordinate [[position]];
    float2 textureCoordinate;
} TextureMappingVertex;

vertex TextureMappingVertex mapTextureDrawable(unsigned int vertex_id [[ vertex_id ]]) {
    // renderedCoordinates:
    // -------------------
    // has coordinates of the screen edges in the following order:
    // left-bottom (-1.0, -1.0), right-bottom (1.0, -1.0), left-top (-1.0, 1.0), right-top (1.0, 1.0)
    float4x4 renderedCoordinates = float4x4(float4( -1.0, -1.0, 0.0, 1.0 ),      /// (x, y, depth, W)
                                            float4(  1.0, -1.0, 0.0, 1.0 ),
                                            float4( -1.0,  1.0, 0.0, 1.0 ),
                                            float4(  1.0,  1.0, 0.0, 1.0 ));
    
    // textureCoordinates:
    // -------------------
    // would list the exactly same edges of the texture in the same order as renderedCoordinates:
    // left-bottom (0.0, 1.0), right-bottom (1.0, 1.0), left-top (0.0, 0.0), right-top (1.0, 0.0).
    float4x2 textureCoordinates = float4x2(float2( 0.0, 1.0 ), /// (x, y)
                                           float2( 1.0, 1.0 ),
                                           float2( 0.0, 0.0 ),
                                           float2( 1.0, 0.0 ));
    TextureMappingVertex outVertex;
    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];
    outVertex.textureCoordinate = textureCoordinates[vertex_id];
    
    return outVertex;
}

fragment half4 displayTextureDrawable(TextureMappingVertex mappingVertex [[ stage_in ]],
                              texture2d<float, access::sample> texture [[ texture(0) ]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    return half4(texture.sample(s, mappingVertex.textureCoordinate));
}

