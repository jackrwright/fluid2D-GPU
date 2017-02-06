//
//  Fluid2DObject.m
//  fuid2D
//
//  Created by Jack Wright on 2/3/13.
//  Copyright (c) 2013 Jack Wright. All rights reserved.
//

#import "Fluid2DObject.h"
#import "glUtil.h"
#import "half.h"

#if kUseVAOs
static const GLfloat square_mesh[] = {
	0.000, 0.000, 0.000, 0.0, 0.0,
	1.0, 0.000, 0.000, 1.0, 0.0,
	0.000, 1.0, 0.000, 0.0, 1.0,
	1.0, 1.0, 0.000, 1.0, 1.0
};
#else
static const GLfloat square_vertices[] = {
	0.000, 0.000, 0.000,
	1.0, 0.000, 0.000,
	0.000, 1.0, 0.000,
	1.0, 1.0, 0.000,
};

static const GLfloat square_uvCoords[] = {
    0.0, 0.0,
    1.0, 0.0,
    0.0, 1.0,
    1.0, 1.0,
};
#endif

#if kUseVAOs
static GLfloat sim_mesh[20];
#else
static GLfloat sim_vertices[12];
static GLfloat sim_uvCoords[8];
#endif

#if kUseVAOs
static GLfloat left_mesh[10];
static GLfloat right_mesh[10];
static GLfloat bottom_mesh[10];
static GLfloat top_mesh[10];
#else
static GLfloat left_vertices[6];
static GLfloat right_vertices[6];
static GLfloat bottom_vertices[6];
static GLfloat top_vertices[6];

static GLfloat left_uvCoords[4];
static GLfloat right_uvCoords[4];
static GLfloat bottom_uvCoords[4];
static GLfloat top_uvCoords[4];
#endif

@implementation Fluid2DObject

@synthesize force, diffusion, viscosity, vorticity, dissipation, projectTwice, gravity;
@synthesize displayTexture = _iDisplayTexture;
@synthesize delegate;
@synthesize advectTemperature, kT, kFa, kFb;
@synthesize isFire, kReaction;
@synthesize displayChoice;
@synthesize blendFactor;
@synthesize turbulence;


BOOL CheckForExtension(NSString *searchName)
{
	// For performance, the array can be created once and cached.
    NSString *extensionsString = [NSString stringWithCString:(const char *)glGetString(GL_EXTENSIONS) encoding: NSASCIIStringEncoding];
    
	NSArray *extensionsNames = [extensionsString componentsSeparatedByString:@" "];

    return [extensionsNames containsObject: searchName];
}


void PrintAllExtensions()
{
	// For performance, the array can be created once and cached.
    NSString *extensionsString = [NSString stringWithCString:(const char *)glGetString(GL_EXTENSIONS) encoding: NSASCIIStringEncoding];

    NSArray *extensionsNames = [extensionsString componentsSeparatedByString:@" "];

	printf("\nExtensions:\n");
	for (NSString *oneExtension in extensionsNames) {
		printf("%s\n", [oneExtension UTF8String]);
	}
}

#define PRINT_GL_VALUE(value) 			\
{										\
	GLint result;						\
	const char* name = #value;			\
	glGetIntegerv((value), &result);	\
	printf("%s = %d\n", name, result);	\
}

void printGLCapabilities()
{
	// Print out device specific capabilities...
	
	// Common values for ES1.1 and ES2.0
	PRINT_GL_VALUE(GL_MAX_TEXTURE_SIZE);
	PRINT_GL_VALUE(GL_DEPTH_BITS);
	PRINT_GL_VALUE(GL_STENCIL_BITS);
	
	// values for ES2.0
	PRINT_GL_VALUE(GL_MAX_VERTEX_ATTRIBS);
	PRINT_GL_VALUE(GL_MAX_VERTEX_UNIFORM_VECTORS);
	PRINT_GL_VALUE(GL_MAX_FRAGMENT_UNIFORM_VECTORS);
	PRINT_GL_VALUE(GL_MAX_VARYING_VECTORS);
	PRINT_GL_VALUE(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS);
	PRINT_GL_VALUE(GL_MAX_TEXTURE_IMAGE_UNITS);
	
	PrintAllExtensions();
}


