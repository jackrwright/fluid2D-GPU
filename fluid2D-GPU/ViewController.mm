//
//  ViewController.m
//  fluid2D-GPU
//
//  Created by Jack Wright on 3/20/13.
//  Copyright (c) 2013 Jack Wright. All rights reserved.
//

#import "ViewController.h"
#import "Finger.h"
#import "glUtil.h"

#define RANDOM_FLOAT() ((float)random() / (float)INT32_MAX)
#define RANDOM_FLOAT_BETWEEN(MIN,MAX) ((RANDOM_FLOAT() * ((MAX)-(MIN))) + MIN)

static bool simulating = true;

static float displayScale;
static float userForce;
static float userDiffusion;
static float userViscosity;
static float userVorticity;
static float userDissipation;
static float userTemperature;
static NSInteger userBlendMode = 1;
static NSInteger userMedium;

static int mouse_down[3];
static int win_x, win_y;

typedef struct {
	CGFloat r;
	CGFloat g;
	CGFloat b;
	CGFloat a;
} COLOR;
static COLOR source;

@interface ViewController () {
	Fluid2DObject		*_theFluidObject;
	int					_frameRate;
	Shader				*_presentShader;
    GLKMatrix4			_modelViewProjectionMatrix;
	
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo *backgroundTexInfo;
@property (strong, nonatomic) UIImage *backgroundImage;

@end


@implementation ViewController

@synthesize clearButton, fingerState, colorButton, displayOption, backgroundButton;
@synthesize forceSlider, forceValue, diffusionSlider, diffusionValue, viscositySlider, viscosityValue;
@synthesize vorticitySlider, vorticityValue, dissipationSlider, dissipationValue, temperatureSlider, temperatureValue;
@synthesize blendMode, medium;


#pragma mark - life cycle methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	displayScale = 1.0;
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
	{
		displayScale = [[UIScreen mainScreen] scale];
	}
	
	int width = self.view.bounds.size.width;
	int height = self.view.bounds.size.height;
	
	win_x = MIN(width, height) * displayScale;
	win_y = win_x;

	_frameRate = 30.0;

	_touchesInProgress = [[NSMutableDictionary alloc] init];

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
	
	self.preferredFramesPerSecond = _frameRate;
	
	// set the default color
	source.r = 1.0f;
	source.g = 1.0f;
	source.b = 1.0f;
	source.a = 1.0f;
	self.colorButton.backgroundColor = [UIColor colorWithRed:source.r green:source.g blue:source.b alpha:source.a];

	
	// these will be the current user settings
	userForce = 1.0;
	userDiffusion = 0.0;
	userViscosity = 0.0;
	userVorticity = 0.3;
	userDissipation = 1.0;
	userTemperature = 0.0;
	userMedium = 0;		// ink
	
	// Configure the controls with the defaults...
	
	self.temperatureSlider.value = userTemperature;
	self.temperatureValue.text = [NSString stringWithFormat:@"%3.1f", userTemperature];
	
	self.forceSlider.value = userForce;
	self.forceValue.text = [NSString stringWithFormat:@"%3.1f", userForce];
	
	self.vorticitySlider.value = userVorticity;
	self.vorticityValue.text = [NSString stringWithFormat:@"%5.4f", userVorticity];
	
	self.dissipationSlider.value = userDissipation;
	self.dissipationValue.text = [NSString stringWithFormat:@"%5.4f", userDissipation];
	
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		self.diffusionSlider.value = userDiffusion * 10000;
		self.diffusionValue.text = [NSString stringWithFormat:@"%7.6f", userDiffusion];
		
