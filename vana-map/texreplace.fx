// A texture swapped in for another: our icons drawn where the radar shows the vanilla sprite they borrow.
texture gTexture;

technique replace
{
    pass P0
    {
        Texture[0] = gTexture;
    }
}