- (id) initWithDim:(int)N
{
//	printGLCapabilities();
	
	GLint result;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &result);
	if (result < N) {
		NSLog(@"Max texture size for this device is: %d. Requested N is: %d", result, N);
		return nil;
	}

	if (!CheckForExtension(@"GL_EXT_color_buffer_half_float"))
	{
		NSLog(@"Cannot run this program because this device doesn't support GL_EXT_color_buffer_half_float");

		return nil;
	}

	glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &result);
	int numTexUnits = 5;
	if (result < numTexUnits) {
		// numTexUnits texture units are used when advecting velocity influenced by temperature and density
		NSLog(@"Not enough texture units available to the fragment shader: %d. We need %d", result, numTexUnits);
		return nil;
	}

	

	self = [super init];
	if(self != nil)
	{
		
		
		_N = N;

		// set up the defaults
		diffusion = 0.0f;
		viscosity = 0.0f;
		force = 5.0f;
		vorticity = 0.3;
		dissipation = 1.0;
		projectTwice = NO;
		displayChoice = F2D_DisplayDensity;
		blendFactor = 1.0;
		turbulence = 0.0;
		
		_iNumPoissonSteps = 21;		// make this odd
		

		
//		debugImage = new GLhalf[_N * _N * 4];
		
		_pixelWidth = 1.0 / (float)_N;
		float halfPixel = _pixelWidth * 0.5;
		
		
		_sMin = _pixelWidth;
		_sMax = 1.0 - _pixelWidth;
		_tMin = _pixelWidth;
		_tMax = 1.0 - _pixelWidth;
		
#if kUseVAOs
		sim_mesh[0] = _pixelWidth;
		sim_mesh[1] = _pixelWidth;
		sim_mesh[2] = 0.0;
		sim_mesh[3] = _sMin;
		sim_mesh[4] = _tMin;

		sim_mesh[5] = 1.0 - _pixelWidth;
		sim_mesh[6] = _pixelWidth;
		sim_mesh[7] = 0.0;
		sim_mesh[8] = _sMax;
		sim_mesh[9] = _tMin;
		
		sim_mesh[10] = _pixelWidth;
		sim_mesh[11] = 1.0 - _pixelWidth;
		sim_mesh[12] = 0.0;
		sim_mesh[13] = _sMin;
		sim_mesh[14] = _tMax;
		
		sim_mesh[15] = 1.0 - _pixelWidth;
		sim_mesh[16] = 1.0 - _pixelWidth;
		sim_mesh[17] = 0.0;
		sim_mesh[18] = _sMax;
		sim_mesh[19] = _tMax;
#else
		sim_vertices[0] = _pixelWidth;
		sim_vertices[1] = _pixelWidth;
		sim_vertices[2] = 0.0;
		sim_vertices[3] = 1.0 - _pixelWidth;
		sim_vertices[4] = _pixelWidth;
		sim_vertices[5] = 0.0;
		sim_vertices[6] = _pixelWidth;
		sim_vertices[7] = 1.0 - _pixelWidth;
		sim_vertices[8] = 0.0;
		sim_vertices[9] = 1.0 - _pixelWidth;
		sim_vertices[10] = 1.0 - _pixelWidth;
		sim_vertices[11] = 0.0;
		
		sim_uvCoords[0] = _sMin;
		sim_uvCoords[1] = _tMin;
		sim_uvCoords[2] = _sMax;
		sim_uvCoords[3] = _tMin;
		sim_uvCoords[4] = _sMin;
		sim_uvCoords[5] = _tMax;
		sim_uvCoords[6] = _sMax;
		sim_uvCoords[7] = _tMax;
#endif
		
		_xMin = halfPixel;
		_xMax = (1.0 - halfPixel);
		_yMin = (_pixelWidth + halfPixel);
		_yMax = (1.0 - _pixelWidth + halfPixel);
		
#if kUseVAOs
		left_mesh[0] = _xMin;
		left_mesh[1] = _yMin;
		left_mesh[2] = 0.0;
		left_mesh[3] = 0.0;
		left_mesh[4] = _tMin;
		left_mesh[5] = _xMin;
		left_mesh[6] = _yMax;
		left_mesh[7] = 0.0;
		left_mesh[8] = 0.0;
		left_mesh[9] = _tMax;
		
		right_mesh[0] = _xMax;
		right_mesh[1] = _yMin;
		right_mesh[2] = 0.0;
		right_mesh[3] = _sMax + _pixelWidth;
		right_mesh[4] = _tMin;
		right_mesh[5] = _xMax;
		right_mesh[6] = _yMax;
		right_mesh[7] = 0.0;
		right_mesh[8] = _sMax + _pixelWidth;
		right_mesh[9] = _tMax;

		bottom_mesh[0] = _xMin + _pixelWidth;
		bottom_mesh[1] = _yMin - halfPixel;
		bottom_mesh[2] = 0.0;
		bottom_mesh[3] = _pixelWidth;
		bottom_mesh[4] = 0.0;
		bottom_mesh[5] = _xMax + _pixelWidth;
		bottom_mesh[6] = _yMin - halfPixel;
		bottom_mesh[7] = 0.0;
		bottom_mesh[8] = _sMax;
		bottom_mesh[9] = 0.0;

		top_mesh[0] = _xMin + _pixelWidth;
		top_mesh[1] = _yMax;
		top_mesh[2] = 0.0;
		top_mesh[3] = _pixelWidth;
		top_mesh[4] = 1.0;
		top_mesh[5] = _xMax + _pixelWidth;
		top_mesh[6] = _yMax;
		top_mesh[7] = 0.0;
		top_mesh[8] = _sMax;
		top_mesh[9] = 1.0;
#else
		left_vertices[0] = _xMin;
		left_vertices[1] = _yMin;
		left_vertices[2] = 0.0;
		left_vertices[3] = _xMin;
		left_vertices[4] = _yMax;
		left_vertices[5] = 0.0;
		
		right_vertices[0] = _xMax;
		right_vertices[1] = _yMin;
		right_vertices[2] = 0.0;
		right_vertices[3] = _xMax;
		right_vertices[4] = _yMax;
		right_vertices[5] = 0.0;
		
		bottom_vertices[0] = _xMin + _pixelWidth;
		bottom_vertices[1] = _yMin - halfPixel;
		bottom_vertices[2] = 0.0;
		bottom_vertices[3] = _xMax + _pixelWidth;
		bottom_vertices[4] = _yMin - halfPixel;
		bottom_vertices[5] = 0.0;
		
		top_vertices[0] = _xMin + _pixelWidth;
		top_vertices[1] = _yMax;
		top_vertices[2] = 0.0;
		top_vertices[3] = _xMax + _pixelWidth;
		top_vertices[4] = _yMax;
		top_vertices[5] = 0.0;
		
		left_uvCoords[0] = 0.0;
		left_uvCoords[1] = _tMin;
		left_uvCoords[2] = 0.0;
		left_uvCoords[3] = _tMax;
		
		right_uvCoords[0] = _sMax + _pixelWidth;
		right_uvCoords[1] = _tMin;
		right_uvCoords[2] = _sMax + _pixelWidth;
		right_uvCoords[3] = _tMax;
		
		bottom_uvCoords[0] = _pixelWidth;
		bottom_uvCoords[1] = 0.0;
		bottom_uvCoords[2] = _sMax;
		bottom_uvCoords[3] = 0.0;
		
		top_uvCoords[0] = _pixelWidth;
		top_uvCoords[1] = 1.0;
		top_uvCoords[2] = _sMax;
		top_uvCoords[3] = 1.0;
#endif

		[self createTextures];
		
		[self loadShaders];

#if kUseVAOs

		// make sure there's nothing else bound
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
		

		// The Simulation quad
		glGenVertexArraysOES(1, &_vertexArrayObjectSim);
		glBindVertexArrayOES(_vertexArrayObjectSim);
		
		glGenBuffers(1, &_vertexBufferSim);
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferSim);
		glBufferData(GL_ARRAY_BUFFER, sizeof(sim_mesh), &sim_mesh[0], GL_STATIC_DRAW);

		GLuint vertexAttrib = [displayShader attributeHandle:@"position"];
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
		
		GLuint textureAttrib = [displayShader attributeHandle:@"inTexCoord"];
		glEnableVertexAttribArray(textureAttrib);
		glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(12));
		
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
		GetGLError();
		

		// The full square quad
		glGenVertexArraysOES(1, &_vertexArrayObjectFull);
		glBindVertexArrayOES(_vertexArrayObjectFull);
		
		glGenBuffers(1, &_vertexBufferFull);
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferFull);
		glBufferData(GL_ARRAY_BUFFER, sizeof(square_mesh), &square_mesh[0], GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
		
		glEnableVertexAttribArray(textureAttrib);
		glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(12));
		
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
		GetGLError();
		

		// The left line
		glGenVertexArraysOES(1, &_vertexArrayObjectLeft);
		glBindVertexArrayOES(_vertexArrayObjectLeft);
		
		glGenBuffers(1, &_vertexBufferLeft);
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferLeft);
		glBufferData(GL_ARRAY_BUFFER, sizeof(left_mesh), &left_mesh[0], GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
		
		glEnableVertexAttribArray(textureAttrib);
		glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(12));
		
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
		GetGLError();

		// The right line
		glGenVertexArraysOES(1, &_vertexArrayObjectRight);
		glBindVertexArrayOES(_vertexArrayObjectRight);
		
		glGenBuffers(1, &_vertexBufferRight);
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferRight);
		glBufferData(GL_ARRAY_BUFFER, sizeof(right_mesh), &right_mesh[0], GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
		
		glEnableVertexAttribArray(textureAttrib);
		glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(12));
		
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
		GetGLError();
		
		// The bottom line
		glGenVertexArraysOES(1, &_vertexArrayObjectBottom);
		glBindVertexArrayOES(_vertexArrayObjectBottom);
		
		glGenBuffers(1, &_vertexBufferBottom);
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferBottom);
		glBufferData(GL_ARRAY_BUFFER, sizeof(bottom_mesh), &bottom_mesh[0], GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
		
		glEnableVertexAttribArray(textureAttrib);
		glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(12));
		
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
		GetGLError();
		
		// The top line
		glGenVertexArraysOES(1, &_vertexArrayObjectTop);
		glBindVertexArrayOES(_vertexArrayObjectTop);
		
		glGenBuffers(1, &_vertexBufferTop);
		glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferTop);
		glBufferData(GL_ARRAY_BUFFER, sizeof(top_mesh), &top_mesh[0], GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(vertexAttrib);
		glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(0));
		
		glEnableVertexAttribArray(textureAttrib);
		glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 5 * sizeof(GL_FLOAT), BUFFER_OFFSET(12));
		
		glBindVertexArrayOES(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		
		GetGLError();
		
#endif

		// create some zeros with which to clear the textures
		// 4 is the number of components (RGBA)
		_zeros = new GLhalf[_N * _N * 4];
		_zerosB = new GLubyte[_N * _N * 4];

		memset(_zeros, 0, _N * _N * 4 * sizeof(GLhalf));
		memset(_zerosB, 0, _N * _N * 4 * sizeof(GLubyte));
		
		// clear the textures
		[self reset];
		
		self.projectionMatrix = GLKMatrix4MakeOrtho(0, 1, 0, 1, -1, 1);
		
		self.modelViewMatrix = GLKMatrix4Identity;
		_modelViewProjectionMatrix = GLKMatrix4Multiply(self.projectionMatrix, self.modelViewMatrix);
		
	}
	
	return self;
	
}