		self.viscositySlider.value = userViscosity * 10000;
		self.viscosityValue.text = [NSString stringWithFormat:@"%5.4f", userViscosity];
		
	}
	
	[self chooseFingerState:0];
	

	// default to Blend
	[self.blendMode setSelectedSegmentIndex:userBlendMode];
	
	[self.medium setSelectedSegmentIndex:userMedium];
	
    [EAGLContext setCurrentContext:self.context];
    
	[self setupGL];
	
	// for the image picker...
	
	NSString *path = [self itemArchivePath];
	self.backgroundImage = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	
	if (self.backgroundImage) {
		[self createTextureFromImage:self.backgroundImage];
	}
	
	[self.view canBecomeFirstResponder];
	
}

- (NSUInteger)supportedInterfaceOrientations
{
	return (UIInterfaceOrientationMaskLandscape);
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}


- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (NSString *) itemArchivePath
{
	NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES);
	
	// Get one and only document directory from that list
	NSString *documentDirectory = [documentDirectories objectAtIndex: 0];
	
	return [documentDirectory stringByAppendingPathComponent:@"image.archive"];
}


- (BOOL) saveChanges
{
	// returns success or failure
	
	NSString *path = [self itemArchivePath];
	
	return [NSKeyedArchiver archiveRootObject:self.backgroundImage toFile:path];
}


#pragma mark -

static GLfloat sim_uvCoords[8];

- (void)setupGL
{
	GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, 1, 0, 1, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"present" ofType:@"plist"]];
	_presentShader = [[Shader alloc] initWithShaderSettings:dict];

	
	_theFluidObject = [[Fluid2DObject alloc] initWithDim:theN];
	if (_theFluidObject == nil) {
		NSLog(@"Could not create Fluid Object!");
		exit(1);
	}

	_theFluidObject.gravity = GLKVector2Make(0.0, 1.0);	// normalized velocity vector

	_theFluidObject.delegate = self;
	
	float _pixelWidth = 1.0 / (float)theN;

	float _sMin = _pixelWidth;
	float _sMax = 1.0 - _pixelWidth;
	float _tMin = _pixelWidth;
	float _tMax = 1.0 - _pixelWidth;

	sim_uvCoords[0] = _sMin;
	sim_uvCoords[1] = _tMin;
	sim_uvCoords[2] = _sMax;
	sim_uvCoords[3] = _tMin;
	sim_uvCoords[4] = _sMin;
	sim_uvCoords[5] = _tMax;
	sim_uvCoords[6] = _sMax;
	sim_uvCoords[7] = _tMax;

} // setupGL


- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
}

#pragma mark - User interaction methods

- (void) getExternalInput
{
	if ( !mouse_down[0] && !mouse_down[1] && !mouse_down[2] ) return;
	
	for (NSValue *key in _touchesInProgress) {
		
		Finger *finger = [_touchesInProgress objectForKey: key];
		
		int i = (int)(((finger.point.x)/(float)win_x) * theN);
		int j = (int)(((finger.point.y)/(float)win_y) * theN);
		
		if ( i<1 || i>theN || j<1 || j>theN ) {
			continue;
		}
		
		// calculate the position of the fluid in the simulation
		float xPos = ((finger.point.x)/(float)win_x);
		float yPos = ((finger.point.y)/(float)win_y);

		if (mouse_down[2]) {
			
			float radius = 0.0005;

			switch (userMedium) {
				case 0:
					// ink
					[_theFluidObject injectColorR:source.r g:source.g b:source.b atX:xPos y:yPos withRadius:radius];
					break;

				case 1:
					// smoke
					if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
						radius *= 2.0;
					} else {
						radius *= 6.0;
					}
					[_theFluidObject injectSmokeR:source.r g:source.g b:source.b atX:xPos y:yPos withTemperature:userTemperature andRadius:radius];
					break;
		
				case 2:
					// fire
					if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
						radius *= 2.0;
					} else {
						radius *= 6.0;
					}
					[_theFluidObject injectSmokeR:1.0 g:1.0 b:1.0 atX:xPos y:yPos withTemperature:userTemperature andRadius:radius];
					break;
					
				default:
					break;
			}
			
		}
		
		if (mouse_down[0]) {
			
			float dx = (finger.point.x - finger.oldPoint.x) * Dt * userForce * 0.5;
			float dy = (finger.point.y - finger.oldPoint.y) * Dt * userForce * 0.5;
			float radius = 0.0005;
			
//			if (userMedium == 1) {
//				// smoke
//				float rx = RANDOM_FLOAT_BETWEEN(-1.0, 1.0) * _theFluidObject.turbulence;
//				float ry = RANDOM_FLOAT_BETWEEN(-1.0, 1.0) * _theFluidObject.turbulence;
//				
//				dx += rx;
//				dy += ry;
//			}
			
			[_theFluidObject injectVelocityDX:dx
										   dy:dy
										  atX:xPos y:yPos
								   withRadius:radius];
			
		}
		
		if (mouse_down[1]) {
//			float scale = 0.1;
//			float vx = (finger.point.x - finger.oldPoint.x) * Dt * scale;
//			float vy = (finger.point.y - finger.oldPoint.y) * Dt * scale;
//			[self generateObstacleX:finger.point.x y:finger.point.y velocityX:vx vy:vy radius:_fSplatRadius];
			
		}
		
		finger.oldPoint = finger.point;
		
	} // for each touch

} // getExternalInput


- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
	
	CGPoint p0;
	
	// only want to count touches in our glView
	NSSet *myTouches = [event touchesForView:self.view];
	
	for (UITouch *touch in myTouches) {
		
		NSValue *key = [NSValue valueWithNonretainedObject: touch];
		
		Finger *finger = [_touchesInProgress objectForKey: key];
		
		if (finger) {
			// we already have this one
			continue;
		}
		
		p0 = [touch locationInView:self.view];
		p0.x *= displayScale;
		p0.y = (self.view.bounds.size.height - p0.y) * displayScale;
		
		finger = [[Finger alloc] init];
		
		finger.oldPoint = finger.point = p0;
		finger.theTouch = touch;
		
		if (mouse_down[1]) {
			finger.isObstacle = YES;
		} else {
			finger.isObstacle = NO;
		}
		
		//		printf("touch began: touch = 0x%lx, key = 0x%lx, phase = %d\n", (unsigned long)touch, (unsigned long)[key nonretainedObjectValue], touch.phase);
		
		[_touchesInProgress setObject:finger forKey:key];
		
	}
	
	
//	NSInteger selection = self.fingerState.selectedSegmentIndex;
//	
//	mouse_down[1] = 0;	// no bang
//	
//	if (selection == 0) {
//		// ink button
//		mouse_down[0] = 1;	// force
//		mouse_down[1] = 0;	// no bang
//		mouse_down[2] = 1;	// ink
//	} else if (selection == 1) {
//		// force button
//		mouse_down[0] = 1;	// force
//		mouse_down[1] = 0;	// no bang
//		mouse_down[2] = 0;	// no ink
//	} else if (selection == 2) {
//		// bang button
//		mouse_down[0] = 0;	// no force
//		mouse_down[1] = 1;	// bang
//		mouse_down[2] = 0;	// no ink
//	}
	
}


- (void) endTouches:(NSSet *) touches
{
	for (UITouch *touch in touches) {
		
		
		NSValue *key = [NSValue valueWithNonretainedObject: touch];
		
		
		Finger *finger = [_touchesInProgress objectForKey: key];
		
		if (finger) {
			
			if (finger.isObstacle) {
//				[self generateObstacleX:finger.point.x y:finger.point.y velocityX:0 vy:0 radius:_fSplatRadius];
				finger.isObstacle = NO;
			}
			[_touchesInProgress removeObjectForKey: key];
			
			
			//			printf("touch ended: touch = 0x%lx, key = 0x%lx, phase = %d\n", (unsigned long)touch, (unsigned long)[key nonretainedObjectValue], touch.phase);
		}
		
		
	}
	
} // endTouches


- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
	
	[self endTouches:touches];
	
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	
	// only want to count touches in our glView
	NSSet *myTouches = [event touchesForView:self.view];
	
	for (UITouch *touch in myTouches) {
		
		// find the matching finger
		
		NSValue *key = [NSValue valueWithNonretainedObject: touch];
		
		Finger *finger = [_touchesInProgress objectForKey: key];
		
		if (finger) {
			
			CGPoint p0 = [touch locationInView:self.view];
			p0.x *= displayScale;
			p0.y = (self.view.bounds.size.height - p0.y) * displayScale;
			
			finger.point = p0;
		}
	}
	
} // touchesMoved


- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self endTouches: touches];
}


- (void) startSimulation
{
	simulating = true;
}

- (void)stopSimulation
{
	simulating = false;
}


#pragma mark - button interface methods

- (IBAction) displayOptionChanged:(id) sender
{
	
	UISegmentedControl *_segmentedControl = (UISegmentedControl *)sender;
	NSInteger selection = _segmentedControl.selectedSegmentIndex;
	
	_theFluidObject.displayChoice = (F2D_DISPLAY_CHOICE)selection;
	
} // displayOptionChanged


- (IBAction) mediumChanged:(id) sender
{
	
	UISegmentedControl *_segmentedControl = (UISegmentedControl *)sender;
	NSInteger selection = _segmentedControl.selectedSegmentIndex;
	
	userMedium = selection;
	
	switch (userMedium) {
		case 0:
			// ink
			_theFluidObject.isFire = NO;
			_theFluidObject.advectTemperature = NO;
			[self setDissipation:1.0];
			[self setVorticity:0.0];
			self.temperatureSlider.enabled = NO;
			break;
		case 1:
			// smoke
			_theFluidObject.isFire = NO;
			_theFluidObject.advectTemperature = YES;
			_theFluidObject.kT = 0.1;			// constant for advecting temperature
			_theFluidObject.kFa = 0.01;		// constant for calulating the force of bouyancy due to density
			_theFluidObject.kFb = 0.005;		// constant for calulating the force of bouyancy due to temperature
			[self setDissipation:0.97];
			[self setVorticity:0.3];
			self.temperatureSlider.enabled = YES;
			[self setTemperature:1.0];
			_theFluidObject.turbulence = 0.2;
			break;
		case 2:
			// fire:
			_theFluidObject.isFire = YES;
			_theFluidObject.advectTemperature = YES;
			_theFluidObject.kT = 0.1;			// constant for advecting temperature
			_theFluidObject.kFa = 0.0;			// constant for calulating the force of bouyancy due to density
			_theFluidObject.kFb = 0.005;		// constant for calulating the force of bouyancy due to temperature
			[self setDissipation:0.97];
			[self setVorticity:0.5];
			self.temperatureSlider.enabled = YES;
			[self setTemperature:5.0];
			break;
	}
	
} // mediumChanged


- (IBAction) blendModeChanged:(id) sender
{
	UISegmentedControl *_segmentedControl = (UISegmentedControl *)sender;
	
	userBlendMode = _segmentedControl.selectedSegmentIndex;
	
	_theFluidObject.blendFactor = userBlendMode;
	
} // blendModeChanged


- (IBAction) fingerStateChanged:(id) sender
{
	UISegmentedControl *_segmentedControl = (UISegmentedControl *)sender;
	NSInteger selection = _segmentedControl.selectedSegmentIndex;
	
	[self chooseFingerState:selection];
	
}


- (void) chooseFingerState:(NSInteger)val
{
	
	self.fingerState.selectedSegmentIndex = val;
	
	if (val == 0) {
		// ink button
		mouse_down[0] = 1;	// force
		mouse_down[1] = 0;	// no bang
		mouse_down[2] = 1;	// ink
	} else if (val == 1) {
		// force button
		mouse_down[0] = 1;	// force
		mouse_down[1] = 0;	// no bang
		mouse_down[2] = 0;	// no ink
	} else if (val == 2) {
		// bang button
		mouse_down[0] = 0;	// no force
		mouse_down[1] = 1;	// bang
		mouse_down[2] = 0;	// no ink
	}
}


