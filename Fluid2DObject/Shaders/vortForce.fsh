//----------------------------------------------------------------------------
// Function     	: vortForce
// Description	    :
//----------------------------------------------------------------------------
/**
 The second pass of vorticity confinement computes a vorticity confinement
 force field and applies it to the velocity field to arrive at a new
 velocity field.
 
void vortForce(half2       coords : WPOS,
			   
			   out half2       uNew   : COLOR,
			   
			   uniform half        halfrdx,  // 0.5 / gridscale
			   uniform half2       dxscale,  // vorticity confinement scale
			   uniform half        timestep,
			   uniform samplerRECT vort,     // vorticity
			   uniform samplerRECT u)        // velocity
{
	half vL, vR, vB, vT, vC;
	h1texRECTneighbors(vort, coords, vL, vR, vB, vT);
	
	vC = h1texRECT(vort, coords);
	
	half2 force = halfrdx * half2(abs(vT) - abs(vB), abs(vR) - abs(vL));
	
	// safe normalize
	static const half EPSILON = 2.4414e-4; // 2^-12
	half magSqr = max(EPSILON, dot(force, force));
	force = force * rsqrt(magSqr);
	
	force *= dxscale * vC * half2(1, -1);
	
	uNew = h2texRECT(u, coords);
	
	uNew += timestep * force;
}
 */

precision highp float;

uniform sampler2D vort;
uniform sampler2D u;
uniform highp float simDim;
uniform highp vec2 dxscale;
uniform highp float timestep;

varying highp vec2  texCoord;

void texNeighbors(sampler2D tex, vec2 s, out float left, out float right, out float bottom, out float top, float N)
{
	highp vec2 sIn = s * N - 0.5;
	
	//	sOut = (sIn + 0.5) / N;
	left   = texture2D(tex, ((sIn - vec2(1, 0)) + 0.5) / N).x;
	right  = texture2D(tex, ((sIn + vec2(1, 0)) + 0.5) / N).x;
	bottom = texture2D(tex, ((sIn - vec2(0, 1)) + 0.5) / N).x;
	top    = texture2D(tex, ((sIn + vec2(0, 1)) + 0.5) / N).x;
}


void main()
{
	// get the vorticity from neighboring cells
	float vL, vR, vB, vT;
	texNeighbors(vort, texCoord, vL, vR, vB, vT, simDim);
	
//	highp vec2 texC = texCoord - (0.5 / simDim);
	float vC = texture2D(vort, texCoord).x;
	
	float halfrdx = 0.5;// / simDim;
	
	highp vec2 force = halfrdx * vec2(abs(vT) - abs(vB), abs(vR) - abs(vL));

	// safe normalize
	const float EPSILON = 2.4414e-4; // 2^-12
	float magSqr = max(EPSILON, dot(force, force));
	force = force * inversesqrt(magSqr);
		
	force *= dxscale * vC * vec2(1, -1);
	
	highp vec2 uNew = texture2D(u, texCoord).xy;
	
	uNew += timestep * force;

	gl_FragColor = vec4(uNew, 0, 0);
	
    return;
	
} // main end