- (void) dealloc
{
#if kUseVAO
	glDeleteBuffers(1, &_vertexBufferSim);
    glDeleteVertexArraysOES(1, &_vertexArrayObjectSim);
#endif
}


- (void) createTextures
{
	
	// create texture objects -- there are four: velocity, pressure, divergence,
	// and density.  All are float textures.
	glGenTextures(TEXTURE_COUNT, _iTextures);
	
	int iTex = 0;
	for (iTex = 0; iTex < TEXTURE_COUNT; ++iTex)
	{
		glBindTexture(GL_TEXTURE_2D, _iTextures[iTex]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _N, _N, 0, GL_RGBA, GL_HALF_FLOAT_OES, NULL);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
	}
	
	// **** create the offscreen framebuffer object ****
	
	glGenFramebuffers(1, &_iOffScreenFBO);
	glBindFramebuffer(GL_FRAMEBUFFER, _iOffScreenFBO);
	
	// attach the velocity texture for now
	
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY0], 0);
	
	// test for completeness
	
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
	if(status != GL_FRAMEBUFFER_COMPLETE) {
		NSLog(@"FluidObject: failed to make complete the offscreen framebuffer object %x", status);
	}
	
	
	
	// create the display texture
	glGenTextures(1, &_iDisplayTexture);
	glBindTexture(GL_TEXTURE_2D, _iDisplayTexture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _N, _N, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);


	NSError *error;
	self.fireTexInfo = [GLKTextureLoader textureWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"fireTex1d" ofType:@"png"] options:nil error:&error];
	if (self.fireTexInfo == nil) {
		NSLog(@"fire texture is NIL!");
		NSLog(@"%@",[error localizedDescription]);
	}
	
} // createTextures


- (void) loadShaders
{
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"display" ofType:@"plist"]];
	displayShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"splat" ofType:@"plist"]];
	splatShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"boundary" ofType:@"plist"]];
	boundaryShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"advect" ofType:@"plist"]];
	advectShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"divergence" ofType:@"plist"]];
	divergenceShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"jacobi" ofType:@"plist"]];
	jacobiShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"gradient" ofType:@"plist"]];
	gradientShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"vorticity" ofType:@"plist"]];
	vorticityShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"vortForce" ofType:@"plist"]];
	vortForceShader = [[Shader alloc] initWithShaderSettings:dict];
	
	
//	dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"present" ofType:@"plist"]];
//	presentShader = [[Shader alloc] initWithShaderSettings:dict];
	
} // loadShaders


