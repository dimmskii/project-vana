// The radar's disc: its render target drawn through a circle, with a soft edge one pixel or so wide.
texture gTexture;
float gEdge = 0.012;

sampler Sampler0 = sampler_state
{
    Texture = (gTexture);
    AddressU = Clamp;
    AddressV = Clamp;
};

float4 PixelShaderFunction(float2 uv : TEXCOORD0, float4 diffuse : COLOR0) : COLOR0
{
    float4 colour = tex2D(Sampler0, uv);
    float d = distance(uv, float2(0.5, 0.5));
    colour.a *= saturate((0.5 - d) / gEdge);
    return colour * diffuse;
}

technique disc
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}
