//
//  RZCompositeEffect.m
//
//  Created by Rob Visentin on 1/16/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZCompositeEffect.h"

@interface RZCompositeEffect ()

@property (strong, nonatomic, readwrite) RZEffect *firstEffect;
@property (strong, nonatomic, readwrite) RZEffect *secondEffect;

@property (strong, nonatomic, readwrite) RZEffect *currentEffect;

@end

@implementation RZCompositeEffect

+ (instancetype)compositeEffectWithFirstEffect:(RZEffect *)first secondEffect:(RZEffect *)second
{
    RZCompositeEffect *effect = [[self alloc] init];
    effect.firstEffect = first;
    effect.secondEffect = second;
    effect.currentEffect = effect.firstEffect;
    
    return effect;
}

- (void)setModelViewMatrix:(GLKMatrix4)modelViewMatrix
{
    self.firstEffect.modelViewMatrix = modelViewMatrix;
    self.secondEffect.modelViewMatrix = modelViewMatrix;
}

- (void)setProjectionMatrix:(GLKMatrix4)projectionMatrix
{
    self.firstEffect.projectionMatrix = projectionMatrix;
    self.secondEffect.projectionMatrix = projectionMatrix;
}

- (void)setNormalMatrix:(GLKMatrix3)normalMatrix
{
    self.firstEffect.normalMatrix = normalMatrix;
    self.secondEffect.normalMatrix = normalMatrix;
}

- (void)setResolution:(GLKVector2)resolution
{
    self.firstEffect.resolution = resolution;
    self.secondEffect.resolution = resolution;
}

- (GLuint)downsampleLevel
{
    return [super downsampleLevel] + self.currentEffect.downsampleLevel;
}

- (NSInteger)preferredLevelOfDetail
{
    return MAX(self.firstEffect.preferredLevelOfDetail, self.secondEffect.preferredLevelOfDetail);
}

- (BOOL)link
{
    return [self.firstEffect link] && [self.secondEffect link];
}

- (BOOL)prepareToDraw
{
    BOOL unfinished = YES;
    
    if ( self.currentEffect == self.firstEffect ) {
        if ( ![self.firstEffect prepareToDraw] ) {
            self.currentEffect = self.secondEffect;
        }
    }
    else {
        unfinished = [self.secondEffect prepareToDraw];
        
        if ( !unfinished ) {
            self.currentEffect = self.firstEffect;
        }
    }
    
    return unfinished;
}

- (void)bindAttribute:(NSString *)attribute location:(GLuint)location
{
    [self.currentEffect bindAttribute:attribute location:location];
}

- (GLint)uniformLoc:(NSString *)uniformName
{
    return [self.currentEffect uniformLoc:uniformName];
}

#pragma mark - RZOpenGLObject

- (void)setupGL
{
    [self.firstEffect setupGL];
    [self.secondEffect setupGL];
}

- (void)bindGL
{
    [self.currentEffect bindGL];
}

- (void)teardownGL
{
    [self.firstEffect teardownGL];
    [self.secondEffect teardownGL];
}

@end
