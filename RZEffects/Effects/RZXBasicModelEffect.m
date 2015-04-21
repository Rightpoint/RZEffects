//
//  RZXBasicModelEffect.m
//  RZXSceneDemo
//
//  Created by John Stricker on 4/17/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZXBasicModelEffect.h"

NSString* const kRZXBasicModelEffectVertexShader = RZ_SHADER_SRC(
attribute vec4 a_position;
attribute vec3 a_normal;
attribute vec2 a_texCoord;
varying lowp vec4 v_colorVarying;
varying vec2 v_texCoord;
uniform mat4 u_modelViewProjectionMatrix;
uniform mat3 u_normalMatrix;
uniform vec4 u_diffuseColor;
uniform float u_shadowMax;

void main()
{
    vec3 eyeNormal = normalize(u_normalMatrix * a_normal);
    vec3 lightPosition = vec3(0.0, 1.0, 3.0);
    vec3 colorMin = u_diffuseColor.xyz - u_shadowMax;
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
    
    v_colorVarying = u_diffuseColor * nDotVP;
    v_colorVarying.a = 1.0;
    v_colorVarying.xyz = max(colorMin.xyz,v_colorVarying.xyz);
    
    gl_Position = u_modelViewProjectionMatrix * a_position;
    v_texCoord = a_texCoord;
});

NSString* const kRZXBasicModelEffectFragmentShader = RZ_SHADER_SRC(
precision mediump float;
varying highp vec4 v_colorVarying;
varying vec2 v_texCoord;
uniform sampler2D u_colorMap;
uniform float u_alpha;

void main()
{
    gl_FragColor = texture2D(u_colorMap,v_texCoord) * v_colorVarying;
    gl_FragColor.rgba *=u_alpha;
});

@implementation RZXBasicModelEffect

+ (instancetype)effect
{
    RZXBasicModelEffect *effect = [self effectWithVertexShader:kRZXBasicModelEffectVertexShader fragmentShader:kRZXBasicModelEffectFragmentShader];
    
}

@end
