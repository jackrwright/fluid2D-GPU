//
//  Camera.h
//
//  Created by Jack Wright on 1/30/12.
//  Copyright (c) 2012 JackCraft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Object3D.h"
#import "PVRTVector.h"

@interface Camera : Object3D {
	
	PVRTVec3	_from;
	PVRTVec3	_to;
	PVRTVec3	_up;
	float		_near;
	float		_far;
	float		_fov;
	
	// the follow distance from our view target. Used for rotating about the target while keeping it in view
	PVRTVec3	_boom;
	
	PVRTMat4	_perspective;
	PVRTMat4	_projection;
	PVRTMat4	_view;

}

@property (nonatomic) PVRTVec3 boom;
@property (nonatomic) PVRTMat4 projection;
@property (nonatomic) PVRTMat4 perspective;
@property (nonatomic) PVRTMat4 view;
@property (nonatomic) PVRTVec3 from, to, up;
@property (nonatomic) float near, far, fov;

- (void) offsetLook:(float)look up:(float)up right:(float)right;
- (void) updateProjectionFov:(float)fov aspect:(float)aspect near:(float)near far:(float)far;
- (void) updateFrom:(PVRTVec3)from to:(PVRTVec3)to up:(PVRTVec3)up;

@end
