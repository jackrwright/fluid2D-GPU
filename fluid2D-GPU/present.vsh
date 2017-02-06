//
//  display.vsh
//  fluid2d-GPU
//
//  Created by Jack Wright on 9/23/12.
//  Copyright (c) 2012 Jack Wright. All rights reserved.
//
attribute mediump vec4 position;
attribute highp vec2 inTexCoord;

uniform mat4 modelViewProjectionMatrix;

varying highp vec2  texCoord;


void main()
{
    gl_Position = modelViewProjectionMatrix * position;

	// Pass through texcoords
	texCoord = inTexCoord;
}
