//
//  Finger.h
//
//  Created by Jack Wright on 1/25/13.
//  Copyright (c) 2013 Jack Wright. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Finger : NSObject

@property (nonatomic) CGPoint point;
@property (nonatomic) CGPoint oldPoint;
@property (nonatomic) UITouch *theTouch;
@property bool isObstacle;

@end
