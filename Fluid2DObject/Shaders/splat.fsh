
precision highp float;

uniform vec4 color;
uniform vec2 position;
uniform float radius;
uniform vec2 windowDims;
uniform sampler2D base;
uniform float blend;
uniform bool isDigital;

vec2 coords;

varying mediump vec2  texCoord;


float gaussian(vec2 pos, float radius)
{
	return exp(-dot(pos, pos) / radius);
}


float digital(vec2 pos, float radius)
{
	float len = length(pos);
	if(len < radius) {
		return 1.0;
	} else {
		return 0.0;
	}
}


void main()
{

    vec2 pos;
    float rad;

    coords = vec2(float(texCoord.x), float(texCoord.y));
    pos = windowDims * position - coords;
	rad = radius;
	float g;
	if (isDigital) {
		
		g = digital(pos, rad * 100.0);
		gl_FragColor = color * g;

	} else {
		g = gaussian(pos, rad);
	
		// add
		if (blend <= 0.0) {
			vec4 oldColor = texture2D(base, coords);
			vec4 newColor = color * g;
			gl_FragColor = newColor + oldColor;
		}
		else {
			// blend - use the gaussian function to determine how much of the new color is added
			vec4 oldColor = texture2D(base, coords);
			vec4 newColor = color;
			gl_FragColor = mix(oldColor, newColor, g * blend);
		}
	}

} // main end
