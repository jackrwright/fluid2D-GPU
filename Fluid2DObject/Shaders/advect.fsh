
//#version 110

//#ifdef GL_ARB_texture_rectangle
//#extension GL_ARB_texture_rectangle : enable
//#endif

//----------------------------------------------------------------------------
// Function     	: advect
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program performs a semi-lagrangian advection of a passive field by
 * a moving velocity field.  It works by tracing backwards from each fragment
 * along the velocity field, and moving the passive value at its destination
 * forward to the starting point.  It performs bilinear interpolation at the
 * destination to get a smooth resulting field.
 */

precision highp float;

uniform highp float timestep;
uniform highp float dissipation;
uniform highp float rdx;
uniform sampler2D u;
uniform sampler2D x;
uniform sampler2D obstacles;
uniform sampler2D temperature;
uniform sampler2D density;
uniform vec2 gravity;
uniform float kR;	// constant for advecting the reaction coordinate for fire
uniform float kT;	// constant for introducing turbulence
uniform float kFa;	// constant for force of bouyancy due to temperature
uniform float kFb;	// constant for force of bouyancy due to temperature

// this needs to be highp because an error creeps at higher values of N
varying highp vec2  texCoord;

vec4 f4texRECTbilerp(sampler2D tex, highp vec2 s, float rdx)
{

	// whole cell coords (i.e. 0..1 -> 0..N)
	highp vec2 sIn = s * rdx - 0.5;
	
	highp vec4 st;
	st.xy = floor(sIn);
	st.zw = st.xy + 1.0;

	highp vec2 t = sIn - st.xy; //interpolating factors
	
	// back to texture coords
	st = (st + 0.5) / rdx;

	highp vec4 tex11 = texture2D(tex, st.xy);
	highp vec4 tex21 = texture2D(tex, st.zy);
	highp vec4 tex12 = texture2D(tex, st.xw);
	highp vec4 tex22 = texture2D(tex, st.zw);
	
	// bilinear interpolation
	return mix(mix(tex11, tex21, t.x), mix(tex12, tex22, t.x), t.y);

}


bool isNonEmptyCell(vec2 cellTexCoords)
{
	return (texture2D(obstacles, cellTexCoords).z > 0.0);
}

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}