- (void) reset
{
	int iTex = 0;
	// clear all textures to zero.
	for (iTex = 0; iTex < TEXTURE_COUNT; ++iTex)
	{
		glBindTexture(GL_TEXTURE_2D, _iTextures[iTex]);
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, _N, _N, GL_RGBA, GL_HALF_FLOAT_OES, _zeros);
	}
	
	
	glBindTexture(GL_TEXTURE_2D, _iDisplayTexture);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, _N, _N, GL_RGBA, GL_UNSIGNED_BYTE, _zerosB);
	
} // reset


- (void) drawScalar:(GLuint)texID scale:(float)scale
{
	[displayShader useShader];

    glUniformMatrix4fv([displayShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// bind the offscreen framebuffer
	glBindFramebuffer(GL_FRAMEBUFFER, _iOffScreenFBO);
	
	// attach the display texture to the offscreen FBO so we draw into it
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iDisplayTexture, 0);
	
	// bind the given texture as the input
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	glUniform1i([displayShader uniformLocation:@"texture"], 0);
	
	// bind the reaction texture
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, self.fireTexInfo.name);
	glUniform1i([displayShader uniformLocation:@"reaction"], 1);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectFull);
#else
	GLuint vertexAttrib = [displayShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &square_vertices[0]);
	
	GLuint textureAttrib = [displayShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &square_uvCoords[0]);
#endif
	
	glUniform4f([displayShader uniformLocation:@"bias"], 0.0, 0.0, 0.0, 0.0);
	glUniform4f([displayShader uniformLocation:@"scale"], scale, scale, scale, 1.0);
	
	// is this fire?
	glUniform1i([displayShader uniformLocation:@"isFire"], self.isFire);
	
	// draw the quad. This copies the given texture to the display texture
//	glViewport(0, 0, _N, _N);
//	glClear(GL_COLOR_BUFFER_BIT);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
	// now the display texture has the desired image.
	
//	[self dumpTexture];
	
} // drawScalar


- (void) drawVector:(GLuint)texID scale:(float)scale
{
	[displayShader useShader];
    glUniformMatrix4fv([displayShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// change the range from [-1..1] to [0..1]
	glUniform4f([displayShader uniformLocation:@"bias"], 0.5, 0.5, 0.5, 0.5);
	glUniform4f([displayShader uniformLocation:@"scale"], 0.5 * scale, 0.5 * scale, 0.5 * scale, 0.5 * scale);
	
	// bind the offscreen framebuffer
	glBindFramebuffer(GL_FRAMEBUFFER, _iOffScreenFBO);
	
	// attach the display texture to the offscreen FBO so we draw into it
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iDisplayTexture, 0);
	
	// read from the velocity texture
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	// Set the sampler2D uniform to corresponding texture unit
	glUniform1i([displayShader uniformLocation:@"texture"], 0);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectFull);
#else
	GLuint vertexAttrib = [displayShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &square_vertices[0]);
	
	GLuint textureAttrib = [displayShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &square_uvCoords[0]);
#endif
//	glViewport(0, 0, _N, _N);
//	glClear(GL_COLOR_BUFFER_BIT);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	GetGLError();
	
} // drawVector


#define kAdvectOnly 0


- (void)updateWithDt:(float)Dt
{
	// make sure there's nothing else bound
	glBindVertexArrayOES(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	
	_Dt = Dt;
	
	glViewport(0, 0, _N, _N);
	
	glClearColor(0.0, 0.0, 0.0, 0.0);

	// bind the offscreen FBO
	glBindFramebuffer(GL_FRAMEBUFFER, _iOffScreenFBO);
	
//    glClear(GL_COLOR_BUFFER_BIT);

	// When modifying an array (e.g. vel -> vel)...
	// 0 is always the input
	// 1 is always the output
	// always swap the final result back to 0
	// always set boundaries on the result
	
	
	
	
	if (self.projectTwice) {
		// this makes the simulation behave better, but is costly in terms of performance
		
		[delegate getExternalInput];
		
		//---------------
		// 4. Project divergent velocity into divergence-free field
		//---------------
		
		//---------------
		// 4a. compute divergence
		//---------------
		// Compute the divergence of the velocity field
		
		[self divergence];
		
		//---------------
		// 4b. Compute pressure disturbance
		//---------------
		// Solve for the pressure disturbance caused by the divergence, by solving
		// the poisson problem Laplacian(p) = div(u)
		
		[self pressureDisturbance];
		
		//---------------
		// 4c. Subtract gradient(p) from u
		//---------------
		// This gives us our final, divergence free velocity field.
		
		[self gradient];
		
		[self swapTexturesX0:TEXTURE_VELOCITY0 x:TEXTURE_VELOCITY fbo:_iOffScreenFBO];
		
		[self setVectorBoundariesOnTexture:_iTextures[TEXTURE_VELOCITY0] scale:-1];
	
	}
	
	
	
	
	//---------------
	// 1.  Advect
	//---------------
	// Advect velocity (velocity advects itself, resulting in a divergent
	// velocity field.  Later, correct this divergence).
	
	
				
//	[self setVectorBoundariesOnTexture:_iTextures[TEXTURE_VELOCITY0] scale:-1];
	
	// attach the velocity output texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY], 0);
	
	
	[self advect:_iTextures[TEXTURE_VELOCITY0]];
	
//	printf("\nAfter advection...\n");
//	[self dumpTexture];

	[self swapTexturesX0:TEXTURE_VELOCITY0 x:TEXTURE_VELOCITY fbo:_iOffScreenFBO];
	
	// Set the no-slip velocity...
	// This sets the scale to -1, so that v[0, j] = -v[1, j], so that at
	// the boundary between them, the avg. velocity is zero.
	[self setVectorBoundariesOnTexture:_iTextures[TEXTURE_VELOCITY0] scale:-1];
	
		
	
	// Advect the "ink"
	
	
	[self setScalarBoundariesOnTexture:_iTextures[TEXTURE_DENSITY0] scale:0];
	
	// attach the density output texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_DENSITY], 0);
	
	
	[self advect:_iTextures[TEXTURE_DENSITY0]];
	
	[self swapTexturesX0:TEXTURE_DENSITY0 x:TEXTURE_DENSITY fbo:_iOffScreenFBO];
	
//	[self dumpTexture];
		
	
	// Advect the temperature
	
	if (advectTemperature) {
		
		// attach the temperature output texture to the offscreen FBO
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_TEMPERATURE], 0);
		
		[self advect:_iTextures[TEXTURE_TEMPERATURE0]];
		
		[self swapTexturesX0:TEXTURE_TEMPERATURE0 x:TEXTURE_TEMPERATURE fbo:_iOffScreenFBO];
	
		[self setScalarBoundariesOnTexture:_iTextures[TEXTURE_TEMPERATURE0] scale:0];
	}
	
	//---------------
	// 2. Add Impulse
	//---------------
	
	if (!self.projectTwice) {
		[delegate getExternalInput];
	}
	
	//---------------
	// 3. Apply Vorticity Confinement
	//---------------
	
