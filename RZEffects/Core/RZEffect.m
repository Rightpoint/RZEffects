//
//  RZEffect.m
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/EAGL.h>

#import "RZEffect.h"

NSString* const kRZEffectDefaultVSH2D = RZ_SHADER_SRC(
attribute vec4 a_position;
attribute vec2 a_texCoord0;
                                                  
varying vec2 v_texCoord0;
                                                  
void main(void)
{
    v_texCoord0 = a_texCoord0;
    gl_Position = a_position;
});

NSString* const kRZEffectDefaultVSH3D = RZ_SHADER_SRC(
uniform mat4 u_MVPMatrix;

attribute vec4 a_position;
attribute vec2 a_texCoord0;

varying vec2 v_texCoord0;

void main(void)
{
    v_texCoord0 = a_texCoord0;
    gl_Position = u_MVPMatrix * a_position;
});

NSString* const kRZEffectDefaultFSH = RZ_SHADER_SRC(
uniform lowp sampler2D u_Texture;
                                                    
varying highp vec2 v_texCoord0;
                                         
void main()
{
    gl_FragColor = texture2D(u_Texture, v_texCoord0);
});

GLuint RZCompileShader(const GLchar *source, GLenum type);

@interface RZEffect () {
    GLuint _name;
    
    GLint _mvpMatrixLoc;
    GLint _mvMatrixLoc;
    GLint _normalMatrixLoc;
}

@property (strong, nonatomic) NSString *vshSrc;
@property (strong, nonatomic) NSString *fshSrc;

@property (nonatomic, readwrite, getter = isLinked) BOOL linked;

@property (strong, nonatomic) NSCache *uniforms;

@end

@implementation RZEffect

#pragma mark - lifecycle

+ (instancetype)effectWithVertexShaderNamed:(NSString *)vshName fragmentShaderNamed:(NSString *)fshName
{
    NSString *vshPath = [[NSBundle mainBundle] pathForResource:vshName ofType:@"vsh"];
    NSString *fshPath = [[NSBundle mainBundle] pathForResource:fshName ofType:@"fsh"];
    
    NSString *vsh = [NSString stringWithContentsOfFile:vshPath encoding:NSASCIIStringEncoding error:nil];
    NSString *fsh = [NSString stringWithContentsOfFile:fshPath encoding:NSASCIIStringEncoding error:nil];
    
#if DEBUG
    if ( vsh == nil ) {
        NSLog(@"%@ failed to load vertex shader %@.vsh", NSStringFromClass(self), vshName);
    }
    
    if ( fsh == nil ) {
        NSLog(@"%@ failed to load fragment shader %@.fsh", NSStringFromClass(self), fshName);
    }
#endif

    return [self effectWithVertexShader:vsh fragmentShader:fsh];
}

+ (instancetype)effectWithVertexShader:(NSString *)vsh fragmentShader:(NSString *)fsh
{
    RZEffect *effect = nil;
    
#if DEBUG
    if ( vsh == nil ) {
        NSLog(@"%@ failed to intialize, missing vertex shader.", NSStringFromClass(self));
    }
    
    if ( fsh == nil ) {
        NSLog(@"%@ failed to intialize, missing fragment shader.", NSStringFromClass(self));
    }
#endif
    
    if ( vsh != nil && fsh != nil ) {
        effect = [[self alloc] initWithVertexShader:vsh fragmentShader:fsh];
    }
    
    return effect;
}

#pragma mark - public methods

- (void)setDownsampleLevel:(GLuint)downsampleLevel
{
    _downsampleLevel = MIN(downsampleLevel, RZ_EFFECT_MAX_DOWNSAMPLE);
}

- (NSInteger)preferredLevelOfDetail
{
    return 0;
}

