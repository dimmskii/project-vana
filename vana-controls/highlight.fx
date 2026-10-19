// /interact's highlight: the element's own textures, washed with a pulsing neon tint.
texture gTexture0 < string textureState = "0,Texture"; >;
float4 gColor = float4(0.25, 1.0, 0.5, 1.0);
float gStrength = 0.5;

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float4 tex = tex2D(Sampler0, PS.TexCoord);
    float4 colour = tex * PS.Diffuse;
    colour.rgb = lerp(colour.rgb, gColor.rgb, gStrength) + gColor.rgb * gStrength * 0.35;
    return colour;
}

technique highlight
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique fallback
{
    pass P0
    {
    }
}
