//
//  Object3D.h
//  Dragon2
//
//  Created by Jack Wright on 2/1/12.
//  Copyright (c) 2012 JackCraft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PODModel.h"
#import "PVRTVector.h"
#import "PVRTQuaternion.h"

@interface Object3D : NSObject {
	PODModel		*_model;
	PVRTVec3		_scale;
	PVRTVec3		_position;
	PVRTQUATERNION	_rotation;
	float			_ambient;
	GLuint			_texture0;
	GLuint			_texture1;
	

}

@property (nonatomic, retain)	PODModel* model;
@property (nonatomic)			PVRTVec3 scale;
@property float					ambient;
@property GLuint				texture0;
@property GLuint				texture1;

@property (nonatomic) PVRTVec3 position;
@property (nonatomic) PVRTQUATERNION rotation;

- (id) initWithModel:(PODModel*)theModel;
- (void) yaw:(float)yaw;
- (void) pitch:(float)pitch;
- (void) roll:(float)roll;
- (PVRTVec3) getAxis:(PVRTVec3)axis;
- (void) draw;

@end
