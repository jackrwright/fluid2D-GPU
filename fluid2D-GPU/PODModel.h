//
//  PODModel.h
//
//  Created by Jack Wright on 1/15/12.
//  Copyright (c) 2012 JackCraft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVRTModelPOD.h"
#import "Shader.h"

@interface PODModel : NSObject {


    GLuint *_vertexArray;
    GLuint *_vertexBuffer;
    GLuint *_vertexIndexBuffer;

	
	GLuint _texture0;
	GLuint _texture1;
	
	Shader *_shader;
	
	PVRTVec4		_globalLight;
	PVRTVec4		_lightDir;
	float			_ambient;
	
	float _scale;

	PVRTMat4		_lightViewMatrix;

@public
	CPVRTModelPOD	_scene;
	PVRTMat4 		_transform;
	PVRTMat4 		_mProjection;
	PVRTMat4		_biasMatrix;
	
}

@property GLuint texture0, texture1;
@property (nonatomic) PVRTVec4 globalLight;
@property (nonatomic) PVRTVec4 lightDir;
@property (nonatomic) PVRTMat4 lightViewMatrix;
@property (nonatomic) PVRTMat4 biasMatrix;
@property float ambient;
@property (nonatomic) Shader *shader;

- (id) initWithFile:(NSString *)filename texture:(GLuint)texture shader:(Shader *)shader;

- (id) initFromMemory:(const char *)name size:(const size_t)size texture:(GLuint)texture shader:(Shader *)shader;
- (BOOL) loadFile:(NSString *)filename;
- (BOOL) loadFromMemory:(const char *)name size:(const size_t)size;
- (void) setFrame:(float)frame;
- (void) drawWithTransform:(PVRTMat4)transform mProjection:(PVRTMat4)projection;
- (void) draw;

@end