// main procedure, the original name was main
void main()
{
	
	if (isNonEmptyCell(texCoord)) {
		gl_FragColor = vec4(0, 0, 0, 0);
		return;
	}
	
	// Trace backwards along the trajectory determined by the current velocity.
	// distance = rate * time.
    highp vec2 pos;
	
    highp vec4 vel;

	vel = texture2D(u, texCoord);	// velocity at current cell

	pos = texCoord - (timestep * vel.xy);

	// Example:
	//    the "particle" followed a trajectory and has landed like this:
	//
	//   (x1,y2)----(x2,y2)    (xN,yN)
	//      |          |    /----/  (trajectory: (xN,yN) = start, x = end)
	//      |          |---/
	//      |      /--/|    ^
	//      |  pos/    |     \_ v.xy (the velocity)
	//      |          |
	//      |          |
	//   (x1,y1)----(x2,y1)
	//
	// x1, y1, x2, and y2 are the coordinates of the 4 nearest grid points
	// around the destination.  We compute these using offsets and the floor
	// operator.  The "-0.5" and +0.5 used below are due to the fact that
	// the centers of texels in a TEXTURE_RECTANGLE_NV are at 0.5, 1.5, 2.5,
	// etc.
	
	// The function f4texRECTbilerp computes the above 4 points and interpolates
	// a value from texture lookups at each point. Rendering this value will
	// effectively place the interpolated value back at the starting point
	// of the advection.
	
	// So that we can have dissipating scalar fields (like smoke), we
	// multiply the interpolated value by a [0, 1] dissipation scalar
	// (1 = lasts forever, 0 = instantly dissipates.  At high frame rates,
	// useful values are in [0.99, 1].



	highp vec4 newValue = f4texRECTbilerp(x, pos, rdx);

	// only dissipate the alpha so ink disappears instead of turning black
	// this only works if we're blending.
	// dissipation should always be 1.0 when advecting velocity.
	newValue.w *= dissipation;
//	newValue *= dissipation;
	
	// update with gravity (might be zero)
//	newValue = vec4(newValue.xy + gravity, newValue.zw);
	
	// update the reaction coord (k is only non-zero for fire)
	newValue.w -= (kR * timestep);
	if (newValue.w < 0.0) newValue.w = 0.0;
	
#if 0
	// *********************************
	// Compute the force of bouyancy based on the advected temperature T
	// Pmg/R * (1/Ta - 1/T) * z
	
	float Ta = 0.0;		// ambient temperature

	// Compute the scalar value for bouyancy.
	// kFb is non-zero if we're advecting temperature.
	float Sb = (texture2D(temperature, texCoord).x - Ta) * kFb;

	// Apply gravity to give it the right direction
	vec2 Fb = (Sb * gravity.xy);
	
#else
	// *********************************
	// Version 2 - also take into account density
	// Fb = -alpha * p * z + Beta * (T - Ta) * z
	//
	// where z points in the upward vertical direction,
	// Ta is the ambient temperature of the air and
	// alpha and Beta are two positive constants with appropriate units such that
	// the equation is physically meaningful. Note that when p = 0 and T = Ta, this force is zero.
	
	float Ta = 0.0;
	
	vec2 Fb = ((kFb * texture2D(temperature, texCoord).x - Ta) * gravity.xy) - (kFa * texture2D(density, texCoord).a * gravity.xy);

#endif

	// update the velocity with the bouyancy
	newValue.xy += Fb;
	
//	// If kT is non-zero, introduce a random perturbation into the velocity vector based on the current density
//	if (kT != 0.0) {
//		vec2 co = newValue.xy;
//		vec2 vT = vec2(rand(co), rand(co)) * kT * texture2D(density, texCoord).a;
//		newValue.xy = vT;
//	}

	gl_FragColor = newValue;
	
	// test code - return the whole coords in r,g and velocity in b,a
//	float veloX = vel.x * timestep;
//	float veloY = vel.y * timestep;
//	if((veloX) > 0.0) veloX = 1.0;
//	if((veloY) > 0.0) veloY = 1.0;
//	gl_FragColor = vec4(pos * rdx, veloX, veloY);
	
	// test code - dump the input velocity values
//	gl_FragColor = vec4(vel, 0, 0);

	
	// test code - skip bilerp
//	gl_FragColor = dissipation * texture2D(x, pos);
	

	// test code - write existing value back
//	gl_FragColor = texture2D(x, texCoord.xy);




	// simulation size cell coords (e.g. 0 - 1 -> 0 - 64)
//	vec2 coordWhole = texCoord * rdx;

	// copy the value from one cell to the right:
//	coordWhole = vec2(coordWhole.x + 1.0, coordWhole.y);
	
	// copy the value from one cell to the left:
//	coordWhole = vec2(coordWhole.x - 1.0, coordWhole.y);
	
	// copy the value from one cell above:
//	coordWhole = vec2(coordWhole.x, coordWhole.y + 1.0);
	
	// copy the value from one cell below:
//	coordWhole = vec2(coordWhole.x, coordWhole.y - 1.0);

	// copy the value from one cell below left:
//	coordWhole = vec2(coordWhole.x - 1.0, coordWhole.y - 1.0);
	
	// copy the value from one cell below right:
//	coordWhole = vec2(coordWhole.x + 1.0, coordWhole.y - 1.0);
	
//	vec2 coord = coordWhole / rdx;	// back to tex coords
//	gl_FragColor = texture2D(x, coord.xy);
	
//	gl_FragColor = f4texRECTbilerp(x, coord, rdx);


	
    return;
} // main end