- (IBAction)temperatureSliderChanged:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	userTemperature = slider.value;
	
	self.temperatureValue.text = [NSString stringWithFormat:@"%3.1f", userTemperature];
	
}

- (void) setTemperature:(float)val
{
	userTemperature = val;
	self.temperatureSlider.value = userTemperature;
	self.temperatureValue.text = [NSString stringWithFormat:@"%3.1f", userTemperature];
}

- (IBAction)forceSliderChanged:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	userForce = slider.value;
	
	self.forceValue.text = [NSString stringWithFormat:@"%3.1f", userForce];
	
}

- (IBAction)forceValueChanged:(id)sender
{
	UITextField *theText = (UITextField *)sender;
	userForce = [theText.text floatValue];
	
	self.forceSlider.value = userForce;
}


- (IBAction)diffusionSliderChanged:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	userDiffusion = slider.value / 10000.0;
	
	self.diffusionValue.text = [NSString stringWithFormat:@"%7.6f", userDiffusion];
	
	_theFluidObject.diffusion = userDiffusion;
	
}

- (IBAction)viscositySliderChanged:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	userViscosity = slider.value / 10000.0;
	
	NSString *newText = [[NSString alloc] initWithFormat:@"%5.4f", userViscosity];
	self.viscosityValue.text = newText;
	
	_theFluidObject.viscosity = userViscosity;
	
}

- (IBAction)vorticitySliderChanged:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	userVorticity = slider.value;
	
	NSString *newText = [[NSString alloc] initWithFormat:@"%5.4f", userVorticity];
	self.vorticityValue.text = newText;
	
	_theFluidObject.vorticity = userVorticity;
	
}

- (void) setVorticity:(float)val
{
	userVorticity = val;
	self.vorticitySlider.value = userVorticity;
	self.vorticityValue.text = [NSString stringWithFormat:@"%5.4f", userVorticity];

	_theFluidObject.vorticity = userVorticity;
}

- (IBAction)dissipationSliderChanged:(id)sender
{
	UISlider *slider = (UISlider *)sender;
	userDissipation = slider.value;
	
	self.dissipationValue.text = [NSString stringWithFormat:@"%5.4f", userDissipation];
	
	_theFluidObject.dissipation = userDissipation;
	
}

- (void) setDissipation:(float)val
{
	userDissipation = val;
	self.dissipationSlider.value = userDissipation;
	self.dissipationValue.text = [NSString stringWithFormat:@"%5.4f", userDissipation];

	_theFluidObject.dissipation = userDissipation;
}


#pragma mark - color picker methods

- (IBAction) colorButtonPressed:(id) sender
{
	[self stopSimulation];
	
	UIColor *theColor = [UIColor colorWithRed:source.r green:source.g blue:source.b alpha:source.a];
	
	colorPicker = [[ColorPickerController alloc] initWithColor:theColor andTitle:@"Color Picker"];
	colorPicker.delegate = self;
	
	navigationController = [[UINavigationController alloc] initWithRootViewController:colorPicker];
	
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		
		self.aPopover = [[UIPopoverController alloc] initWithContentViewController:navigationController];
		self.aPopover.delegate = self;
		[self.aPopover setPopoverContentSize:CGSizeMake(320, 480)];
		
		CGRect _bounds = self.colorButton.frame;
		[self.aPopover presentPopoverFromRect:_bounds inView:self.view
					 permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		
	} else {
		colorPicker.modalPresentationStyle = UIModalPresentationFormSheet;
		
		[self presentViewController: navigationController animated: YES completion:nil];
	}
	
}


- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController;
{
	
	[self dismissColorController];
}


- (void) dismissColorController
{
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		[self.aPopover dismissPopoverAnimated:YES];
		self.aPopover = nil;
	} else {
		[navigationController dismissViewControllerAnimated:YES completion:nil];
	}
	
	[self startSimulation];
}

