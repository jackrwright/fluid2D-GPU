//
//  Fluid2DObject.h
//  fuid2D
//
//  Created by Jack Wright on 2/3/13.
//  Copyright (c) 2013 Jack Wright. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "Shader.h"

// This is defined here for debugging. The parent App can choose to use this
// to set up the simulation if debugging arrays are needed (dumpTexture method).
#define theN 128

#define kUseVAOs 1

enum Texture
{
    TEXTURE_VELOCITY0,
    TEXTURE_VELOCITY,
    TEXTURE_DENSITY0,
    TEXTURE_DENSITY,
    TEXTURE_DIVERGENCE,
    TEXTURE_PRESSURE0,
    TEXTURE_PRESSURE,
    TEXTURE_VORTICITY,
	TEXTURE_OBSTACLES,
	TEXTURE_TEMPERATURE0,
	TEXTURE_TEMPERATURE,
    TEXTURE_COUNT
};

typedef enum F2D_DisplayChoice {
	F2D_DisplayDensity = 0,
	F2D_DisplayVelocity,
	F2D_DisplayDivergence,
	F2D_DisplayPressure,
	F2D_DisplayObstacles,
	F2D_DisplayTemperature,
} F2D_DISPLAY_CHOICE;

@protocol fluidObjectDelegate;

#if kUseVAOs
#define BUFFER_OFFSET(i) ((char *)NULL + (i))
#endif


@interface Fluid2DObject : NSObject {

	GLuint	_iTextures[TEXTURE_COUNT];

	GLuint	_iDisplayTexture;

	GLuint	_iOffScreenFBO;
	
	int		_N;
	float	_pixelWidth;
	float	_sMin, _sMax, _tMin, _tMax;
	float	_xMin, _xMax, _yMin, _yMax;
	
	GLhalf	*_zeros;
	GLubyte	*_zerosB;
	
//	GLhalf *debugImage;
	

	Shader	*displayShader;
	Shader	*splatShader;
	Shader	*boundaryShader;
	Shader	*advectShader;
	Shader	*divergenceShader;
	Shader	*jacobiShader;
	Shader	*gradientShader;
	Shader	*vorticityShader;
	Shader	*vortForceShader;

    GLKMatrix4 _modelViewProjectionMatrix;
	
	float	_Dt;

	int		_iNumPoissonSteps;

#if kUseVAOs
	GLuint	_vertexArrayObjectSim;
	GLuint	_vertexBufferSim;

	GLuint	_vertexArrayObjectFull;
	GLuint	_vertexBufferFull;

	GLuint	_vertexArrayObjectLeft;
	GLuint	_vertexBufferLeft;
	GLuint	_vertexArrayObjectRight;
	GLuint	_vertexBufferRight;
	GLuint	_vertexArrayObjectBottom;
	GLuint	_vertexBufferBottom;
	GLuint	_vertexArrayObjectTop;
	GLuint	_vertexBufferTop;
#endif
}

@property (nonatomic, assign) id<fluidObjectDelegate> delegate;
@property (strong, nonatomic) GLKTextureInfo *fireTexInfo;
@property GLKMatrix4	projectionMatrix;
@property GLKMatrix4	modelViewMatrix;
@property float			force;
@property float			diffusion;
@property float			viscosity;
@property float			vorticity;
@property float			dissipation;
@property GLKVector2	gravity;
@property BOOL			projectTwice;
@property GLuint		displayTexture;
@property float			blendFactor;
@property float			turbulence;

@property BOOL			isFire;
@property float			kReaction;

@property BOOL			advectTemperature;
@property float			kT;			// constant for advecting temperature
@property float			kFa, kFb;	// Constants for force of bouyancy due to density and temperature

@property F2D_DISPLAY_CHOICE	displayChoice;

- (id) initWithDim:(int)N;
- (void) reset;
- (void) updateWithDt:(float)Dt;
- (void) injectColorR:(float)r g:(float)g b:(float)b atX:(float)x y:(float)y withRadius:(float)radius;
- (void) injectVelocityDX:(float)dx dy:(float)dy atX:(float)x y:(float)y withRadius:(float)radius;
- (void) injectSmokeR:(float)r g:(float)g b:(float)b atX:(float)x y:(float)y withTemperature:(float)temp andRadius:(float)radius;
- (void) generateObstacleX:(float)x y:(float)y velocityX:(float)vx vy:(float)vy radius:(float)radius;

@end

@protocol fluidObjectDelegate <NSObject>

- (void) getExternalInput;

@end

