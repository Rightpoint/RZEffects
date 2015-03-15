//
//  RZUIEffectView.m
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/glext.h>

#import "RZUIEffectView.h"

#import "RZEffectContext.h"
#import "RZViewTexture.h"
#import "RZQuadMesh.h"

static const GLenum s_GLDiscards[]  = {GL_DEPTH_ATTACHMENT, GL_COLOR_ATTACHMENT0};

#define RZ_EFFECT_AUX_TEXTURES (RZ_EFFECT_MAX_DOWNSAMPLE + 1)

@interface RZGLView (RZProtected)

- (void)rz_createBuffers;
- (void)rz_destroyBuffers;

@end

@interface RZUIEffectView () <RZUpdateable, RZRenderable> {
    GLuint _fbos[2];
    GLuint _drbs[2];
    
    GLuint _auxTex[2][RZ_EFFECT_AUX_TEXTURES];
}

@property (nonatomic, readonly) RZEffectContext *context;

@property (strong, nonatomic) IBOutlet UIView *sourceView;
@property (strong, nonatomic) RZViewTexture *viewTexture;

@property (assign, nonatomic) BOOL textureLoaded;

@end

@implementation RZUIEffectView

#pragma mark - lifecycle

- (instancetype)initWithSourceView:(UIView *)view effect:(RZEffect *)effect dynamicContent:(BOOL)dynamic
{
    self = [super initWithFrame:view.bounds];
    if ( self ) {
        self.dynamic = dynamic;
        self.effect = effect;
        self.sourceView = view;
    }
    return self;
}

#pragma mark - public methods

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self rz_updateCamera];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self rz_updateCamera];
}

- (void)setEffect:(RZEffect *)effect
{
    [self.context runBlock:^(RZEffectContext *context){
        [self rz_setEffect:effect];
    }];
}

- (void)display
{
    [self.context runBlock:^(RZEffectContext *context){
        context.depthTestEnabled = YES;
        context.cullFace = GL_BACK;

        context.activeTexture = GL_TEXTURE0;
        context.clearColor = self.backgroundColor.CGColor;

        [self bindGL];

        int fbo = 0;

        GLuint downsample = self.effect.downsampleLevel;
        GLint denom = pow(2.0, downsample);

        while ( [self.effect prepareToDraw] ) {
            context.viewport = CGRectMake(0.0f, 0.0f, _backingWidth/denom, _backingHeight/denom);
            glBindFramebuffer(GL_FRAMEBUFFER, _fbos[fbo]);

            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _auxTex[fbo][downsample], 0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            [self.model render];

            glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, s_GLDiscards);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
            glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, &s_GLDiscards[1]);

            glBindTexture(GL_TEXTURE_2D, _auxTex[fbo][downsample]);
            fbo = 1 - fbo;

            downsample = self.effect.downsampleLevel;
            denom = pow(2.0, downsample);
        };

        // TODO: what if the last effect has lower downsample?

        context.viewport = CGRectMake(0.0f, 0.0f, _backingWidth, _backingHeight);

        glBindFramebuffer(GL_FRAMEBUFFER, _fbos[fbo]);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _crb);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        [self.model render];

        glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, s_GLDiscards);

        glBindRenderbuffer(GL_RENDERBUFFER, _crb);
        [context presentRenderbuffer:GL_RENDERBUFFER];

        glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, &s_GLDiscards[1]);

        glUseProgram(0);
        glBindTexture(GL_TEXTURE_2D, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
    }];
}

#pragma mark - protected methods

- (void)rz_createBuffers
{
    [super rz_createBuffers];

    _fbos[0] = _fbo;
    _drbs[0] = _drb;

    glGenFramebuffers(1, &_fbos[1]);
    glGenRenderbuffers(1, &_drbs[1]);

    glBindFramebuffer(GL_FRAMEBUFFER, _fbos[1]);
    glBindRenderbuffer(GL_RENDERBUFFER, _drbs[1]);

    glGenTextures(2 * RZ_EFFECT_AUX_TEXTURES, _auxTex[0]);

    for ( int tex = 0; tex < 2; tex++ ) {
        for ( int i = 0; i < RZ_EFFECT_AUX_TEXTURES; i++ ) {
            GLsizei denom = pow(2.0, i);

            glBindTexture(GL_TEXTURE_2D, _auxTex[tex][i]);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _backingWidth / denom, _backingHeight / denom, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        }
    }

    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, _backingWidth, _backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _drbs[1]);

    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

