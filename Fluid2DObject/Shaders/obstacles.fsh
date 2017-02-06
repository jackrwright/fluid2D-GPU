//----------------------------------------------------------------------------
// Function     	: obstacles
// Description	    :

precision highp float;

uniform mediump vec4 value;

varying highp vec2  texCoord;

void main()
{
	gl_FragColor = value;
	
} // main end
