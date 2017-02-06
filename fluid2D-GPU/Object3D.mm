//
//  Object3D.mm
//
//  Created by Jack Wright on 2/1/12.
//  Copyright (c) 2012 JackCraft. All rights reserved.
//

#import "Object3D.h"

@implementation Object3D

@synthesize model = _model;
@synthesize scale = _scale;
@synthesize ambient = _ambient;
@synthesize texture0 = _texture0, texture1 = _texture1;

@synthesize position = _position;
@synthesize rotation = _rotation;


- (void) setPositionX:(float)x Y:(float)y Z:(float)z {
	_position.x = x;
	_position.y = y;
	_position.z = z;
}

- (id) init {
	self = [super init];
	[self setPositionX:0 Y:0 Z:0];
	_scale = PVRTVec3(1, 1, 1);
	
	PVRTMatrixQuaternionIdentity(_rotation);
	
	return self;
}


- (id) initWithModel:(PODModel*)theModel;
{
	self = [self init];
	
	_model = theModel;
	
	_model->_transform = PVRTMat4::Identity();
	
	[_model setFrame:0];
	
	return self;
}


- (void) draw
{
	PVRTMat4 mPosition = PVRTMat4::Translation(_position.x, _position.y, _position.z);
	
	PVRTMat4 view;
	PVRTMatrixRotationQuaternion(view, _rotation);
	
	// scale, rotate, translate, then apply the camera matrix
	_model->_transform = mPosition;
	_model->_transform *= view;

	_model->_transform *= PVRTMat4::Scale(_scale);
	
	// reorient the light direction based on the model rotation
	PVRTVec4 vLightDirWorld = _model.globalLight;	// move to Object3D ?
	_model.lightDir = vLightDirWorld * view;
	
	_model.ambient = _ambient;
	
	_model.texture0 = _texture0;
	_model.texture1 = _texture1;

	[_model draw];
	
} // draw


- (void) rotate:(float)angle axis:(PVRTVec3)axis {
	PVRTQUATERNION qtmp;
	PVRTMatrixQuaternionRotationAxis(qtmp, axis, -angle);
	PVRTMatrixQuaternionMultiply(_rotation, qtmp, _rotation);
	PVRTMatrixQuaternionNormalize(_rotation);
}

- (void) yaw:(float)yaw{
	[self rotate:yaw axis:PVRTVec3(0, 1, 0)];
}

- (void) pitch:(float)pitch{
	[self rotate:pitch axis:PVRTVec3(1, 0, 0)];
}

- (void) roll:(float)roll{
	[self rotate:roll axis:PVRTVec3(0, 0, 1)];
}

- (PVRTVec3) getAxis:(PVRTVec3)axis {
	PVRTMat4 view;
	PVRTMatrixRotationQuaternion(view, _rotation);
	PVRTMatrixInverse(view, view);
	return axis*view;
}

@end
