//----------------------------------------------------------------------------
// Function     	: divergence
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program computes the divergence of the specified vector field
 * "velocity". The divergence is defined as
 *
 *  "grad dot v" = partial(v.x)/partial(x) + partial(v.y)/partial(y),
 *
 * and it represents the quantity of "stuff" flowing in and out of a parcel of
 * fluid.  Incompressible fluids must be divergence-free.  In other words
 * this quantity must be zero everywhere.
 *
 */
// void h4texRECTneighbors(samplerRECT tex, half2 s,
//						 out half4 left,
//						 out half4 right,
//						 out half4 bottom,
//						 out half4 top)
// {
//	 left   = h4texRECT(tex, s - half2(1, 0));
//	 right  = h4texRECT(tex, s + half2(1, 0));
//	 bottom = h4texRECT(tex, s - half2(0, 1));
//	 top    = h4texRECT(tex, s + half2(0, 1));
// }
 
//void divergence(half2       coords  : WPOS,  // grid coordinates
//		   out  half4       div     : COLOR, // divergence (output)
//		uniform half        halfrdx,         // 0.5 / gridscale
//		uniform samplerRECT w)               // vector field
//{
//	half4 vL, vR, vB, vT;
//	h4texRECTneighbors(w, coords, vL, vR, vB, vT);
//	
//	div = halfrdx * (vR.x - vL.x + vT.y - vB.y);
//}

precision highp float;

uniform sampler2D w;
uniform sampler2D obstacles;
uniform highp float simDim;

varying highp vec2  texCoord;

void texNeighbors(sampler2D tex, vec2 s, out vec4 left, out vec4 right, out vec4 bottom, out vec4 top, float N)
{
	vec2 sIn = s * N - 0.5;

	left   = texture2D(tex, ((sIn - vec2(1, 0)) + 0.5) / N);
	right  = texture2D(tex, ((sIn + vec2(1, 0)) + 0.5) / N);
	bottom = texture2D(tex, ((sIn - vec2(0, 1)) + 0.5) / N);
	top    = texture2D(tex, ((sIn + vec2(0, 1)) + 0.5) / N);

}


bool isSolid(vec2 cellTexCoords)
{
	return (texture2D(obstacles, cellTexCoords).z > 0.9);
}


// main procedure, the original name was main
void main()
{
	vec4 vL, vR, vB, vT;
	texNeighbors(w, texCoord, vL, vR, vB, vT, simDim);
	
	// account for obstacles
	vec2 sIn = texCoord * simDim - 0.5;
	vec4 vC = texture2D(w, texCoord);
	if (isSolid( ((sIn - vec2(1, 0)) + 0.5) / simDim) ) vL = vC;
	if (isSolid( ((sIn + vec2(1, 0)) + 0.5) / simDim) ) vR = vC;
	if (isSolid( ((sIn - vec2(0, 1)) + 0.5) / simDim) ) vB = vC;
	if (isSolid( ((sIn + vec2(0, 1)) + 0.5) / simDim) ) vT = vC;
	
	float halfrdx = -0.5 / simDim;

	vec4 div = vec4(halfrdx * (vR.x - vL.x + vT.y - vB.y), 0.0, 0.0, 0.0);
	
	gl_FragColor = div;
	
    return;
	
} // main end
