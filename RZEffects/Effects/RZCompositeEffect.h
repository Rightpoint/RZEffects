//
//  RZCompositeEffect.h
//
//  Created by Rob Visentin on 1/16/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZEffect.h"

@interface RZCompositeEffect : RZEffect

@property (strong, nonatomic, readonly) RZEffect *firstEffect;
@property (strong, nonatomic, readonly) RZEffect *secondEffect;

@property (strong, nonatomic, readonly) RZEffect *currentEffect;

+ (instancetype)compositeEffectWithFirstEffect:(RZEffect *)first secondEffect:(RZEffect *)second;

@end