- (BOOL)link
{
    [self.uniforms removeAllObjects];
    
    glLinkProgram(_name);
    
    GLint success;
    glGetProgramiv(_name, GL_LINK_STATUS, &success);
    
#if DEBUG
    if ( success != GL_TRUE ) {
        GLint length;
        glGetProgramiv(_name, GL_INFO_LOG_LENGTH, &length);
        
        GLchar *logText = (GLchar *)malloc(length + 1);
        logText[length] = '\0';
        glGetProgramInfoLog(_name, length, NULL, logText);
        
        fprintf(stderr, "Error linking %s: %s\n", [NSStringFromClass([self class]) UTF8String], logText);
        
        free(logText);
    }
#endif

    self.linked = (success == GL_TRUE);
    
    if ( self.isLinked && self.mvpUniform != nil ) {
        _mvpMatrixLoc = [self uniformLoc:self.mvpUniform];
    }
    
    if (self.isLinked && self.mvUniform != nil ) {
        _mvMatrixLoc = [self uniformLoc:self.mvUniform];
    }
    
    if ( self.isLinked && self.normalMatrixUniform != nil ) {
        _normalMatrixLoc = [self uniformLoc:self.normalMatrixUniform];
    }
    
    return self.isLinked;
}

- (BOOL)prepareToDraw
{
    [self bindGL];
    
    if ( _mvpMatrixLoc >= 0 )
    {
        GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(_projectionMatrix, _modelViewMatrix);
        glUniformMatrix4fv(_mvpMatrixLoc, 1, GL_FALSE, mvpMatrix.m);
    }
    
    if ( _mvMatrixLoc >= 0 ) {
        glUniformMatrix4fv(_mvMatrixLoc, 1, GL_FALSE, _modelViewMatrix.m);
    }
    
    if ( _normalMatrixLoc >= 0 )
    {
        glUniformMatrix3fv(_normalMatrixLoc, 1, GL_FALSE, _normalMatrix.m);
    }
    
    return NO;
}

- (void)bindAttribute:(NSString *)attribute location:(GLuint)location
{
    glBindAttribLocation(_name, location, [attribute UTF8String]);
}

- (GLint)uniformLoc:(NSString *)uniformName
{
    GLuint loc;
    NSNumber *cachedLoc = [self.uniforms objectForKey:uniformName];
    
    if ( cachedLoc != nil ) {
        loc = cachedLoc.intValue;
    }
    else {
        loc = glGetUniformLocation(_name, [uniformName UTF8String]);
        
        if ( loc != -1 ) {
            [self.uniforms setObject:@(loc) forKey:uniformName];
        }
    }
    
    return loc;
}

#pragma mark - RZOpenGLObject

- (void)setupGL
{
    if ( [EAGLContext currentContext] != nil ) {
        [self teardownGL];
        
        GLuint vs = RZCompileShader([self.vshSrc UTF8String], GL_VERTEX_SHADER);
        GLuint fs = RZCompileShader([self.fshSrc UTF8String], GL_FRAGMENT_SHADER);
        
        _name = glCreateProgram();
        
        glAttachShader(_name, vs);
        glAttachShader(_name, fs);
    }
    else {
        NSLog(@"Failed to setup %@: No active EAGLContext.", NSStringFromClass([self class]));
    }
}

- (void)bindGL
{
    glUseProgram(_name);
}

- (void)teardownGL
{
    glDeleteProgram(_name);
}

#pragma mark - private methods

- (instancetype)initWithVertexShader:(NSString *)vsh fragmentShader:(NSString *)fsh
{
    self = [self init];
    if ( self ) {
        _vshSrc = vsh;
        _fshSrc = fsh;
        
        _mvpMatrixLoc = -1;
        _mvMatrixLoc = -1;
        _normalMatrixLoc = -1;
        
        _modelViewMatrix = GLKMatrix4Identity;
        _projectionMatrix = GLKMatrix4Identity;
        _normalMatrix = GLKMatrix3Identity;
        
        _uniforms = [[NSCache alloc] init];
    }
    return self;
}

GLuint RZCompileShader(const GLchar *source, GLenum type)
{
    GLuint shader = glCreateShader(type);
    GLint length = (GLuint)strlen(source);
    
    glShaderSource(shader, 1, &source, &length);
    glCompileShader(shader);
    
#if DEBUG
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    
    if ( success != GL_TRUE ) {
        GLint length;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
        
        GLchar *logText = malloc(length + 1);
        logText[length] = '\0';
        glGetShaderInfoLog(shader, length, NULL, logText);
        
        fprintf(stderr, "Error compiling shader: %s\n", logText);
        
        free(logText);
    }
#endif
    
    return shader;
}

@end
