//
//  RZRenderLoop.m
//
//  Created by Rob Visentin on 1/10/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RZRenderLoop.h"

static const NSInteger kRZRenderLoopDefaultFPS = 30;

@interface RZRenderLoop ()

@property (strong, nonatomic) CADisplayLink *displayLink;
@property (assign, nonatomic) BOOL pausedWhileInactive;

@property (weak, nonatomic) id<RZUpdateable> updateTarget;
@property (weak, nonatomic) id<RZRenderable> renderTarget;

@property (assign, nonatomic, readwrite) CFTimeInterval lastRender;
@property (assign, nonatomic, readwrite, getter=isRunning) BOOL running;

@end

@implementation RZRenderLoop

+ (instancetype)renderLoop
{
    return [[[self class] alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if ( self ) {
        _automaticallyResumeWhenForegrounded = YES;
        
        [self rz_setupDisplayLink];
    }
    return self;
}

- (void)dealloc
{
    [self rz_teardownDisplayLink];
}

- (void)setPreferredFPS:(NSInteger)preferredFPS
{
    _preferredFPS = MAX(1, MIN(preferredFPS, 60));
    self.displayLink.frameInterval = 60 / _preferredFPS;
}

- (void)run
{
    self.lastRender = CACurrentMediaTime();
    
    self.running = YES;
}

- (void)stop
{
    self.running = NO;
}
                        
#pragma mark - private methods

- (void)rz_setupDisplayLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(rz_render:)];
    self.displayLink.paused = YES;

    self.preferredFPS = kRZRenderLoopDefaultFPS;
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rz_didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rz_willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)rz_teardownDisplayLink
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)setRunning:(BOOL)running
{
    _running = running;
    self.displayLink.paused = !running;
}

- (void)rz_didEnterBackground:(NSNotification *)notification
{
    if ( self.isRunning ) {
        [self stop];
        self.pausedWhileInactive = YES;
    }
}

- (void)rz_willEnterForeground:(NSNotification *)notification
{
    if ( self.pausedWhileInactive && self.automaticallyResumeWhenForegrounded ) {
        [self run];
    }
}

- (void)rz_render:(CADisplayLink *)displayLink
{
    CFTimeInterval dt = displayLink.timestamp - self.lastRender;
    
    [self.updateTarget update:dt];

    [self.renderTarget render];
    
    self.lastRender = displayLink.timestamp;
}

@end