#if !kAdvectOnly
	if (vorticity > 0) {
		[self vorticityComputation];
	}
#endif
	//---------------
	// 3. Diffuse (if viscosity is > 0)
	//---------------
	// If this is a viscous fluid, solve the poisson problem for the viscous
	// diffusion
	

	//---------------
	// 4. Project divergent velocity into divergence-free field
	//---------------
	
	//---------------
	// 4a. compute divergence
	//---------------
	// Compute the divergence of the velocity field
#if !kAdvectOnly
	[self divergence];
#endif
	//---------------
	// 4b. Compute pressure disturbance
	//---------------
	// Solve for the pressure disturbance caused by the divergence, by solving
	// the poisson problem Laplacian(p) = div(u)
	
#if !kAdvectOnly
	[self pressureDisturbance];
#endif
	//---------------
	// 4c. Subtract gradient(p) from u
	//---------------
	// This gives us our final, divergence free velocity field.
#if !kAdvectOnly
	
	[self gradient];
	
	[self swapTexturesX0:TEXTURE_VELOCITY0 x:TEXTURE_VELOCITY fbo:_iOffScreenFBO];
	
	[self setVectorBoundariesOnTexture:_iTextures[TEXTURE_VELOCITY0] scale:-1];
#endif
	
	switch (displayChoice) {
		case F2D_DisplayDensity:
		default:
			[self drawScalar:_iTextures[TEXTURE_DENSITY0] scale:1.0];
			break;
		case F2D_DisplayVelocity:
			[self drawVector:_iTextures[TEXTURE_VELOCITY0] scale:10.0];
			break;
		case F2D_DisplayDivergence:
			[self drawVector:_iTextures[TEXTURE_DIVERGENCE] scale:1000.0];
			break;
		case F2D_DisplayPressure:
			[self drawVector:_iTextures[TEXTURE_PRESSURE0] scale:10000.0];
			break;
		case F2D_DisplayObstacles:
			[self drawVector:_iTextures[TEXTURE_OBSTACLES] scale:1.0];
			break;
		case F2D_DisplayTemperature:
			[self drawVector:_iTextures[TEXTURE_TEMPERATURE0] scale:0.1];
			break;
	}

	GetGLError();

} // update


static GLhalf debugImage[theN][theN][4];


- (void) dumpTexture
{
	
	// bind the velocity FBO
	glBindFramebuffer(GL_FRAMEBUFFER, _iOffScreenFBO);
	GetGLError();
	
	glReadPixels( 0, 0, _N, _N, GL_RGBA, GL_HALF_FLOAT_OES, &debugImage );
	GetGLError();
	
	Float16Compressor *f16c = new(Float16Compressor);
	
	int x, y;
//	printf("\nDebug texure...\n");
	for (y = _N-1; y >= 0; y--) {
		for (x = 0; x < _N; x++) {
			
//			printf("[%6.4f, %6.4f, %6.4f, %6.4f] ",
			printf("[%7.4f, %7.4f] ",
				   f16c->decompress( debugImage[y][x][0] ),
				   f16c->decompress( debugImage[y][x][1] )
//				   f16c->decompress( debugImage[y][x][2] ),
//				   f16c->decompress( debugImage[y][x][3] )
				   );
			
		}
		printf("\n");
	}
	
	delete f16c;
	
} // dumpTexture



#pragma mark - Simulation methods

- (void) injectColorR:(float)r g:(float)g b:(float)b atX:(float)x y:(float)y withRadius:(float)radius;
{
	[self generateSplatX:x y:y dx:0 dy:0 r:r g:g b:b radius:radius inTex:_iTextures[TEXTURE_DENSITY0] blend:blendFactor];

	[self swapTexturesX0:TEXTURE_DENSITY0 x:TEXTURE_DENSITY fbo:_iOffScreenFBO];
}

- (void) injectVelocityDX:(float)dx dy:(float)dy atX:(float)x y:(float)y withRadius:(float)radius;
{
	[self generateSplatX:x y:y dx:dx dy:dy r:0.0 g:0.0 b:0.0 radius:radius inTex:_iTextures[TEXTURE_VELOCITY0] blend:0.0];

//	printf("\nAfter injection...\n");
//	[self dumpTexture];
	
	[self swapTexturesX0:TEXTURE_VELOCITY0 x:TEXTURE_VELOCITY fbo:_iOffScreenFBO];
}

- (void) injectSmokeR:(float)r g:(float)g b:(float)b atX:(float)x y:(float)y withTemperature:(float)temp andRadius:(float)radius;
{
	[self generateSplatX:x y:y dx:0 dy:0 r:r g:g b:b radius:radius inTex:_iTextures[TEXTURE_DENSITY0] blend:1.0];
	[self swapTexturesX0:TEXTURE_DENSITY0 x:TEXTURE_DENSITY fbo:_iOffScreenFBO];

	[self generateSplatX:x y:y dx:0 dy:0 r:temp g:0 b:0 radius:radius inTex:_iTextures[TEXTURE_TEMPERATURE0] blend:1.0];
	[self swapTexturesX0:TEXTURE_TEMPERATURE0 x:TEXTURE_TEMPERATURE fbo:_iOffScreenFBO];
}


