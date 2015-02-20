//
//  RZEffectContext.m
//
//  Created by Rob Visentin on 2/18/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>

#import "RZEffectContext.h"

@interface RZEffectContext ()

@property (strong, nonatomic, readwrite) dispatch_queue_t contextQueue;
@property (strong, nonatomic) EAGLContext *glContext;

@end

@implementation RZEffectContext

+ (instancetype)defaultContext
{
    static id s_DefaultContext = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_DefaultContext = [[self alloc] init];
    });

    return s_DefaultContext;
}

- (instancetype)init
{
    return [self initWithSharedContext:nil];
}

- (instancetype)initWithSharedContext:(RZEffectContext *)shareContext
{
    self = [super init];
    if ( self ) {
        const char *queueLabel = [NSString stringWithFormat:@"com.rzeffects.context-%lu", (unsigned long)self.hash].UTF8String;
        _contextQueue = dispatch_queue_create(queueLabel, DISPATCH_QUEUE_SERIAL);

        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareContext.glContext.sharegroup];
    }

    return self;
}

- (BOOL)isCurrentContext
{
    return ([EAGLContext currentContext] == self.glContext);
}

- (BOOL)renderbufferStorage:(NSUInteger)target fromDrawable:(id<EAGLDrawable>)drawable
{
    __block BOOL success = NO;

    if ( self.isCurrentContext ) {
        success = [self.glContext renderbufferStorage:target fromDrawable:drawable];
    }
    else {
        [self runBlock:^(RZEffectContext *context) {
            success = [context.glContext renderbufferStorage:target fromDrawable:drawable];
        }];
    }

    return success;
}

- (BOOL)presentRenderbuffer:(NSUInteger)target
{
    __block BOOL success = NO;

    if ( self.isCurrentContext ) {
        success = [self.glContext presentRenderbuffer:target];
    }
    else {
        [self runBlock:^(RZEffectContext *context) {
            success = [context.glContext presentRenderbuffer:target];
        }];
    }

    return success;
}

- (void)runBlock:(void (^)(RZEffectContext *))block
{
    [self runBlock:block wait:YES];
}

- (void)runBlock:(void (^)(RZEffectContext *context))block wait:(BOOL)wait
{
    if ( block != nil ) {
        if ( self.isCurrentContext ) {
            if ( wait ) {
                block(self);
            }
            else {
                dispatch_async(self.contextQueue, ^{
                    block(self);
                });
            }
        }
        else {
            void (^innerBlock)() = ^{
                if ( !self.isCurrentContext ) {
                    [EAGLContext setCurrentContext:self.glContext];
                }

                @autoreleasepool {
                    block(self);
                }
            };

            if ( wait ) {
                dispatch_sync(self.contextQueue, innerBlock);
            }
            else {
                dispatch_async(self.contextQueue, innerBlock);
            }
        }
    }
}

@end