- (void)colorPickerSaved:(ColorPickerController *)controller
{
    UIColor *newColor = controller.selectedColor;
	
    // do something with newColor
	[newColor getRed:&source.r green:&source.g blue:&source.b alpha:&source.a];
	
	// select the ink
	[self chooseFingerState:0];
	
	// set the background color of the button with the color
	self.colorButton.backgroundColor = controller.selectedColor;
	
	// dismiss the view controller
	[self dismissColorController];
	
}


- (void)colorPickerCancelled:(ColorPickerController *)controller;
{
	// dismiss the view controller
	[self dismissColorController];
	
}


#pragma mark - "other" button methods

- (void) backgroundButtonPressed:(id)sender
{
	[self stopSimulation];
	
	UIImagePickerController *imagePicker = [[ UIImagePickerController alloc] init];
	
	[imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
	[imagePicker setDelegate:self];
	
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		
		self.imagePopover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
		self.imagePopover.delegate = self;
		
		CGRect _bounds = self.clearButton.frame;
		[self.imagePopover presentPopoverFromRect:_bounds inView:self.view
						 permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {
		
		[self presentViewController:imagePicker animated:YES completion:nil];
		
 	}
	
} // backgroundButtonPressed


- (void) createTextureFromImage:(UIImage *) theImage;
{
	
	CGSize origImageSize = [self.backgroundImage size];
	
	// The rectangle of the simulation view
	CGRect newRect = CGRectMake( 0, 0, 1024, 1024);
	
	// Figure out a scaling ratio to make sure we maintain the same aspect ratio
	float ratio = MAX( newRect.size.width / origImageSize.width, newRect.size.height / origImageSize.height);
	
	// Create a transparent bitmap context with a scaling factor
	// equal to that of the screen
	UIGraphicsBeginImageContextWithOptions( newRect.size, NO, 0.0);
	
	// Center the image in the rectangle
	CGRect projectRect;
	projectRect.size.width = ratio * origImageSize.width;
	projectRect.size.height = ratio * origImageSize.height;
	projectRect.origin.x = (newRect.size.width - projectRect.size.width) / 2.0;
	projectRect.origin.y = (newRect.size.height - projectRect.size.height) / 2.0;
	
	// Draw the image on it
	[self.backgroundImage drawInRect:projectRect];
	
	UIImage *fixedImage = UIGraphicsGetImageFromCurrentImageContext();
	
	
	// create a texture from the image, flipping y...
	
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                        forKey:GLKTextureLoaderOriginBottomLeft];
	
	if (self.backgroundTexInfo) {
		self.backgroundTexInfo = nil;
	}
	
	self.backgroundTexInfo = [GLKTextureLoader textureWithCGImage:[fixedImage CGImage] options:options error:nil];
	
} // createTextureFromImage


- (void) imagePickerController:( UIImagePickerController *) picker
 didFinishPickingMediaWithInfo:( NSDictionary *) info
{
	// Get picked image from info dictionary
	self.backgroundImage = [info objectForKey:UIImagePickerControllerOriginalImage];
	
	[self createTextureFromImage:self.backgroundImage];
	
	// Take image picker off the screen
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		[self.imagePopover dismissPopoverAnimated:YES];
		self.imagePopover = nil;
	} else {
		[self dismissViewControllerAnimated:YES completion:nil];
	}
	
	[self startSimulation];
}


// this needed for UIMenuController:
- (BOOL) canBecomeFirstResponder
{
	return YES;
}


- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	BOOL retValue = NO;
	
	if ( action == @selector(reset) ) {
		retValue = YES;
	} else if ( action == @selector(clearBackgroundImage) ) {
		retValue = YES;
	} else if ( action == @selector(setBackgroundImage:) ) {
		retValue = YES;
	} else {
		retValue = [super canPerformAction:action withSender:sender];
	}
	
	return retValue;
}


- (void) clearBackgroundImage
{
	self.backgroundTexInfo = nil;
	self.backgroundImage = nil;
}