- (void) generateSplatX:(float)x y:(float)y
					 dx:(float)dx dy:(float)dy
					  r:(float)r g:(float)g b:(float)b
				 radius:(float)radius
				  inTex:(GLuint)texID
				  blend:(float)blend
{
	// Generate a gaussian "splat" in the specified texture at the given coords
	
	// make sure there's nothing else bound
	glBindVertexArrayOES(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	
	// use the splat shader program
	[splatShader useShader];
	
	if (texID == _iTextures[TEXTURE_DENSITY0]) {
		
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_DENSITY], 0);
		
		glUniform4f([splatShader uniformLocation:@"color"], r, g, b, 1.0);
		GetGLError();
	}
	else if (texID == _iTextures[TEXTURE_VELOCITY0]) {
		
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY], 0);
		
		glUniform4f([splatShader uniformLocation:@"color"], dx, dy, 0.0, 0.0);
		
	}
	else if (texID == _iTextures[TEXTURE_TEMPERATURE0]) {
		
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_TEMPERATURE], 0);
		
		glUniform4f([splatShader uniformLocation:@"color"], r, 0.0, 0.0, 0.0);
		
	}
	
	// blend factor
	glUniform1f([splatShader uniformLocation:@"blend"], blend);
	
	// pass the project matrix
	glUniformMatrix4fv([splatShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	
	// Set the sampler2D uniform to texture unit 0
	glUniform1i([splatShader uniformLocation:@"base"], 0);
	
	// pass the position of the splat...
	
	// the position in texture coords
	glUniform2f([splatShader uniformLocation:@"position"], x, y);
	
	// pass the radius
	glUniform1f([splatShader uniformLocation:@"radius"], radius);
	
	// pass the viewport dimensions
	glUniform2f([splatShader uniformLocation:@"windowDims"], 1.0, 1.0);
	
	glUniform1i([splatShader uniformLocation:@"isDigital"], 0);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [splatShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	GLuint textureAttrib = [splatShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	GetGLError();
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
} // generateSplatX


- (void) generateObstacleX:(float)x y:(float)y velocityX:(float)vx vy:(float)vy radius:(float)radius
{
	// Generate a digital "splat" in the obstacles texture at the given window (mouse) coords
	
	//	printf("obstacle: x = %d, y = %d, vx = %f, vy = %f\n", x, y, vx, vy);
	
	glViewport(0, 0, _N, _N);
	
	// bind the offscreen FBO
	glBindFramebuffer(GL_FRAMEBUFFER, _iOffScreenFBO);
	
	
	// attach the obstacles texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_OBSTACLES], 0);
	GetGLError();
	
	//	glClear(GL_COLOR_BUFFER_BIT);
	
	// use the splat shader program
	[splatShader useShader];
	
	// z coord is used to indicate this is an obstacle
	glUniform4f([splatShader uniformLocation:@"color"], vx, vy, 1.0, 0.0);
	GetGLError();
	
	// blend factor
	glUniform1f([splatShader uniformLocation:@"blend"], 0.0);
	GetGLError();
	
	// pass the project matrix
	glUniformMatrix4fv([splatShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	GetGLError();
	
	// pass the position of the splat...
	glUniform2f([splatShader uniformLocation:@"position"], x, y);
	GetGLError();
	
	// pass the radius
	glUniform1f([splatShader uniformLocation:@"radius"], radius);
	GetGLError();
	
	// pass the viewport dimensions
	glUniform2f([splatShader uniformLocation:@"windowDims"], 1.0, 1.0);
	GetGLError();
	
	glUniform1i([splatShader uniformLocation:@"isDigital"], 1);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [splatShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	GetGLError();
	
	GLuint textureAttrib = [splatShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
	GetGLError();
#endif

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	GetGLError();
	
} // generateObstacle


- (void) swapTexturesX0:(GLuint)x0 x:(GLuint)x fbo:(GLuint)fbo
{
	GLuint tmp = _iTextures[x0];
	_iTextures[x0] = _iTextures[x];
	_iTextures[x] = tmp;
	
} // swapTextures


- (void) advect:(GLuint)texID
{
	
	// use the advect shader program
	[advectShader useShader];
	
	// pass the projection matrix
	glUniformMatrix4fv([advectShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// bind the input texture of what we're advecting to texture unit 0
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	// Set the x sampler2D uniform to texture unit 0
	glUniform1i([advectShader uniformLocation:@"x"], 0);
	
	// bind the velocity texture to texture unit 1, because it will always be the velocity that advects whatever
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY0]);
	// Set the u sampler2D uniform to texture unit 1
	glUniform1i([advectShader uniformLocation:@"u"], 1);
	
	// bind the obstacles texture to texture unit 2
	glActiveTexture(GL_TEXTURE2);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_OBSTACLES]);
	GetGLError();
	// Set the obstacles sampler2D uniform to texture unit 2
	glUniform1i([advectShader uniformLocation:@"obstacles"], 2);
	GetGLError();
	
	float isVelocity = 0.0;
	if (texID == _iTextures[TEXTURE_VELOCITY0]) {
		isVelocity = 1.0;
	}
	
	// pass the constant for advecting temperature
	// Not really needed since we just move it around, but it could
	// be used to accelerate cooling.
	float theKT = 0.0;
	
//	if (texID == _iTextures[TEXTURE_TEMPERATURE0]) {
//		theKT = kT;
//	} else {
//		theKT = 0.0;
//	}

	glUniform1f([advectShader uniformLocation:@"kT"], theKT);
	
	// pass the reaction constant
	float kR = 0.0;
	if (self.isFire && (isVelocity == 0)) {
		kR = kReaction;
	}

	if (isVelocity && advectTemperature) {
		// bind the temperature texture to texture unit 3
		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_TEMPERATURE0]);
		GetGLError();
		// Set the temperature sampler2D uniform to texture unit 3
		glUniform1i([advectShader uniformLocation:@"temperature"], 3);
		GetGLError();

		// bind the denisty texture to texture unit 4
		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_DENSITY0]);
		GetGLError();
		// Set the density sampler2D uniform to texture unit 4
		glUniform1i([advectShader uniformLocation:@"density"], 4);
		GetGLError();
		
		// pass the constant for force of bouyancy due to density
		glUniform1f([advectShader uniformLocation:@"kFa"], kFa);

		// pass the constant for force of bouyancy due to temperature
		glUniform1f([advectShader uniformLocation:@"kFb"], kFb);
	}
	else {
		glUniform1f([advectShader uniformLocation:@"kFa"], 0.0);
		glUniform1f([advectShader uniformLocation:@"kFb"], 0.0);
	}
	
//	if (isVelocity) {
//		glUniform1f([advectShader uniformLocation:@"kT"], turbulence);
//	} else {
//		glUniform1f([advectShader uniformLocation:@"kT"], 0.0);
//	}

	
	// pass the timestep
	glUniform1f([advectShader uniformLocation:@"timestep"], _Dt);
	
	float theDiss = self.dissipation;
	if (isVelocity) {
		// don't dissipate velocity
		theDiss = 0.99;
	}
	glUniform1f([advectShader uniformLocation:@"dissipation"], theDiss);
	
	// pass the simulation dimensions
	glUniform1f([advectShader uniformLocation:@"rdx"], (float)_N);
	
	glUniform2f([advectShader uniformLocation:@"gravity"], self.gravity.x, self.gravity.y);

	glUniform1f([advectShader uniformLocation:@"kR"], kR);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [advectShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	GLuint textureAttrib = [advectShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif
	// draw the quad
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	GetGLError();
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
} // advect


- (void) gradient
{
	
	// attach the velocity output texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY], 0);
	
	// use the gradient shader program
	[gradientShader useShader];
	
	// pass the projection matrix
	glUniformMatrix4fv([gradientShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// pass the 'p' sampler (pressure)
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_PRESSURE0]);
	// Set the sampler2D uniform to texture unit 0
	glUniform1i([gradientShader uniformLocation:@"p"], 0);
	
	// pass the 'w' sampler (velocity)
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY0]);
	// Set the sampler2D uniform to texture unit 1
	glUniform1i([gradientShader uniformLocation:@"w"], 1);
	
	// bind the obstacles texture to texture unit 2
	glActiveTexture(GL_TEXTURE2);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_OBSTACLES]);
	GetGLError();
	// Set the obstacles sampler2D uniform to texture unit 2
	glUniform1i([gradientShader uniformLocation:@"obstacles"], 2);
	GetGLError();
	
	
	// pass resolution of the simulation
	glUniform1f([gradientShader uniformLocation:@"simDim"], _N);
	
	// the vertex attributes
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [gradientShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	GLuint textureAttrib = [gradientShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif
	// draw the quad
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
} // gradient



- (void) pressureDisturbance
{
	// input0 is pressure
	// input1 is divergence
	// output to pressure
		
	// attach the pressure input texture to the offscreen FBO so we can clear it
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_PRESSURE0], 0);
	
	// Clear the pressure texture, to initialize the pressure disturbance to
	// zero before iterating.  If this is disabled, the solution converges
	// faster, but tends to have oscillations.
	
	glClear(GL_COLOR_BUFFER_BIT);
	
	// use the jacobi shader program
	[jacobiShader useShader];
	
	// pass the projection matrix
	glUniformMatrix4fv([jacobiShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	
	// pass the 'b' sampler (divergence)
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_DIVERGENCE]);
	// Set the sampler2D uniform to texture unit 1
	glUniform1i([jacobiShader uniformLocation:@"b"], 1);
	
	
	// pass the 'x' sampler (pressure)
	// Set the sampler2D uniform to texture unit 0
	glUniform1i([jacobiShader uniformLocation:@"x"], 0);
	
	
	// bind the obstacles texture to texture unit 2
	glActiveTexture(GL_TEXTURE2);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_OBSTACLES]);
	GetGLError();
	// Set the obstacles sampler2D uniform to texture unit 2
	glUniform1i([jacobiShader uniformLocation:@"obstacles"], 2);
	GetGLError();
	
	
	// pass resolution of the simulation
	glUniform1f([jacobiShader uniformLocation:@"simDim"], _N);
	
	// pass alpha
	//	glUniform1f([jacobi uniformLocation:@"alpha"], -Nsim * Nsim);
	glUniform1f([jacobiShader uniformLocation:@"alpha"], 1.0);
	
	// pass beta
	glUniform1f([jacobiShader uniformLocation:@"beta"], 0.25);
	
	
	// the vertex attributes
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [jacobiShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	GLuint textureAttrib = [jacobiShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif
//	_iNumPoissonSteps = 3;
	
	for (int i = 0; i < _iNumPoissonSteps; ++i)
	{
		// attach the new pressure output texture to the offscreen FBO
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_PRESSURE], 0);

		// bind the new pressure intput texture to texture unit 0
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_PRESSURE0]);
		
		// draw the quad
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		GetGLError();
		
		[self swapTexturesX0:TEXTURE_PRESSURE0 x:TEXTURE_PRESSURE fbo:_iOffScreenFBO];
		
		// Apply pure neumann boundary conditions
