//----------------------------------------------------------------------------
// Function     	: jacobi
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program performs a single Jacobi relaxation step for a poisson
 * equation of the form
 *
 *                Laplacian(U) = b,
 *
 * where U = (u, v) and Laplacian(U) is defined as
 *
 *   grad(div x) = grad(grad dot x) =
 *            partial^2(u)/(partial(x))^2 + partial^2(v)/(partial(y))^2
 *
 * A solution of the equation can be found iteratively, by using this
 * iteration:
 *
 *   U'(i,j) = (U(i-1,j) + U(i+1,j) + U(i,j-1) + U(i,j+1) + b) * 0.25
 *
 * That is what this routine does.  To maintain flexibility for slightly
 * different poisson problems (such as viscous diffusion), we provide
 * two parameters, centerFactor and stencilFactor.  These are useful for
 * non-unit-scale grids, and when there is a coefficient on the RHS of the
 * poisson equation.
 *
 * This program works for both scalar and vector equations.
 *
void jacobi(half2       coords : WPOS,
			out half4       xNew   : COLOR,
			
			uniform half        alpha,
			uniform half        rBeta, // reciprocal beta
			uniform samplerRECT x,     // x vector (Ax = b)
			uniform samplerRECT b)     // b vector (Ax = b)
{
	
	half4 xL, xR, xB, xT;
	h4texRECTneighbors(x, coords, xL, xR, xB, xT);
	
	half4 bC = h4texRECT(b, coords);
	
	xNew = (xL + xR + xB + xT + alpha * bC) * rBeta;
}
 */

precision highp float;

uniform sampler2D x;
uniform sampler2D b;
uniform sampler2D obstacles;

uniform float alpha;
uniform float beta;

uniform highp float simDim;

varying highp vec2  texCoord;

void texNeighbors(sampler2D tex, vec2 s, out float left, out float right, out float bottom, out float top, float N)
{
	vec2 sIn = s * N - 0.5;

	left   = texture2D(tex, ((sIn - vec2(1, 0)) + 0.5) / N).x;
	right  = texture2D(tex, ((sIn + vec2(1, 0)) + 0.5) / N).x;
	bottom = texture2D(tex, ((sIn - vec2(0, 1)) + 0.5) / N).x;
	top    = texture2D(tex, ((sIn + vec2(0, 1)) + 0.5) / N).x;

}

bool isSolid(vec2 cellTexCoords)
{
	return (texture2D(obstacles, cellTexCoords).z > 0.9);
}


// main procedure, the original name was main
void main()
{

 	// get the pressure from neighboring cells
	float pL, pR, pB, pT;
	texNeighbors(x, texCoord, pL, pR, pB, pT, simDim);
	
	// account for obstacles
	vec2 sIn = texCoord * simDim - 0.5;
	float pC = texture2D(x, texCoord).z;
	if (isSolid( ((sIn - vec2(1, 0)) + 0.5) / simDim) ) pL = pC;
	if (isSolid( ((sIn + vec2(1, 0)) + 0.5) / simDim) ) pR = pC;
	if (isSolid( ((sIn - vec2(0, 1)) + 0.5) / simDim) ) pB = pC;
	if (isSolid( ((sIn + vec2(0, 1)) + 0.5) / simDim) ) pT = pC;
	
	// the divergence from the current cell
	vec4 bC = texture2D(b, texCoord);
	
	// compute the new pressure
	float pNew = (pL + pR + pB + pT + alpha * bC.x) * beta;

	gl_FragColor = vec4(pNew, 0, 0, 0);
		
    return;
	
} // main end
