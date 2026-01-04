//
//  BasicShaders.metal
//  texture
//
//  Created by John Matthew Weston on 10/7/18.
//  Copyright © 2018 John Matthew Weston. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// Vertex Shader
vertex float4 basic_vertex(const device packed_float3* vertex_array [[ buffer(0) ]], unsigned int vid [[ vertex_id ]]) {
    return float4(vertex_array[vid], 1.0);
}

// Fragment Shader
fragment half4 basic_fragment(){
    return half4(1.0);
}
