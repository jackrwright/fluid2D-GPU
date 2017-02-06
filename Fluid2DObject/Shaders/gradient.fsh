//----------------------------------------------------------------------------
// Function     	: gradient
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program implements the final step in the fluid simulation.  After
 * the poisson solver has iterated to find the pressure disturbance caused by
 * the divergence of the velocity field, the gradient of that pressure needs
 * to be subtracted from this divergent velocity to get a divergence-free
 * velocity field:
 *
 * v-zero-divergence = v-divergent -  grad(p)
 *
 * The gradient(p) is defined:
 *     grad(p) = (partial(p)/partial(x), partial(p)/partial(y))
 *
 * The discrete form of this is:
 *     grad(p) = ((p(i+1,j) - p(i-1,j)) / 2dx, (p(i,j+1)-p(i,j-1)) / 2dy)
 *
 * where dx and dy are the dimensions of a grid cell.
 *
 * This program computes the gradient of the pressure and subtracts it from
 * the velocity to get a divergence free velocity.
 *
void gradient(half2       coords  : WPOS,  // grid coordinates
			  out half4       uNew    : COLOR, // divergence (output)//hvfFlo IN,
			  
			  uniform half        halfrdx,         // 0.5 / grid scale
			  uniform samplerRECT p,               // pressure
			  uniform samplerRECT w)               // velocity
{
	half pL, pR, pB, pT;
	
	h1texRECTneighbors(p, coords, pL, pR, pB, pT);
	
	half2 grad = half2(pR - pL, pT - pB) * halfrdx;
	
	uNew = h4texRECT(w, coords);
	uNew.xy -= grad;
}
 */

precision highp float;

uniform sampler2D p;
uniform sampler2D w;
uniform sampler2D obstacles;
uniform highp float simDim;

varying highp vec2  texCoord;

void texNeighbors(sampler2D tex, vec2 s, out float left, out float right, out float bottom, out float top, float N)
{
	highp vec2 sIn = s * N - 0.5;

	left   = texture2D(tex, ((sIn - vec2(1, 0)) + 0.5) / N).x;
	right  = texture2D(tex, ((sIn + vec2(1, 0)) + 0.5) / N).x;
	bottom = texture2D(tex, ((sIn - vec2(0, 1)) + 0.5) / N).x;
	top    = texture2D(tex, ((sIn + vec2(0, 1)) + 0.5) / N).x;
}

bool isBoundaryCell(vec2 cellTexCoords)
{
	return (texture2D(obstacles, cellTexCoords).z > 0.9);
}


vec2 getObstacleVelocity(vec2 cellTexCoords)
{
	return texture2D(obstacles, cellTexCoords).xy;
}


// main procedure, the original name was main
void main()
{

	if (isBoundaryCell(texCoord))
	{
		gl_FragColor = vec4(getObstacleVelocity(texCoord), 0, 0);
		return;
	}
	
	// get the pressure from neighboring cells
	float pL, pR, pB, pT;
	texNeighbors(p, texCoord, pL, pR, pB, pT, simDim);
	
	// Get obstacle velocities in neighboring solid cells
	highp vec2 sIn = texCoord * simDim - 0.5;
	vec2 vL = getObstacleVelocity(((sIn - vec2(1, 0)) + 0.5) / simDim);
	vec2 vR = getObstacleVelocity(((sIn + vec2(1, 0)) + 0.5) / simDim);
	vec2 vB = getObstacleVelocity(((sIn - vec2(0, 1)) + 0.5) / simDim);
	vec2 vT = getObstacleVelocity(((sIn + vec2(0, 1)) + 0.5) / simDim);
	vec2 obstV = vec2(0,0);
	vec2 vMask = vec2(1,1);
	float pC = texture2D(p, texCoord).z;
	if (isBoundaryCell( ((sIn - vec2(1, 0)) + 0.5) / simDim) ) {
		pL = pC; obstV.x = vL.x; vMask.x = 0.0;
	}
	if (isBoundaryCell( ((sIn + vec2(1, 0)) + 0.5) / simDim) ) {
		pR = pC; obstV.x = vR.x; vMask.x = 0.0;
	}
	if (isBoundaryCell( ((sIn - vec2(0, 1)) + 0.5) / simDim) ) {
		pB = pC; obstV.y = vB.y; vMask.y = 0.0;
	}
	if (isBoundaryCell( ((sIn + vec2(0, 1)) + 0.5) / simDim) ) {
		pT = pC; obstV.y = vT.y; vMask.y = 0.0;
	}
	
	float halfrdx = 0.5 * simDim;

	vec2 grad = vec2(pR - pL, pT - pB) * halfrdx;
	
	vec2 vOld = texture2D(w, texCoord).xy;
	vec2 vNew = vOld - grad;
	
	// Explicitly enforce the appropriate components of the new velocity with obstacle velocities
	vNew = (vMask * vNew) + obstV;
	
	gl_FragColor = vec4(vNew, 0, 0);
	
    return;
	
} // main end
