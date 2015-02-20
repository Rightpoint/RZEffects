//
//  RZEffectContext.h
//
//  Created by Rob Visentin on 2/18/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGLDrawable.h>

@interface RZEffectContext : NSObject

@property (nonatomic, readonly) BOOL isCurrentContext;

+ (instancetype)defaultContext;

- (instancetype)initWithSharedContext:(RZEffectContext *)shareContext NS_DESIGNATED_INITIALIZER;

- (BOOL)renderbufferStorage:(NSUInteger)target fromDrawable:(id<EAGLDrawable>)drawable;
- (BOOL)presentRenderbuffer:(NSUInteger)target;

- (void)runBlock:(void(^)(RZEffectContext *context))block;
- (void)runBlock:(void(^)(RZEffectContext *context))block wait:(BOOL)wait;

@end
