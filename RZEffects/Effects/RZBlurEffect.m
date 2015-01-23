//
//  RZBlurEffect.m
//
//  Created by Rob Visentin on 1/16/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/gl.h>

#import "RZBlurEffect.h"

typedef NS_ENUM(NSUInteger, RZBlurDirection) {
    kRZBlurDirectionHorizontal,
    kRZBlurDirectionVertical
};

//static const GLfloat kRZBlurEffectMinTexelContribution = 1.0f / 256.0f;
static const GLuint kRZBlurEffectMaxSigmaPerLevel = 8;
static const GLint kRZBlurEffectMaxOffsetsPerLevel = kRZBlurEffectMaxSigmaPerLevel + 1;

void RZGetGaussianBlurWeights(GLfloat **weights, GLint *n, GLint sigma, GLint radius);
void RZGetGaussianBlurOffsets(GLfloat **offsets, GLint *n, const GLfloat *weights, GLint numWeights);

@interface RZBlurEffectPartial : RZEffect

@property (assign, nonatomic) GLint sigma;
@property (assign, nonatomic) RZBlurDirection direction;

@property (assign, nonatomic) GLfloat *weights;
@property (assign, nonatomic) GLint numWeights;

@property (assign, nonatomic) GLfloat *offsets;
@property (assign, nonatomic) GLint numOffsets;

@property (assign, nonatomic) BOOL updateOffsets;

+ (instancetype)effectWithSigma:(GLint)sigma direction:(RZBlurDirection)direction;

@end

@implementation RZBlurEffect

+ (instancetype)effectWithSigma:(GLint)sigma
{
//    RZEffect *e1 = [RZBlurEffect rz_effectWithSigma:5 downsample:3];
    
    GLint levels = ceilf((float)sigma / kRZBlurEffectMaxSigmaPerLevel);
    
    RZBlurEffect *blur = nil;
    
    for ( GLint level = levels; level > 0; level-- ) {
        GLint levelSigma = sigma / pow(2.0, level);
        
        RZBlurEffect *levelBlur = [self rz_effectWithSigma:levelSigma downsample:(pow(2.0, level) - 1)];
        
        if ( blur == nil ) {
            blur = levelBlur;
        }
        else {
            blur = [self compositeEffectWithFirstEffect:blur secondEffect:levelBlur];
        }
    }
    
    return blur;
}

- (void)setSigma:(GLint)sigma
{
    _sigma = sigma;
    ((RZBlurEffectPartial *)self.firstEffect).sigma = sigma;
    ((RZBlurEffectPartial *)self.secondEffect).sigma = sigma;
}

#pragma mark - private methods

+ (instancetype)rz_effectWithSigma:(GLint)sigma downsample:(GLint)downsample
{
    RZBlurEffectPartial *e1 = [RZBlurEffectPartial effectWithSigma:sigma direction:kRZBlurDirectionHorizontal];
    e1.downsampleLevel = downsample;
    
    RZBlurEffectPartial *e2 = [RZBlurEffectPartial effectWithSigma:sigma direction:kRZBlurDirectionVertical];
    e2.downsampleLevel = downsample;
    
    RZBlurEffect *effect = [self compositeEffectWithFirstEffect:e1 secondEffect:e2];
    effect.sigma = sigma;
    
    return effect;
}

@end

@implementation RZBlurEffectPartial

+ (instancetype)effectWithSigma:(GLint)sigma direction:(RZBlurDirection)direction
{
    NSString *vsh, *fsh;
    
    if ( sigma < 2 ) {
        vsh = kRZEffectDefaultVSH2D;
        fsh = kRZEffectDefaultFSH;
    }
    else {
        // compute a nice blur radius for the given sigma
//        GLint radius = sqrt(-2.0 * sigma * sigma * log(kRZBlurEffectMinTexelContribution * sqrt(2.0 * M_PI * sigma * sigma)));
//        GLfloat *weights, *offsets;
//        GLint numWeights, numOffsets;
//        
//        RZGetGaussianBlurWeights(&weights, &numWeights, sigma, radius);
//        RZGetGaussianBlurOffsets(&offsets, &numOffsets, weights, numWeights);
//        
//        vsh = [self rz_vertexShaderForDirection:direction offsets:offsets numOffsets:numOffsets];
//        fsh = [self rz_fragmentShaderForDirection:direction weights:weights numWeights:numWeights offsets:offsets numOffsets:numOffsets];
//        
//        free(weights);
//        free(offsets);
        
        vsh = [self rz_vertexShaderWithNumOffsets:kRZBlurEffectMaxOffsetsPerLevel];
        fsh = [self rz_fragmentShaderWithNumWeights:2 * kRZBlurEffectMaxOffsetsPerLevel + 1];
    }
    
    RZBlurEffectPartial *effect = [self effectWithVertexShader:vsh fragmentShader:fsh];
    effect.sigma = sigma;
    effect.direction = direction;
    
    effect.mvpUniform = @"u_MVPMatrix";
    
    return effect;
}

