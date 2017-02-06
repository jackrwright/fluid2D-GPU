//
//  ViewController.h
//  fluid2D-GPU
//
//  Created by Jack Wright on 3/20/13.
//  Copyright (c) 2013 Jack Wright. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "ColorPickerController.h"
#import "Fluid2DObject.h"

@interface ViewController : GLKViewController<fluidObjectDelegate, ColorPickerDelegate, UIAccelerometerDelegate, UIPopoverControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
	
	IBOutlet	UISegmentedControl	*fingerState;
	IBOutlet	UIButton *clearButton;
	
	IBOutlet	UISlider *forceSlider;
	IBOutlet	UITextField *forceValue;
	
	IBOutlet	UISlider *diffusionSlider;
	IBOutlet	UITextField *diffusionValue;
	
	IBOutlet	UISlider *viscositySlider;
	IBOutlet	UITextField *viscosityValue;
	
	IBOutlet	UISlider *vorticitySlider;
	IBOutlet	UITextField *vorticityValue;
	
	IBOutlet	UISlider *dissipationSlider;
	IBOutlet	UITextField *dissipationValue;
	
	IBOutlet	UISlider *temperatureSlider;
	IBOutlet	UITextField *temperatureValue;
	
	IBOutlet	UIButton *colorButton;
	IBOutlet	UIButton *backgroundButton;
	
	IBOutlet	UISegmentedControl	*displayOption;
	
	IBOutlet	UISegmentedControl	*blendMode;
	
	IBOutlet	UISegmentedControl	*medium;
	
	ColorPickerController *colorPicker;
	UINavigationController *navigationController;
	
	NSMutableDictionary *_touchesInProgress;
}

- (IBAction) fingerStateChanged:(id) sender;
- (IBAction) clearButtonPressed:(id) sender;
- (IBAction) forceSliderChanged:(id) sender;
- (IBAction) diffusionSliderChanged:(id) sender;
- (IBAction) viscositySliderChanged:(id) sender;
- (IBAction) vorticitySliderChanged:(id) sender;
- (IBAction) dissipationSliderChanged:(id) sender;
- (IBAction) temperatureSliderChanged:(id) sender;
- (IBAction) colorButtonPressed:(id) sender;
- (IBAction) displayOptionChanged:(id) sender;
- (IBAction) mediumChanged:(id) sender;
- (IBAction) blendModeChanged:(id) sender;
- (IBAction) backgroundButtonPressed:(id) sender;

@property (nonatomic, strong) UISegmentedControl *fingerState;
@property (nonatomic, strong) UIButton *clearButton;

@property (nonatomic, strong) UISlider *forceSlider;
@property (nonatomic, strong) UITextField *forceValue;

@property (nonatomic, strong) UISlider *diffusionSlider;
@property (nonatomic, strong) UITextField *diffusionValue;

@property (nonatomic, strong) UISlider *viscositySlider;
@property (nonatomic, strong) UITextField *viscosityValue;

@property (nonatomic, strong) UISlider *vorticitySlider;
@property (nonatomic, strong) UITextField *vorticityValue;

@property (nonatomic, strong) UISlider *dissipationSlider;
@property (nonatomic, strong) UITextField *dissipationValue;

@property (nonatomic, strong) UISlider *temperatureSlider;
@property (nonatomic, strong) UITextField *temperatureValue;

@property (nonatomic, strong) UIButton *colorButton;
@property (nonatomic, strong) UIButton *backgroundButton;

@property (nonatomic, strong) UISegmentedControl *displayOption;
@property (nonatomic, strong) UISegmentedControl *medium;
@property (nonatomic, strong) UISegmentedControl *blendMode;

@property (nonatomic, strong) UIPopoverController *aPopover;
@property (nonatomic, strong) UIPopoverController *imagePopover;

- (void) startSimulation;
- (void) stopSimulation;
- (BOOL) saveChanges;

@end
