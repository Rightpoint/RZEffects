//
//  RZUIEffectView.h
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZGLView.h"

#import "RZEffect.h"
#import "RZCamera.h"

@interface RZUIEffectView : RZGLView

@property (strong, nonatomic) RZEffect *effect;

@property (strong, nonatomic) RZCamera *effectCamera;
@property (strong, nonatomic) RZTransform3D *effectTransform;

@property (assign, nonatomic, getter=isDynamic) IBInspectable BOOL dynamic;

@property (assign, nonatomic) BOOL synchronousUpdate; // default NO
@property (assign, nonatomic) BOOL automaticallyAdjustsCamera; // default YES

- (instancetype)initWithSourceView:(UIView *)view effect:(RZEffect *)effect dynamicContent:(BOOL)dynamic;

@end

@interface RZUIEffectView (RZUnavailable)

- (instancetype)initWithFrame:(CGRect)frame __attribute__((unavailable("Use -initWithSourceView: instead.")));

@end
