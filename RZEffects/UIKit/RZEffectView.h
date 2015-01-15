//
//  RZEffectView.h
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RZEffect.h"
#import "RZCamera.h"

@interface RZEffectView : UIView

@property (assign, nonatomic) IBInspectable NSInteger framesPerSecond;
@property (assign, nonatomic, getter=isPaused) BOOL paused;

@property (strong, nonatomic) RZEffect *effect;
@property (strong, nonatomic) id<RZRenderable> model;

@property (strong, nonatomic) RZCamera *effectCamera;
@property (strong, nonatomic) RZTransform3D *effectTransform;

@property (assign, nonatomic, getter=isDynamic) IBInspectable BOOL dynamic;

- (instancetype)initWithSourceView:(UIView *)view effect:(RZEffect *)effect dynamicContent:(BOOL)dynamic;

- (void)display;

@end

@interface RZEffectView (RZUnavailable)

- (instancetype)initWithFrame:(CGRect)frame __attribute__((unavailable("Use -initWithSourceView: instead.")));

@end
