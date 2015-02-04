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

typedef struct _RZGaussianBlurProperties {
    GLint sigma;
    GLfloat *weights;
    GLint numWeights;

    GLfloat *offsets;
    GLint numOffsets;
} RZGaussianBlurProperties;

static const GLuint kRZBlurEffectMinSigma = 2;
static const GLuint kRZBlurEffectMaxSigmaPerLevel = 8;
static const GLint kRZBlurEffectMaxOffsetsPerLevel = kRZBlurEffectMaxSigmaPerLevel + 1;

@interface RZBlurEffectPartial : RZEffect

@property (assign, nonatomic) RZBlurDirection direction;

@property (assign, nonatomic) RZGaussianBlurProperties blurProperties;
@property (assign, nonatomic) BOOL updateBlurProperties;

+ (instancetype)effectWithDirection:(RZBlurDirection)direction;

@end

@interface RZBlurEffectFull : RZCompositeEffect

@property (assign, nonatomic) GLint sigma;
@property (assign, nonatomic) GLuint downsample;

@property (assign, nonatomic) RZGaussianBlurProperties blurProperties;

void RZGetGaussianBlurWeights(GLfloat **weights, GLint *n, GLint sigma, GLint radius);
void RZGetGaussianBlurOffsets(GLfloat **offsets, GLint *n, const GLfloat *weights, GLint numWeights);

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
    RZBlurEffectPartial *horizontal = [RZBlurEffectPartial effectWithDirection:kRZBlurDirectionHorizontal];
    RZBlurEffectPartial *vertical = [RZBlurEffectPartial effectWithDirection:kRZBlurDirectionVertical];

    RZBlurEffectFull *blur = [RZBlurEffectFull compositeEffectWithFirstEffect:horizontal secondEffect:vertical];
    blur.sigma = kRZBlurEffectMinSigma;

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

    self.horizontal.modelViewMatrix = modelViewMatrix;
}

- (void)setProjectionMatrix:(GLKMatrix4)projectionMatrix
{
    [super setProjectionMatrix:projectionMatrix];

    self.horizontal.projectionMatrix = projectionMatrix;
}

- (void)setNormalMatrix:(GLKMatrix3)normalMatrix
{
    [super setNormalMatrix:normalMatrix];

    self.horizontal.normalMatrix = normalMatrix;
}

- (void)setResolution:(GLKVector2)resolution
{
    [super setResolution:resolution];

    self.firstBlur.resolution = resolution;
}

- (GLuint)downsampleLevel
{
    return [super downsampleLevel] + self.currentBlur.downsampleLevel;
}

- (void)setSigma:(GLint)sigma
{
    sigma = MAX(2, sigma);
    _sigma = sigma;

    __block GLint remainingSigma = sigma;
    [[self.blurs copy] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(RZBlurEffectFull *blur, NSUInteger idx, BOOL *stop) {
        if ( remainingSigma > 0 ) {
            GLfloat multiplier = powf(2.0f, MIN(self.blurs.count - idx - 1, RZ_EFFECT_MAX_DOWNSAMPLE));
            GLint levelSigma = MIN(ceilf(remainingSigma / multiplier), kRZBlurEffectMaxSigmaPerLevel);

            blur.sigma = levelSigma;

            remainingSigma -= levelSigma * multiplier;
        }
        else {
            [self.blurs removeObjectsInRange:NSMakeRange(0, idx + 1)];
            *stop = YES;
        }
    }];

    for ( GLuint i = (GLuint)self.blurs.count; remainingSigma > 0; i = MIN(i + 1, RZ_EFFECT_MAX_DOWNSAMPLE) ) {
        GLfloat multiplier = powf(2.0f, i);
        GLint levelSigma = MIN(ceilf(remainingSigma / multiplier), kRZBlurEffectMaxSigmaPerLevel);

        [self.blurs insertObject:[self rz_blurWithSigma:levelSigma downsample:i] atIndex:0];

        remainingSigma -= levelSigma * multiplier;
    }

    // TODO: might need to update currentIdx
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

- (RZBlurEffectFull *)rz_blurWithSigma:(GLint)sigma downsample:(GLuint)downsample
{
    RZBlurEffectFull *blur = [RZBlurEffectFull compositeEffectWithFirstEffect:self.horizontal secondEffect:self.vertical];
    blur.sigma = sigma;
    blur.downsample = downsample;

    return blur;
}

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

- (GLint)sigma
{
    return _blurProperties.sigma;
}

- (void)setSigma:(GLint)sigma
{
    _blurProperties.sigma = sigma;

    free(_blurProperties.weights);
    free(_blurProperties.offsets);

    RZGetGaussianBlurWeights(&_blurProperties.weights, &_blurProperties.numWeights, sigma, 2 * kRZBlurEffectMaxOffsetsPerLevel);
    RZGetGaussianBlurOffsets(&_blurProperties.offsets, &_blurProperties.numOffsets, _blurProperties.weights, _blurProperties.numWeights);
}

- (BOOL)prepareToDraw
{
    RZBlurEffectPartial *horizontal = (RZBlurEffectPartial *)self.firstEffect;
    RZBlurEffectPartial *vertical = (RZBlurEffectPartial *)self.secondEffect;

    horizontal.downsampleLevel = self.downsample;
    vertical.downsampleLevel = self.downsample;

    if ( horizontal.blurProperties.sigma != _blurProperties.sigma ) {
        horizontal.blurProperties = _blurProperties;
    }

    if ( vertical.blurProperties.sigma != _blurProperties.sigma ) {
        vertical.blurProperties = _blurProperties;
    }

    return [super prepareToDraw];
}

- (void)dealloc
{
    free(_blurProperties.weights);
    free(_blurProperties.offsets);
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

#pragma mark - private methods

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

#pragma mark - RZBlurEffectPartial

@implementation RZBlurEffectPartial

+ (instancetype)effectWithDirection:(RZBlurDirection)direction
{
    NSString *vsh = [self rz_vertexShaderWithNumOffsets:kRZBlurEffectMaxOffsetsPerLevel];
    NSString *fsh = [self rz_fragmentShaderWithNumWeights:2 * kRZBlurEffectMaxOffsetsPerLevel + 1];
    
    RZBlurEffectPartial *effect = [self effectWithVertexShader:vsh fragmentShader:fsh];
    effect.direction = direction;
    
    effect.mvpUniform = @"u_MVPMatrix";
    
    return effect;
}

- (void)setBlurProperties:(RZGaussianBlurProperties)blurProperties
{
    _blurProperties = blurProperties;
    self.updateBlurProperties = YES;
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
    
    if ( self.updateBlurProperties ) {
        glUniform1fv([self uniformLoc:@"u_Weights"], _blurProperties.numWeights, _blurProperties.weights);
        glUniform1fv([self uniformLoc:@"u_Offsets"], _blurProperties.numOffsets, _blurProperties.offsets);
        
        self.updateBlurProperties = NO;
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

@end