- (void)rz_destroyBuffers
{
    [super rz_destroyBuffers];

    if ( _fbos[1] != 0 ) {
        glDeleteFramebuffers(1, &_fbos[1]);
        glDeleteRenderbuffers(1, &_drbs[1]);
        glDeleteTextures(2 * RZ_EFFECT_AUX_TEXTURES, _auxTex[0]);
    }

    memset(_fbos, 0, 2 * sizeof(GLuint));
    memset(_drbs, 0, 2 * sizeof(GLuint));
    memset(_auxTex, 0, 2 * RZ_EFFECT_AUX_TEXTURES * sizeof(GLuint));
}

#pragma mark - private methods

- (RZEffectContext *)context
{
    return _context;
}

- (void)setSourceView:(UIView *)sourceView
{
    _sourceView = sourceView;

    self.effectCamera = [RZCamera cameraWithFieldOfView:GLKMathDegreesToRadians(30.0f) aspectRatio:1.0f nearClipping:0.001f farClipping:10.0f];

    self.effectTransform = [RZTransform3D transform];

    [self rz_createTexture];
    [self rz_updateCamera];
}

- (void)rz_updateCamera
{
    CGFloat aspectRatio = (CGRectGetWidth(self.bounds) / CGRectGetWidth(self.bounds));
    self.effectCamera.aspectRatio = aspectRatio;

    GLKVector3 camTrans = GLKVector3Make(0.0f, 0.0f, -1.0f / tanf(self.effectCamera.fieldOfView / 2.0f));
    self.effectTransform.translation = GLKVector3Add(self.effectTransform.translation, camTrans);
}

- (void)rz_createTexture
{
    if ( self.sourceView != nil ) {
        [self.context runBlock:^(RZEffectContext *context) {
            [_viewTexture teardownGL];
            _viewTexture = [RZViewTexture textureWithSize:self.sourceView.bounds.size];
            [_viewTexture setupGL];
        }];
    }
}

- (void)rz_setEffect:(RZEffect *)effect
{
    [_effect teardownGL];
    
    [effect setupGL];
    
    if ( [effect link] ) {
        _effect = effect;

        self.model = [RZQuadMesh quadWithSubdivisionLevel:effect.preferredLevelOfDetail];

    }
    else {
        _effect = nil;

        self.model = nil;
    }
}

- (void)rz_congfigureEffect
{
    GLKMatrix4 model, view, projection;
    
    if ( self.effectTransform != nil ) {
        model = self.effectTransform.modelMatrix;
    }
    else {
        model = GLKMatrix4Identity;
    }
    
    if ( self.effectCamera != nil ) {
        view = self.effectCamera.viewMatrix;
        projection = self.effectCamera.projectionMatrix;
    }
    else {
        view = GLKMatrix4Identity;
        projection = GLKMatrix4Identity;
    }
    
    self.effect.resolution = GLKVector2Make(_backingWidth, _backingHeight);
    self.effect.modelViewMatrix = GLKMatrix4Multiply(view, model);
    self.effect.projectionMatrix = projection;
}

#pragma mark - RZUpdateable

- (void)update:(NSTimeInterval)dt
{
    [super update:dt];

    if ( self.isDynamic || !self.textureLoaded ) {
        [self.viewTexture updateWithView:self.sourceView synchronous:NO];
        self.textureLoaded = YES;
    }
}

#pragma mark - RZRenderable

- (void)setupGL
{
    [super setupGL];

    [self rz_setEffect:self.effect];
    [self rz_createTexture];
}

- (void)bindGL
{
    [super bindGL];

    [self rz_congfigureEffect];
    [self.viewTexture bindGL];
}

- (void)teardownGL
{
    [super teardownGL];

    [self.effect teardownGL];
    [self.viewTexture teardownGL];
}

@end