- (void)setSigma:(GLint)sigma
{
    _sigma = sigma;
    
    free(_weights);
    free(_offsets);
    
//    GLint radius = sqrt(-2.0 * sigma * sigma * log(kRZBlurEffectMinTexelContribution * sqrt(2.0 * M_PI * sigma * sigma)));
    
    RZGetGaussianBlurWeights(&_weights, &_numWeights, sigma, 2 * kRZBlurEffectMaxOffsetsPerLevel);
    RZGetGaussianBlurOffsets(&_offsets, &_numOffsets, _weights, _numWeights);
    
    self.updateOffsets = YES;
}

- (BOOL)link
{
    [self bindAttribute:@"a_position" location:kRZVertexAttribPosition];
    [self bindAttribute:@"a_texCoord0" location:kRZVertexAttribTexCoord];
    
    return [super link];
}

- (BOOL)prepareToDraw
{
    BOOL ret = [super prepareToDraw];
    
    if ( self.updateOffsets ) {
        glUniform1fv([self uniformLoc:@"u_Weights"], _numWeights, _weights);
        glUniform1fv([self uniformLoc:@"u_Offsets"], _numOffsets, _offsets);
        
        self.updateOffsets = NO;
    }
    
    GLfloat scale = powf(2.0, self.downsampleLevel);
    
    glUniform2f([self uniformLoc:@"u_Step"], (1 - self.direction) * scale / self.resolution.x, self.direction * scale / self.resolution.y);
    
    return ret;
}

#pragma mark - private methods

+ (NSString *)rz_vertexShaderWithNumOffsets:(GLint)numOffsets
{
    NSMutableString *vsh = [NSMutableString string];
    
    [vsh appendFormat:@"\
     uniform vec2 u_Step;\n\
     uniform float u_Offsets[%i];\n\
     \n\
     attribute vec4 a_position;\n\
     attribute vec2 a_texCoord0;\n\
     \n\
     varying vec2 v_blurCoords[%i];\n\
     \n\
     void main(void)\n\
     {\n\
     gl_Position = a_position;\n\
     v_blurCoords[0] = a_texCoord0;\n\
     ", numOffsets, numOffsets * 2 + 1];
    
    for ( int i = 0; i < numOffsets; i++ ) {
        [vsh appendFormat:@"v_blurCoords[%i] = a_texCoord0 + u_Step * u_Offsets[%i];\n", i * 2 + 1, i];
        [vsh appendFormat:@"v_blurCoords[%i] = a_texCoord0 - u_Step * u_Offsets[%i];\n", i * 2 + 2, i];
    }
    
    [vsh appendString:@"}"];
    
    return vsh;
}

+ (NSString *)rz_fragmentShaderWithNumWeights:(GLint)numWeights
{
    NSMutableString *fsh = [NSMutableString string];
    
    [fsh appendFormat:@"\
     uniform lowp sampler2D u_Texture;\n\
     \n\
     uniform highp vec2 u_Step;\n\
     uniform highp float u_Weights[%i];\n\
     \n\
     varying highp vec2 v_blurCoords[%i];\n\
     \n\
     void main(void)\n\
     {\n\
     lowp vec4 color = texture2D(u_Texture, v_blurCoords[0]) * u_Weights[0];\n\
     highp float weight = 0.0;\n\
     ", numWeights, numWeights];
    
    for ( int i = 0; i < ceil((numWeights - 1) / 2); i++ ) {
        [fsh appendFormat:@"weight = u_Weights[%i] + u_Weights[%i];\n", i * 2 + 1, i * 2 + 2];
        
        [fsh appendFormat:@"color += texture2D(u_Texture, v_blurCoords[%i]) * weight;\n", i * 2 + 1];
        [fsh appendFormat:@"color += texture2D(u_Texture, v_blurCoords[%i]) * weight;\n", i * 2 + 2];
    }
    
    [fsh appendString:@"\
     gl_FragColor = color;\n\
     }"];
    
    return fsh;
}

