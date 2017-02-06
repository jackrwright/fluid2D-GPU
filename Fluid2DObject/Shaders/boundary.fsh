//#ifdef GL_ARB_texture_rectangle
//#extension GL_ARB_texture_rectangle : enable
//#endif

//----------------------------------------------------------------------------
// Function     	: boundary
// Description	    :
//----------------------------------------------------------------------------
/**
 * This program is used to compute neumann boundary conditions for solving
 * poisson problems.  The neumann boundary condition for the poisson equation
 * says that partial(u)/partial(n) = 0, where n is the normal direction of the
 * inside of the boundary.  This simply means that the value of the field
 * does not change across the boundary in the normal direction.
 *
 * In the case of our simple grid, this simply means that the value of the
 * field at the boundary should equal the value just inside the boundary.
 *
 * We allow the user to specify the direction of "just inside the boundary"
 * by using texture coordinate 1.
 *
 * Thus, to use this program on the left boundary, TEX1 = (1, 0):
 *
 * LEFT:   TEX1=( 1,  0)
 * RIGHT:  TEX1=(-1,  0)
 * BOTTOM: TEX1=( 0,  1)
 * TOP:    TEX1=( 0, -1)
 *
 * scale is used to selectively scale the desired component
 */

precision highp float;

uniform mediump sampler2D x;
uniform highp vec2 offset;
uniform mediump vec3 scale;

varying highp vec2  texCoord;

void main()
{
	vec4 val = texture2D(x, texCoord + offset);
	
	gl_FragColor = vec4(scale * val.xyz, 0.0);
	
	// test code
//	val = vec4(1.0, 0.0, 0.0, 0.0);
//	gl_FragColor = vec4(val.xyz, val.w);

	// test code - return the coords
//	gl_FragColor = vec4(texCoord * 128.0, 0.0, 0.0);

	// test code - return the coords of the inner cells
//	gl_FragColor = vec4((texCoord + offset) * 128.0, 0.0, 0.0);
	

} // main end
