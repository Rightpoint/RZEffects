//
//  RZEffectContext.h
//
//  Created by Rob Visentin on 2/18/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/EAGLDrawable.h>
#import <CoreGraphics/CGColor.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>

#import "RZEffectsCommon.h"

@interface RZEffectContext : NSObject

@property (nonatomic, readonly) BOOL isCurrentContext;

@property (assign, nonatomic) CGRect viewport;
@property (assign, nonatomic) CGColorRef clearColor; // default nil (opaque black)

@property (assign, nonatomic, getter=isDepthTestEnabled) BOOL depthTestEnabled; // default NO
@property (assign, nonatomic, getter=isStencilTestEnabled) BOOL stencilTestEnabled; // default NO

@property (assign, nonatomic) GLenum cullFace; // default GL_BACK

@property (assign, nonatomic) GLenum activeTexture; // default GL_TEXTURE0

+ (instancetype)defaultContext;

+ (RZEffectContext *)currentContext;

- (instancetype)initWithSharedContext:(RZEffectContext *)shareContext NS_DESIGNATED_INITIALIZER;

- (BOOL)renderbufferStorage:(NSUInteger)target fromDrawable:(id<EAGLDrawable>)drawable;
- (BOOL)presentRenderbuffer:(NSUInteger)target;

- (void)bindVertexArray:(GLuint)vao;
- (void)useProgram:(GLuint)program;

- (GLuint)vertexShaderWithSource:(NSString *)vshSrc;
- (GLuint)fragmentShaderWithSource:(NSString *)fshSrc;

- (CVOpenGLESTextureRef)textureWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)runBlock:(void(^)(RZEffectContext *context))block;
- (void)runBlock:(void(^)(RZEffectContext *context))block wait:(BOOL)wait;

@end