//		[self setScalarBoundariesOnTexture:_iTextures[TEXTURE_PRESSURE0] scale:1.0];
		
	}
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
 
	// Apply pure neumann boundary conditions
	[self setScalarBoundariesOnTexture:_iTextures[TEXTURE_PRESSURE0] scale:1.0];
	

} // pressureDisturbance


- (void) vorticityComputation
{
	
	// vorticity computation.
	
	
	// use the vorticity shader program
	[vorticityShader useShader];
	
	GLuint texID0 = _iTextures[TEXTURE_VELOCITY0];	// input is velocity
	
	// output to vorticity
	
	// attach the divergence texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_VORTICITY], 0);
	
	// pass the projection matrix
	glUniformMatrix4fv([divergenceShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// Pass the velocity texture as input
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID0);
	
	glUniform1i([vorticityShader uniformLocation:@"u"], 0);
	
	// pass resolution of the simulation
	glUniform1f([vorticityShader uniformLocation:@"simDim"], _N);
	
	// the vertex attributes
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [vorticityShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	GLuint textureAttrib = [vorticityShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif
	// draw the quad
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
#if 1
	// vorticity confinement force computation.
	
	// use the vortForce shader program for the second pass
	[vortForceShader useShader];
	
	// input0 is velocity
	//	GLuint texID1 = _iTextures[TEXTURE_VELOCITY0];
	// input1 is vorticity
	GLuint texID1 = _iTextures[TEXTURE_VORTICITY];
	
	// output to velocity
	
	// attach the velocity output texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_VELOCITY], 0);
	
	//	glClear(GL_COLOR_BUFFER_BIT);
	//	GetGLError();
	
	// pass the projection matrix
	glUniformMatrix4fv([vortForceShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// Pass the velocity texture as input0
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID0);
	
	glUniform1i([vortForceShader uniformLocation:@"u"], 0);
	
	// Pass the vorticity texture as input1
	
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, texID1);
	
	glUniform1i([vortForceShader uniformLocation:@"vort"], 1);
	
	// pass resolution of the simulation
	glUniform1f([vortForceShader uniformLocation:@"simDim"], _N);
	
	// pass the timestep
	glUniform1f([vortForceShader uniformLocation:@"timestep"], _Dt);
	
	// pass the vorticity scale
	float vortScale = 0.035 * vorticity;
	glUniform2f([vortForceShader uniformLocation:@"dxscale"], vortScale * _N, vortScale * _N);
	
	// the vertex attributes
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	vertexAttrib = [vortForceShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	textureAttrib = [vortForceShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif
	// draw the quad
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
	[self swapTexturesX0:TEXTURE_VELOCITY0 x:TEXTURE_VELOCITY fbo:_iOffScreenFBO];
	
	[self setVectorBoundariesOnTexture:_iTextures[TEXTURE_VELOCITY0] scale:-1];
	
#endif
	
	
	
} // vorticity


- (void) divergence
{
	
	// use the divergence shader program
	[divergenceShader useShader];
	
	GLuint texID = _iTextures[TEXTURE_VELOCITY0];	// input is velocity
	//	GLuint fbo = _iOffScreenFBO;					// output to divergence
	
	// attach the divergence texture to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _iTextures[TEXTURE_DIVERGENCE], 0);
	
	// pass the projection matrix
	glUniformMatrix4fv([divergenceShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	// Set the sampler2D uniform to texture unit 0
	glUniform1i([divergenceShader uniformLocation:@"w"], 0);
	
	// bind the obstacles texture to texture unit 1
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, _iTextures[TEXTURE_OBSTACLES]);
	GetGLError();
	// Set the obstacles sampler2D uniform to texture unit 1
	glUniform1i([divergenceShader uniformLocation:@"obstacles"], 1);
	GetGLError();
	
	
	// pass resolution of the simulation
	glUniform1f([divergenceShader uniformLocation:@"simDim"], _N);
	
	
	// the vertex attributes
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectSim);
#else
	GLuint vertexAttrib = [divergenceShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &sim_vertices[0]);
	
	GLuint textureAttrib = [divergenceShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);
#endif
	// draw the quad
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
} // divergence


- (void) setVectorBoundariesOnTexture:(GLuint)texID scale:(float)scale
{
	[boundaryShader useShader];
	
	// we don't clear the destination because we'll be adding to it, not replacing it
	
	// attach the texture we're setting boundaries on to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texID, 0);
	
	// pass the projection matrix
	glUniformMatrix4fv([boundaryShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// pass the given texture
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	glUniform1i([boundaryShader uniformLocation:@"x"], 0);
	
	// left
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], _pixelWidth, 0);
	glUniform3f([boundaryShader uniformLocation:@"scale"], scale, 1, 0);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectLeft);
#else
	GLuint vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &left_vertices[0]);
	
	GLuint textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &left_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
	
	// top
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], 0, -_pixelWidth);
	glUniform3f([boundaryShader uniformLocation:@"scale"], 1, scale, 0);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectTop);
#else
	vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &top_vertices[0]);
	
	textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &top_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
	
	// right
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], -_pixelWidth, 0);
	glUniform3f([boundaryShader uniformLocation:@"scale"], scale, 1, 0);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectRight);
