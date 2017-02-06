//----------------------------------------------------------------------------
// Vorticity Confinement
//----------------------------------------------------------------------------
// The motion of smoke, air and other low-viscosity fluids typically contains
// rotational flows at a variety of scales. This rotational flow is called
// vorticity.  As Fedkiw et al. explained (2001), numerical dissipation caused
// by simulation on a coarse grid damps out these interesting features.
// Therefore, they used "vorticity confinement" to restore these fine-scale
// motions. Vorticity confinement works by first computing the vorticity,
//                          vort = curl(u).
// The program vorticity() does this computation. From the vorticity we
// compute a normalized vorticity vector field,
//                          F = normalize(eta),
// where, eta = grad(|vort|). The vectors in F point from areas of lower
// vorticity to areas of higher vorticity. From these vectors we compute a
// force that can be used to restore an approximation of the dissipated
// vorticity:
//                          vortForce = eps * cross(F, vort) * dx.
// Here eps is a user-controlled scale parameter.
//
// The operations above require two passes in the simulator.  This is because
// the vorticity must be computed in one pass, because computing the vector
// field F requires sampling multiple vorticity values for each vector.
// Because a texture can't be written and then read in a single pass, this is
// inherently a two-pass algorithm.

//----------------------------------------------------------------------------
// Function     	: vorticity
// Description	    :
//----------------------------------------------------------------------------
/**
 The first pass of vorticity confinement computes the (scalar) vorticity
 field.  See the description above.  In Flo, if vorticity confinement is
 disabled, but the vorticity field is being displayed, only this first
 pass is executed.
 
void vorticity(half2       coords : WPOS,
			   out half        vort   : COLOR,
			   
			   uniform half        halfrdx, // 0.5 / gridscale
			   uniform samplerRECT u)       // velocity
{
	half4 uL, uR, uB, uT;
	h4texRECTneighbors(u, coords, uL, uR, uB, uT);
	
	vort = halfrdx * ((uR.y - uL.y) - (uT.x - uB.x));
}
 */

precision highp float;

uniform sampler2D u;
uniform highp float simDim;

varying highp vec2  texCoord;

void texNeighbors(sampler2D tex, vec2 s, out vec4 left, out vec4 right, out vec4 bottom, out vec4 top, float N)
{
	vec2 sIn = s * N - 0.5;
	
	//	sOut = (sIn + 0.5) / N;
	left   = texture2D(tex, ((sIn - vec2(1, 0)) + 0.5) / N);
	right  = texture2D(tex, ((sIn + vec2(1, 0)) + 0.5) / N);
	bottom = texture2D(tex, ((sIn - vec2(0, 1)) + 0.5) / N);
	top    = texture2D(tex, ((sIn + vec2(0, 1)) + 0.5) / N);
	
}



void main()
{
	// get the velocity from neighboring cells
	highp vec4 uL, uR, uB, uT;
	texNeighbors(u, texCoord, uL, uR, uB, uT, simDim);
	
	float halfrdx = 0.5;
//	float halfrdx = 0.5 / simDim;

	float vort = ((uR.y - uL.y) - (uT.x - uB.x)) * halfrdx;
		
	gl_FragColor = vec4(vort, 0, 0, 0);
	
    return;
	
} // main end
