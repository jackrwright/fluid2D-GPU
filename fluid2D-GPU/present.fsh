// present.fsh
// present the given texture overlaying the background image

precision highp float;

uniform sampler2D texture;
uniform sampler2D background;

varying highp vec2  texCoord;

#define white 1.0
#define lumCoeff vec4(0.25, 0.65, 0.1, 0.0)

vec4 overlay(vec4 botColor, vec4 topColor)
{
	vec4 result;
	
	// mix(x, y, a)
	// x • (1 - a) + y • a
	
	result = mix(botColor, topColor, topColor.a);
	
	return result;
}

void main()
{
	vec4 color = texture2D(texture, texCoord);

	vec4 bg = texture2D(background, texCoord);

	gl_FragColor = overlay(bg, color);
}
