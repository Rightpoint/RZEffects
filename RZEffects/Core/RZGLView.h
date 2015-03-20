//
//  RZGLView.h
//
//  Created by Rob Visentin on 3/15/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RZUpdateable.h"
#import "RZRenderable.h"

@class RZEffectContext;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"

@interface RZGLView : UIView <RZUpdateable, RZRenderable> {
    @protected
    RZEffectContext *_context;
    
    GLuint _fbo;
    GLuint _crb;
    GLuint _drb;

    GLint _backingWidth;
    GLint _backingHeight;
}

@property (assign, nonatomic) IBInspectable NSInteger framesPerSecond;
@property (assign, nonatomic, getter=isPaused) BOOL paused;

@property (strong, nonatomic) id<RZRenderable> model;

- (void)display;

@end

#pragma clang diagnostic pop
