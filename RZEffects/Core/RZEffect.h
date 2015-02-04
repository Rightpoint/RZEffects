//
//  RZEffect.h
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <GLKit/GLKMath.h>

#import "RZEffectsCommon.h"

OBJC_EXTERN NSString* const kRZEffectDefaultVSH2D;
OBJC_EXTERN NSString* const kRZEffectDefaultVSH3D;

OBJC_EXTERN NSString* const kRZEffectDefaultFSH;

#define RZ_EFFECT_MAX_DOWNSAMPLE 4

#define RZ_SHADER_SRC(src) (@#src)

@interface RZEffect : NSObject <RZOpenGLObject, NSCopying>

@property (nonatomic, readonly, getter = isLinked) BOOL linked;

@property (assign, nonatomic) GLKMatrix4 modelViewMatrix;
@property (assign, nonatomic) GLKMatrix4 projectionMatrix;
@property (assign, nonatomic) GLKMatrix3 normalMatrix;

@property (copy, nonatomic) NSString *mvpUniform;
@property (copy, nonatomic) NSString *mvUniform;
@property (copy, nonatomic) NSString *normalMatrixUniform;

@property (assign, nonatomic) GLKVector2 resolution;
@property (assign, nonatomic) GLuint downsampleLevel;

@property (nonatomic, readonly) NSInteger preferredLevelOfDetail;

+ (instancetype)effectWithVertexShaderNamed:(NSString *)vshName fragmentShaderNamed:(NSString *)fshName;

+ (instancetype)effectWithVertexShader:(NSString *)vsh fragmentShader:(NSString *)fsh;

- (BOOL)link;

- (BOOL)prepareToDraw;

- (void)bindAttribute:(NSString *)attribute location:(GLuint)location;
- (GLint)uniformLoc:(NSString *)uniformName;

@end
