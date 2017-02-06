//
//  Camera.mm
//
//  Created by Jack Wright on 1/30/12.
//  Copyright (c) 2012 JackCraft. All rights reserved.
//

#import "Camera.h"

@implementation Camera

@synthesize boom = _boom;
@synthesize projection = _projection;
@synthesize perspective = _perspective;
@synthesize view = _view;
@synthesize from = _from;
@synthesize to = _to;
@synthesize up = _up;
@synthesize near = _near;
@synthesize far = _far;
@synthesize fov = _fov;

/*
 * Call this before updateFrom:to:up to define the projection matrix
 */
- (void) updateProjectionFov:(float)fov aspect:(float)aspect near:(float)near far:(float)far;
{
	_near = near;
	_far = far;
	_fov = fov;

	_perspective = PVRTMat4::PerspectiveFovRH(fov, aspect, near, far, PVRTMat4::OGL, 0);

} // updateProjection


- (void) updateFrom:(PVRTVec3)from to:(PVRTVec3)to up:(PVRTVec3)up;
{
	_from = from;
	_to = to;
	_up = up;

	_view = PVRTMat4::LookAtRH(from, to, up);

	_projection = _perspective * _view;
	
} // update


- (void) offsetLook:(float)look up:(float)up right:(float)right {
	_boom.z = look;
	_boom.y = up;
	_boom.x = right;
}

@end
