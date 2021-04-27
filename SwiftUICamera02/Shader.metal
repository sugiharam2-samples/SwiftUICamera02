//
//  Shader.metal
//  SwiftUICamera02
//
//  Created by Mamoru Sugihara on 2021/04/27.
//

#include <metal_stdlib>
using namespace metal;

struct RasterizerData
{
	float4 clipSpacePosition [[position]];
	float2 texCoord;
};

vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
			 const device float4 *position [[ buffer(0) ]],
			 const device float2 *uv [[ buffer(1) ]])
{
	RasterizerData out;
	out.clipSpacePosition = position[vertexID];
	out.texCoord = uv[vertexID];
	return out;
}

fragment float4
fragmentShader(RasterizerData in [[ stage_in ]],
			   texture2d<float, access::sample> texture [[ texture(0) ]])
{
	constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);
	return texture.sample(sampler2d, in.texCoord);
}
