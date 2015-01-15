//
//  RZRenderLoop.m
//
//  Created by Rob Visentin on 1/10/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RZRenderLoop.h"

@interface RZRenderLoop ()

@property (strong, nonatomic) CADisplayLink *displayLink;
@property (assign, nonatomic) BOOL pausedWhileInactive;

@property (strong, nonatomic) NSInvocation *updateInvocation;
@property (strong, nonatomic) NSInvocation *renderInvocation;

@property (assign, nonatomic, readwrite) CFTimeInterval lastRender;
@property (assign, nonatomic, readwrite, getter=isRunning, setter=_setRunning:) BOOL running;

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
        _automaticallyResumeWhenBecomingActive = YES;
        
        [self _setupDisplayLink];
    }
    return self;
}

- (void)dealloc
{
    [self _teardownDisplayLink];
}

- (void)setPreferredFPS:(NSInteger)preferredFPS
{
    preferredFPS = MAX(1, MIN(preferredFPS, 60));
    self.displayLink.frameInterval = 60 / preferredFPS;
}

- (void)setUpdateTarget:(id)target action:(SEL)updateAction
{
    @synchronized (self) {
        NSMethodSignature *methodSig = [target methodSignatureForSelector:updateAction];
        
        if ( methodSig != nil ) {
            NSAssert(methodSig.numberOfArguments == 3, @"%@ update action must have exactly one parameter, a CFTimeInterval.", NSStringFromClass([self class]));
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
            invocation.target = target;
            invocation.selector = updateAction;
            
            self.updateInvocation = invocation;
        }
        else {
            self.updateInvocation = nil;
        }
    }
}

- (void)setRenderTarget:(id)target action:(SEL)renderAction
{
    @synchronized (self) {
        NSMethodSignature *methodSig = [target methodSignatureForSelector:renderAction];
        
        if ( methodSig != nil ) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
            invocation.target = target;
            invocation.selector = renderAction;
            
            self.renderInvocation = invocation;
        }
        else {
            self.renderInvocation = nil;
        }
    }
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

- (void)_setupDisplayLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_render:)];
    self.displayLink.paused = YES;
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)_teardownDisplayLink
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)_setRunning:(BOOL)running
{
    _running = running;
    self.displayLink.paused = !running;
}

- (void)_willResignActive:(NSNotification *)notification
{
    if ( self.isRunning ) {
        [self stop];
        self.pausedWhileInactive = YES;
    }
}

- (void)_didBecomeActive:(NSNotification *)notification
{
    if ( self.pausedWhileInactive && self.automaticallyResumeWhenBecomingActive ) {
        [self run];
    }
}

- (void)_render:(CADisplayLink *)displayLink
{
    CFTimeInterval dt = displayLink.timestamp - self.lastRender;
    
    @synchronized (self.updateInvocation) {
        if ( self.updateInvocation.target != nil ) {
            [self.updateInvocation setArgument:&dt atIndex:2];
            [self.updateInvocation invoke];
        }
    }
    
    @synchronized (self.renderInvocation) {
        if ( self.renderInvocation.target != nil ) {
            [self.renderInvocation invoke];
        }
    }
    
    self.lastRender = displayLink.timestamp;
}

@end