#else
	vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &right_vertices[0]);
	
	textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &right_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
	
	// bottom
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], 0, (_pixelWidth));
	glUniform3f([boundaryShader uniformLocation:@"scale"], 1, scale, 0);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectBottom);
#else
	vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &bottom_vertices[0]);
	
	textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &bottom_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
} // setVectorBoundariesOnTexture


- (void) setScalarBoundariesOnTexture:(GLuint)texID scale:(float)scale
{
	[boundaryShader useShader];
	
	// we don't clear the destination because we'll be adding to it, not replacing it
	
	// attach the texture we're setting boundaries on to the offscreen FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texID, 0);
	
	// pass the projection matrix
	glUniformMatrix4fv([boundaryShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	// pass the given texture
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texID);
	glUniform1i([boundaryShader uniformLocation:@"x"], 0);
	
	// left
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], _pixelWidth, 0);
	glUniform3f([boundaryShader uniformLocation:@"scale"], scale, scale, scale);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectLeft);
#else
	GLuint vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &left_vertices[0]);
	
	GLuint textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &left_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
	
	// top
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], 0, -_pixelWidth);
	glUniform3f([boundaryShader uniformLocation:@"scale"], scale, scale, scale);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectTop);
#else
	vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &top_vertices[0]);
	
	textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &top_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
	
	// right
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], -_pixelWidth, 0);
	glUniform3f([boundaryShader uniformLocation:@"scale"], scale, scale, scale);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectRight);
#else
	vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &right_vertices[0]);
	
	textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &right_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
	
	// bottom
	
	glUniform2f([boundaryShader uniformLocation:@"offset"], 0, (_pixelWidth));
	glUniform3f([boundaryShader uniformLocation:@"scale"], scale, scale, scale);
	
#if kUseVAOs
	glBindVertexArrayOES(_vertexArrayObjectBottom);
#else
	vertexAttrib = [boundaryShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &bottom_vertices[0]);
	
	textureAttrib = [boundaryShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &bottom_uvCoords[0]);
#endif
	glDrawArrays(GL_LINES, 0, 2);
	
#if kUseVAOs
	glBindVertexArrayOES(0);
#endif
	
} // setScalarBoundariesOnTexture



@end