// adapted from GPUImage Gaussian blur filter
// see: https://github.com/BradLarson/GPUImage
+ (NSString *)rz_vertexShaderForDirection:(RZBlurDirection)direction offsets:(GLfloat *)offsets numOffsets:(GLint)numOffsets
{
    numOffsets = MIN(numOffsets, kRZBlurEffectMaxOffsetsPerLevel);
    
    GLfloat hStep = (direction == kRZBlurDirectionHorizontal) ? 1.0f : 0.0f;
    GLfloat vStep = (direction == kRZBlurDirectionHorizontal) ? 0.0f : 1.0f;
    
    NSMutableString *vsh = [[NSMutableString alloc] init];
    
    [vsh appendFormat:@"\
     uniform float u_Step;\n\
     \n\
     attribute vec4 a_position;\n\
     attribute vec2 a_texCoord0;\n\
     \n\
     varying vec2 v_blurCoords[%i];\n\
     \n\
     void main(void)\n\
     {\n\
     gl_Position = a_position;\n\
     \n\
     vec3 gaussian = u_Gaussian;\n\
     vec2 texStep = vec2(%f * u_Step, %f * u_Step);\n", numOffsets * 2 + 1, hStep, vStep];
    
    [vsh appendString:@"v_blurCoords[0] = a_texCoord0;\n"];
    
    for ( GLint i = 0; i < numOffsets; i++ ) {
        [vsh appendFormat:@"\
         v_blurCoords[%i] = a_texCoord0 + texStep * %f;\n\
         v_blurCoords[%i] = a_texCoord0 - texStep * %f;\n", i * 2 + 1, offsets[i], i * 2 + 1, offsets[i]];
    }
    
    [vsh appendString:@"}"];
    
    return vsh;
}

// adapted from GPUImage Gaussian blur filter
// see: https://github.com/BradLarson/GPUImage
+ (NSString *)rz_fragmentShaderForDirection:(RZBlurDirection)direction weights:(GLfloat *)weights numWeights:(GLint)numWeights offsets:(GLfloat *)offsets numOffsets:(GLint)numOffsets
{
    GLint trueNumOffsets = numOffsets;
    numOffsets = MIN(numOffsets, kRZBlurEffectMaxOffsetsPerLevel);
    
    NSMutableString *fsh = [[NSMutableString alloc] init];
    
    [fsh appendFormat:@"\
     uniform lowp sampler2D u_Texture;\n\
     uniform highp vec2 u_Step;\n\
     \n\
     varying highp vec2 v_blurCoords[%i];\n\
     \n\
     void main(void)\n\
     {\n\
     lowp vec4 sum = texture2D(u_Texture, v_blurCoords[0]) * %f;\n", numOffsets * 2 + 1, weights[0]];
    
    for ( GLint i = 0; i < trueNumOffsets; i++ ) {
        GLfloat w1 = weights[i * 2 + 1];
        GLfloat w2 = weights[i * 2 + 2];
        
        GLfloat sum = w1 + w2;
        
        if ( i < numOffsets ) {
            [fsh appendFormat:@"sum += texture2D(u_Texture, v_blurCoords[%i]) * %f;\n", i * 2 + 1, sum];
            [fsh appendFormat:@"sum += texture2D(u_Texture, v_blurCoords[%i]) * %f;\n", i * 2 + 2, sum];
        }
        else {
            // if the number of required samples exceeds the amount we can pass in via varyings, we have to do dependent texture reads
            [fsh appendFormat:@"sum += texture2D(u_Texture, v_blurCoords[0] + u_Step * %f) * %f;\n", offsets[i], sum];
            [fsh appendFormat:@"sum += texture2D(u_Texture, v_blurCoords[0] - u_Step * %f) * %f;\n", offsets[i], sum];
        }
    }
    
    [fsh appendString:@"\
     gl_FragColor = sum;\n\
     }"];
    
    return fsh;
}

void RZGetGaussianBlurWeights(GLfloat **weights, GLint *n, GLint sigma, GLint radius)
{
    GLint numWeights = radius + 1;
    *weights = (GLfloat *)malloc(numWeights * sizeof(GLfloat));
    
    GLfloat norm = (1.0f / sqrtf(2.0f * M_PI * sigma * sigma));
    (*weights)[0] = norm;
    GLfloat sum = norm;
    
    // compute standard Gaussian weights using the 1-dimensional Gaussian function
    for ( GLint i = 1; i < numWeights; i++ ) {
        GLfloat weight =  norm * exp(-i * i / (2.0 * sigma * sigma));
        (*weights)[i] = weight;
        sum += 2.0f * weight;
    }
    
    // normalize weights to prevent the clipping of the Gaussian curve and reduced luminance
    for ( GLint i = 0; i < numWeights; i++ ) {
        (*weights)[i] /= sum;
    }
    
    if ( n != NULL ) {
        *n = numWeights;
    }
}

void RZGetGaussianBlurOffsets(GLfloat **offsets, GLint *n, const GLfloat *weights, GLint numWeights)
{
    GLint radius = numWeights - 1;
    
    // compute the offsets at which to read interpolated texel values
    // see: http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    GLint numOffsets = ceilf(radius / 2.0);
    *offsets = (GLfloat *)malloc(numOffsets * sizeof(GLfloat));
    
    for ( GLint i = 0; i < numOffsets; i++ ) {
        GLfloat w1 = weights[i * 2 + 1];
        GLfloat w2 = weights[i * 2 + 2];
        
        (*offsets)[i] = (w1 * (i * 2 + 1) + w2 * (i * 2 + 2)) / (w1 + w2);
    }
    
    if ( n != NULL ) {
        *n = numOffsets;
    }
}

@end
