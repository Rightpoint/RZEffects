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

static const GLuint kRZBlurEffectMaxSigmaPerLevel = 8;
static const GLint kRZBlurEffectMaxOffsetsPerLevel = kRZBlurEffectMaxSigmaPerLevel + 1;

void RZGetGaussianBlurWeights(GLfloat **weights, GLint *n, GLint sigma, GLint radius);
void RZGetGaussianBlurOffsets(GLfloat **offsets, GLint *n, const GLfloat *weights, GLint numWeights);

@interface RZBlurEffectPartial : RZEffect

@property (assign, nonatomic) RZBlurDirection direction;
@property (assign, nonatomic) GLint sigma;

@property (assign, nonatomic) GLfloat *weights;
@property (assign, nonatomic) GLint numWeights;

@property (assign, nonatomic) GLfloat *offsets;
@property (assign, nonatomic) GLint numOffsets;

@property (assign, nonatomic) BOOL updateOffsets;

+ (instancetype)effectWithSigma:(GLint)sigma direction:(RZBlurDirection)direction;

@end

@interface RZBlurEffectFull : RZCompositeEffect

@property (assign, nonatomic) GLint sigma;

@end

@interface RZBlurEffect ()

@property (strong, nonatomic) RZBlurEffectPartial *horizontal;
@property (strong, nonatomic) RZBlurEffectPartial *vertical;

@property (strong, nonatomic) NSMutableArray *blurs;
@property (assign, nonatomic) NSUInteger currentIdx;

@property (nonatomic, readonly) RZBlurEffectFull *firstBlur;
@property (nonatomic, readonly) RZBlurEffectFull *currentBlur;

@end

@implementation RZBlurEffect

+ (instancetype)effect
{
    GLint sigma = kRZBlurEffectMaxSigmaPerLevel;

    RZBlurEffectPartial *horizontal = [RZBlurEffectPartial effectWithSigma:sigma direction:kRZBlurDirectionHorizontal];
    horizontal.downsampleLevel = 0;

    RZBlurEffectPartial *vertical = [RZBlurEffectPartial effectWithSigma:sigma direction:kRZBlurDirectionVertical];
    vertical.downsampleLevel = 0;

    RZBlurEffectFull *blur = [RZBlurEffectFull compositeEffectWithFirstEffect:horizontal secondEffect:vertical];
    blur.sigma = sigma;

    RZBlurEffect *effect = [[RZBlurEffect alloc] init];
    effect.horizontal = horizontal;
    effect.vertical = vertical;

    effect.blurs = [NSMutableArray arrayWithObject:blur];

    return effect;
}

#pragma mark - overrides

- (BOOL)isLinked
{
    return self.horizontal.isLinked && self.vertical.isLinked;
}

- (BOOL)link
{
    return [self.horizontal link] && [self.vertical link];
}

- (void)setModelViewMatrix:(GLKMatrix4)modelViewMatrix
{
    [super setModelViewMatrix:modelViewMatrix];

    self.firstBlur.modelViewMatrix = modelViewMatrix;
}

- (void)setProjectionMatrix:(GLKMatrix4)projectionMatrix
{
    [super setProjectionMatrix:projectionMatrix];

    self.firstBlur.projectionMatrix = projectionMatrix;
}

- (void)setNormalMatrix:(GLKMatrix3)normalMatrix
{
    [super setNormalMatrix:normalMatrix];

    self.firstBlur.normalMatrix = normalMatrix;
}

- (void)setResolution:(GLKVector2)resolution
{
    [super setResolution:resolution];

    [self.blurs enumerateObjectsUsingBlock:^(RZBlurEffectFull *blur, NSUInteger idx, BOOL *stop) {
        blur.resolution = resolution;
    }];
}

- (GLuint)downsampleLevel
{
    return [super downsampleLevel] + self.currentBlur.downsampleLevel;
}

- (void)setSigma:(GLint)sigma
{
    _sigma = sigma;

    self.firstBlur.sigma = sigma;

    // TODO: set individual blur sigmas
}

- (BOOL)prepareToDraw
{
    BOOL unfinished = YES;

    if ( ![self.currentBlur prepareToDraw] ) {
        if ( self.currentIdx + 1 < self.blurs.count ) {
            self.currentIdx++;;
        }
        else {
            self.currentIdx = 0;
            unfinished = NO;
        }
    }

    return unfinished;
}

- (void)bindAttribute:(NSString *)attribute location:(GLuint)location
{
    // empty implementation
}

- (GLint)uniformLoc:(NSString *)uniformName
{
    return -1;
}

#pragma mark - RZOpenGLObject

- (void)setupGL
{
    [self.horizontal setupGL];
    [self.vertical setupGL];
}

- (void)bindGL
{
    [self.currentBlur bindGL];
}

- (void)teardownGL
{
    [self.horizontal teardownGL];
    [self.vertical teardownGL];
}

#pragma mark - private methods

- (RZBlurEffectFull *)firstBlur
{
    return (RZBlurEffectFull *)[self.blurs firstObject];
}

- (RZBlurEffectFull *)currentBlur
{
    return (RZBlurEffectFull *)self.blurs[self.currentIdx];
}

@end

#pragma mark - RZBlurEffectFull

@implementation RZBlurEffectFull

- (void)setSigma:(GLint)sigma
{
    _sigma = sigma;

    ((RZBlurEffectPartial *)self.firstEffect).sigma = sigma;
    ((RZBlurEffectPartial *)self.secondEffect).sigma = sigma;
}

#pragma mark - RZOpenGLObject

- (void)setupGL
{
    // empty implementation
}

- (void)teardownGL
{
    // empty implementation
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    RZBlurEffect *copy = [super copyWithZone:zone];

    copy.sigma = self.sigma;

    return copy;
}

@end

#pragma mark - RZBlurEffectPartial

@implementation RZBlurEffectPartial

+ (instancetype)effectWithSigma:(GLint)sigma direction:(RZBlurDirection)direction
{
    NSString *vsh, *fsh;
    
    if ( sigma < 2 ) {
        vsh = kRZEffectDefaultVSH2D;
        fsh = kRZEffectDefaultFSH;
    }
    else {
        vsh = [self rz_vertexShaderWithNumOffsets:kRZBlurEffectMaxOffsetsPerLevel];
        fsh = [self rz_fragmentShaderWithNumWeights:2 * kRZBlurEffectMaxOffsetsPerLevel + 1];
    }
    
    RZBlurEffectPartial *effect = [self effectWithVertexShader:vsh fragmentShader:fsh];
    effect.sigma = sigma;
    effect.direction = direction;
    
    effect.mvpUniform = @"u_MVPMatrix";
    
    return effect;
}

- (void)dealloc
{
    free(_weights);
    free(_offsets);
}

- (void)setSigma:(GLint)sigma
{
    _sigma = sigma;
    
    free(_weights);
    free(_offsets);
    
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

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    RZBlurEffectPartial *copy = [super copyWithZone:zone];

    copy.direction = self.direction;
    copy.sigma = self.sigma;

    return copy;
}

#pragma mark - private methods

+ (NSString *)rz_vertexShaderWithNumOffsets:(GLint)numOffsets
{
    NSMutableString *vsh = [NSMutableString string];
    
    [vsh appendFormat:@"\
     uniform mat4 u_MVPMatrix;\n\
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
     gl_Position = u_MVPMatrix * a_position;\n\
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
