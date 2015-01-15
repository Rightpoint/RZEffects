//
//  RZClothEffect.m
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/gl.h>
#import <QuartzCore/QuartzCore.h>

#import "RZClothEffect.h"

static NSString* const kRZClothVSH = RZ_SHADER_SRC(
uniform mat4 u_MVPMatrix;
uniform mat4 u_MVMatrix;

uniform vec2 u_Anchors;

uniform float u_Waves;
uniform float u_Amplitude;
uniform float u_Velocity;

uniform vec3 u_LightOffset;
uniform float u_Time;

attribute vec4 a_position;
attribute vec2 a_texCoord0;

varying vec4 v_position;
varying vec3 v_normal;
varying vec2 v_texCoord0;

varying vec3 v_lightPosition;
                                                   
void main(void)\
{
    vec4 pos = a_position;

    float val = u_Waves * (pos.x - u_Velocity * u_Time);
    pos.z = u_Amplitude * min((pos.x - u_Anchors[0]) / abs(u_Anchors[1] - u_Anchors[0]), 1.0) * sin(val);

    v_normal = vec3(normalize(vec2(-u_Waves * u_Amplitude * cos(val), 1.0)), 0.0);

    v_position = u_MVMatrix * pos;
    v_texCoord0 = a_texCoord0;
    
    vec3 trans = vec3(u_MVMatrix[3][0], u_MVMatrix[3][1], u_MVMatrix[3][2]);
    v_lightPosition = trans + u_LightOffset;

    gl_Position = u_MVPMatrix * pos;
});

static NSString* const kRZClothFSH = RZ_SHADER_SRC(
precision mediump float;

const float c_Shininess = 10.0;
const vec3 c_Attenuation = vec3(1.0, 0.02, 0.017);
                                                   
uniform vec3 u_Ambient;
uniform vec3 u_Diffuse;
uniform vec3 u_Specular;

uniform sampler2D u_Texture;

varying vec4 v_position;
varying vec3 v_normal;
varying highp vec2 v_texCoord0;
                                                   
varying vec3 v_lightPosition;

void main(void)
{
    vec4 tex = texture2D(u_Texture, v_texCoord0);

    vec3 scatteredLight = vec3(0.0);
    vec3 reflectedLight = vec3(0.0);

    vec3 nNormal = normalize(v_normal);

    vec3 lightDirection = v_lightPosition - vec3(v_position);
    float lightDistance = length(lightDirection);

    lightDirection = lightDirection / lightDistance;

    float attenuation = 1.0 / (c_Attenuation[0] + c_Attenuation[1] * lightDistance + c_Attenuation[2] * lightDistance * lightDistance);

    vec3 halfVector = normalize(lightDirection + vec3(0.0, 0.0, 1.0));

    float diffuse = max(0.0, dot(nNormal, lightDirection));
    float diffuseExists = step(0.001, diffuse);

    float specular = dot(nNormal, halfVector);
    specular = diffuseExists * pow(specular, c_Shininess);

    scatteredLight += (u_Ambient * attenuation + u_Diffuse * diffuse * attenuation);
    reflectedLight += (u_Specular * specular * attenuation);

    vec3 rgb = min(tex.rgb * scatteredLight + reflectedLight, vec3(1.0));

    gl_FragColor = vec4(rgb, tex.a);
});

@implementation RZClothEffect

+ (instancetype)effect
{
    RZClothEffect *effect = [super effectWithVertexShader:kRZClothVSH fragmentShader:kRZClothFSH];
    
    effect.preferredLevelOfDetail = 6;
    
    effect.anchors = GLKVector2Make(-1.0f, 1.0f);
    
    effect.waveCount = 8.0f;
    effect.waveAmplitude = 0.05f;
    effect.waveVelocity = 0.8f;
    
    effect.lightOffset = GLKVector3Make(0.0f, 1.0f, 4.0f);
    effect.ambientLight = GLKVector3Make(1.0f, 1.0f, 1.0f);
    effect.diffuseLight = GLKVector3Make(1.0f, 1.0f, 1.0f);
    effect.specularLight = GLKVector3Make(0.6f, 0.6f, 0.6f);
    
    effect.mvpUniform = @"u_MVPMatrix";
    effect.mvUniform = @"u_MVMatrix";
        
    return effect;
}

- (void)setAnchors:(GLKVector2)anchors
{
    if ( anchors.x == anchors.y ) {
        anchors.y = anchors.x + 0.001;
    }
    
    _anchors = anchors;
}

- (BOOL)link
{
    [self bindAttribute:@"a_position" location:kRZVertexAttribPosition];
    [self bindAttribute:@"a_texCoord0" location:kRZVertexAttribTexCoord];
    
    return [super link];
}

- (void)prepareToDraw
{
    [super prepareToDraw];
    
    glUniform2fv([self uniformLoc:@"u_Anchors"], 1, _anchors.v);
    
    glUniform1f([self uniformLoc:@"u_Waves"] , _waveCount);
    glUniform1f([self uniformLoc:@"u_Amplitude"] , _waveAmplitude);
    glUniform1f([self uniformLoc:@"u_Velocity"] , _waveVelocity);

    
    glUniform3fv([self uniformLoc:@"u_LightOffset"], 1, _lightOffset.v);
    glUniform3fv([self uniformLoc:@"u_Ambient"], 1, _ambientLight.v);
    glUniform3fv([self uniformLoc:@"u_Diffuse"], 1, _diffuseLight.v);
    glUniform3fv([self uniformLoc:@"u_Specular"], 1, _specularLight.v);
    
    glUniform1f([self uniformLoc:@"u_Time"], CACurrentMediaTime());
}

@end
