//
//  RZClothEffect.h
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZEffect.h"

@interface RZClothEffect : RZEffect

+ (instancetype)effect;

@property (assign, nonatomic) GLKVector2 anchors;

@property (assign, nonatomic) GLfloat waveCount;
@property (assign, nonatomic) GLfloat waveAmplitude;
@property (assign, nonatomic) GLfloat waveVelocity;

@property (assign, nonatomic) GLKVector3 lightOffset;
@property (assign, nonatomic) GLKVector3 ambientLight;
@property (assign, nonatomic) GLKVector3 diffuseLight;
@property (assign, nonatomic) GLKVector3 specularLight;

@end
