//
//  RZRenderLoop.h
//
//  Created by Rob Visentin on 1/10/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "RZUpdateable.h"
#import "RZRenderable.h"

@interface RZRenderLoop : NSObject

@property (assign, nonatomic, readonly) CFTimeInterval lastRender;
@property (assign, nonatomic, readonly, getter=isRunning) BOOL running;

@property (assign, nonatomic) BOOL automaticallyResumeWhenForegrounded;

@property (assign, nonatomic) NSInteger preferredFPS;

+ (instancetype)renderLoop;

- (void)setUpdateTarget:(id<RZUpdateable>)updateTarget;
- (void)setRenderTarget:(id<RZRenderable>)renderTarget;

- (void)run;
- (void)stop;

@end
