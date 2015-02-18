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
        _automaticallyResumeWhenBecomingActive = YES;
        
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

- (void)rz_setupDisplayLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(rz_render:)];
    self.displayLink.paused = YES;
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rz_willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rz_didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)rz_teardownDisplayLink
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)setRunning:(BOOL)running
{
    _running = running;
    self.displayLink.paused = !running;
}

- (void)rz_willResignActive:(NSNotification *)notification
{
    if ( self.isRunning ) {
        [self stop];
        self.pausedWhileInactive = YES;
    }
}

- (void)rz_didBecomeActive:(NSNotification *)notification
{
    if ( self.pausedWhileInactive && self.automaticallyResumeWhenBecomingActive ) {
        [self run];
    }
}

- (void)rz_render:(CADisplayLink *)displayLink
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
