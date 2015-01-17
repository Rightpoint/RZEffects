//
//  RZViewTexture.m
//
//  Created by Rob Visentin on 1/9/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/glext.h>

#import "RZViewTexture.h"

@interface RZViewTexture () {
    GLsizei _texWidth;
    GLsizei _texHeight;
    
    CVPixelBufferRef _pixBuffer;
    CVOpenGLESTextureCacheRef _texCache;
    CVOpenGLESTextureRef _tex;
    
    CGContextRef _context;
    
    dispatch_queue_t _renderQueue;
    dispatch_semaphore_t _renderSemaphore;
}

@end

@implementation RZViewTexture

+ (instancetype)textureWithSize:(CGSize)size
{
    return [self textureWithSize:size scale:[UIScreen mainScreen].scale];
}

+ (instancetype)textureWithSize:(CGSize)size scale:(CGFloat)scale
{
    return [[[self class] alloc] initWithSize:size scale:scale];
}

- (void)dealloc
{
    [self teardownGL];
}

- (void)updateWithView:(UIView *)view synchronous:(BOOL)synchronous
{
    if ( synchronous ) {
        [self rz_renderView:view];
    }
    else if ( dispatch_semaphore_wait(_renderSemaphore, DISPATCH_TIME_NOW) == 0 ) {
        dispatch_async(_renderQueue, ^{
            [self rz_renderView:view];
            
            dispatch_semaphore_signal(_renderSemaphore);
        });
    }
}

#pragma mark - RZOpenGLObject

- (void)setupGL
{
    if ( [EAGLContext currentContext] != nil ) {
        [self teardownGL];
        
        NSDictionary *buffersAttrs = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]};
        
        CVPixelBufferCreate(NULL, _texWidth, _texHeight, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)(buffersAttrs), &_pixBuffer);
        
        CVPixelBufferLockBaseAddress(_pixBuffer, 0);
        
        CVOpenGLESTextureCacheCreate(NULL, NULL, [EAGLContext currentContext], NULL, &_texCache);
        CVOpenGLESTextureCacheCreateTextureFromImage(NULL, _texCache, _pixBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, _texWidth, _texHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &_tex);
        
        glBindTexture(CVOpenGLESTextureGetTarget(_tex), CVOpenGLESTextureGetName(_tex));
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glBindTexture(GL_TEXTURE_2D, 0);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        _context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(_pixBuffer), _texWidth, _texHeight, 8, CVPixelBufferGetBytesPerRow(_pixBuffer), colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
        CGColorSpaceRelease(colorSpace);
        
        CGContextScaleCTM(_context, _scale, _scale);
        
        CVPixelBufferUnlockBaseAddress(_pixBuffer, 0);
    }
    else {
        NSLog(@"Failed to setup %@: No active EAGLContext.", NSStringFromClass([self class]));
    }
}

- (void)bindGL
{
    glBindTexture(CVOpenGLESTextureGetTarget(_tex), CVOpenGLESTextureGetName(_tex));
}

- (void)teardownGL
{
    CGContextRelease(_context);
    CVPixelBufferRelease(_pixBuffer);
    
    if ( _tex != nil ) {
        GLuint name = CVOpenGLESTextureGetName(_tex);
        glDeleteTextures(1, &name);
        CFRelease(_tex);
    }
    
    if ( _texCache != nil ) {
        CFRelease(_texCache);
    }
}

#pragma mark - private methods

- (instancetype)initWithSize:(CGSize)size scale:(CGFloat)scale
{
    self = [super init];
    if ( self ) {
        _size = size;
        _scale = scale;
        
        _texWidth = size.width * scale;
        _texHeight = size.height * scale;
        
        _renderQueue = dispatch_queue_create("com.raizlabs.view-texture-render", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_renderQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        
        _renderSemaphore = dispatch_semaphore_create(2);
    }
    return self;
}

- (void)rz_renderView:(UIView *)view
{
    @autoreleasepool {
        CVPixelBufferLockBaseAddress(_pixBuffer, 0);
        
        UIGraphicsPushContext(_context);
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
        UIGraphicsPopContext();
        
        CVPixelBufferUnlockBaseAddress(_pixBuffer, 0);
    }
}

@end
