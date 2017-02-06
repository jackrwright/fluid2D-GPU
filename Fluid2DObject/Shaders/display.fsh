// display.fsh

precision highp float;

uniform sampler2D texture;
uniform sampler2D reaction;
uniform mediump vec4 bias;
uniform mediump vec4 scale;
uniform highp float simDim;
uniform bool isFire;

varying highp vec2  texCoord;

void main()
{
	vec4 color = texture2D(texture, texCoord);
	
	if (isFire) {
		
		// use the reaction coordinate to look up the color from the fire texture
		vec4 reactionColor = texture2D(reaction, vec2(color.w, 0.0));
		
		// use the alpha of the density color to determine visiblilty
//		vec4 finalColor = bias + scale * vec4(reactionColor.rgb, color.a);
		vec4 finalColor = bias + scale * reactionColor;
		gl_FragColor = finalColor;
		
	} else {
		gl_FragColor = bias + scale * color;
	}

}