- (IBAction) clearButtonPressed:(id) sender
{
	
	// Grab the menu controller
	UIMenuController *menu = [UIMenuController sharedMenuController];
	
	// Create a new "Reset Simulation" UIMenuItem
	UIMenuItem *clearSimItem = [[UIMenuItem alloc] initWithTitle:@"Reset Sim" action:@selector(reset)];
	
	// Create a new "Clear Background" UIMenuItem
	UIMenuItem *clearBackgroundItem = [[UIMenuItem alloc] initWithTitle:@"Clear Background" action:@selector(clearBackgroundImage)];
	
	// Create a new "Set Background" UIMenuItem
	UIMenuItem *setBackgroundItem = [[UIMenuItem alloc] initWithTitle:@"Set Background" action:@selector(backgroundButtonPressed:)];
	
	[menu setMenuItems:[NSArray arrayWithObjects:clearSimItem, setBackgroundItem, clearBackgroundItem, nil]];
	
	// Tell the menu where it should come from and show it
	CGRect _bounds = self.clearButton.frame;
	
	// Needed to add this for iOS 7 for some reason.
	// Otherwise the second time I try to make the menu visible after choosing something with ImagePicker,
	// The menu is not displayed, and canPerformAction is never called.
	[self becomeFirstResponder];
	
	[menu setTargetRect:_bounds inView:self.view];
	[menu setMenuVisible:YES animated:YES];
	
}


- (void) reset
{
	[_theFluidObject reset];
}


#pragma mark - GLKView and GLKViewController delegate methods

static float Dt;

- (void)update
{
	if (!simulating) {
		return;
	}
    
	Dt = self.timeSinceLastUpdate;
	
	float interp = Dt * self.preferredFramesPerSecond;

	float maxFramesMissed = 5.0;
	
	if (Dt < 0.f || interp > maxFramesMissed) {
		Dt = 1.0 / self.preferredFramesPerSecond;
//		interp = Dt * self.preferredFramesPerSecond;
	}
	
	[_theFluidObject updateWithDt:Dt];
}

const GLfloat square_vertices[] = {
	0.000, 0.000, 0.000,
	1.0, 0.000, 0.000,
	0.000, 1.0, 0.000,
	1.0, 1.0, 0.000,
};

//const GLfloat square_uvCoords[] = {
//    0.0, 0.0,
//    1.0, 0.0,
//    0.0, 1.0,
//    1.0, 1.0,
//};

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	// rebind the view’s framebuffer object to OpenGL ES
	GLKView *theView = (GLKView *)self.view;
	[theView bindDrawable];
	
//    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
	glClearColor(38.0/255.0, 39.0/255.0, 43.0/255.0, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
	[_presentShader useShader];
	
    glUniformMatrix4fv([_presentShader uniformLocation:@"modelViewProjectionMatrix"], 1, 0, _modelViewProjectionMatrix.m);
	
	GLuint vertexAttrib = [_presentShader attributeHandle:@"position"];
	glEnableVertexAttribArray(vertexAttrib);
	glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, 0, 0, &square_vertices[0]);
	
	GLuint textureAttrib = [_presentShader attributeHandle:@"inTexCoord"];
	glEnableVertexAttribArray(textureAttrib);
//	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &square_uvCoords[0]);
	glVertexAttribPointer(textureAttrib, 2, GL_FLOAT, 0, 0, &sim_uvCoords[0]);		// no border
	
	// bind the display texture to unit 0
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, _theFluidObject.displayTexture);
	glUniform1i([_presentShader uniformLocation:@"texture"], 0);
	
	// bind the background texture to unit 1
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, self.backgroundTexInfo.name);
	glUniform1i([_presentShader uniformLocation:@"background"], 1);
	
	// draw the quad.
	// Since the display texture is specified to have linear sampling,
	// the output image will be filtered.
	glViewport(0, 0, win_x, win_y);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	GetGLError();
	
}


@end
