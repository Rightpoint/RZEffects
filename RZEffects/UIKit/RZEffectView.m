//
//  RZEffectView.m
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/glext.h>

#import "RZEffectView.h"
#import "RZEffectContext.h"
#import "RZRenderLoop.h"
#import "RZViewTexture.h"
#import "RZQuadMesh.h"

#import "RZBlurEffect.h"

static const NSInteger kRZEffectViewDefaultFPS = 30;

static const GLenum s_GLDiscards[]  = {GL_DEPTH_ATTACHMENT, GL_COLOR_ATTACHMENT0};

#define RZ_EFFECT_AUX_TEXTURES (RZ_EFFECT_MAX_DOWNSAMPLE + 1)

@interface RZEffectView () {
    GLuint _fbos[2];
    GLuint _crb;
    GLuint _drbs[2];
    
    GLuint _auxTex[2][RZ_EFFECT_AUX_TEXTURES];
    
    GLint _backingWidth;
    GLint _backingHeight;
}

@property (strong, nonatomic) RZEffectContext *context;

@property (strong, nonatomic) RZRenderLoop *renderLoop;

@property (strong, nonatomic) IBOutlet UIView *sourceView;
@property (strong, nonatomic) RZViewTexture *viewTexture;

@property (assign, nonatomic) BOOL textureLoaded;

@end

@implementation RZEffectView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark - lifecycle

- (instancetype)initWithSourceView:(UIView *)view effect:(RZEffect *)effect dynamicContent:(BOOL)dynamic
{
    self = [super initWithFrame:view.bounds];
    if ( self ) {
        _sourceView = view;
        _effect = effect;
        _dynamic = dynamic;
        
        [self rz_commonInit];
        [self rz_createTexture];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if ( self ) {
        _dynamic = NO;
        [self rz_commonInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self rz_createTexture];
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if ( newSuperview == nil ) {
        [self.renderLoop stop];
    }
}

- (void)didMoveToSuperview
{
    if ( self.superview != nil && !self.isPaused ) {
        [self.renderLoop run];
    }
}

#pragma mark - public methods

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];

    [self.context runBlock:^(RZEffectContext *context){
        [self rz_updateBuffersWithSize:frame.size];
    }];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    [self.context runBlock:^(RZEffectContext *context){
        [self rz_updateBuffersWithSize:bounds.size];
    }];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];

    [self.context runBlock:^(RZEffectContext *context){
        context.clearColor = backgroundColor.CGColor;
    } wait:NO];
}

- (void)setPaused:(BOOL)paused
{
    if ( paused != _paused ) {
        if ( paused ) {
            [self.renderLoop run];
        }
        else {
            [self.renderLoop stop];
        }
        
        _paused = paused;
    }    
}

- (void)setFramesPerSecond:(NSInteger)framesPerSecond
{
    _framesPerSecond = framesPerSecond;
    self.renderLoop.preferredFPS = framesPerSecond;
}

- (void)setEffect:(RZEffect *)effect
{
    [self.context runBlock:^(RZEffectContext *context){
        [self rz_setEffect:effect];
    }];
}

- (void)setModel:(id<RZRenderable>)model
{
    [self.context runBlock:^(RZEffectContext *context){
        [self rz_setModel:model];
    }];
}

- (void)setNeedsDisplay
{
    // empty implementation
}

- (void)display
{
    [self.model render];
}

#pragma mark - private methods

- (void)rz_commonInit
{
    CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
    glLayer.contentsScale = [UIScreen mainScreen].scale;
    
    glLayer.drawableProperties = @{ kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8,
                                    kEAGLDrawablePropertyRetainedBacking : @(NO) };
    
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.userInteractionEnabled = NO;

    self.effectCamera = [RZCamera cameraWithFieldOfView:GLKMathDegreesToRadians(30.0f) aspectRatio:1.0f nearClipping:0.001f farClipping:10.0f];
    
    self.effectTransform = [RZTransform3D transform];

    self.context = [RZEffectContext defaultContext];

    [self.context runBlock:^(RZEffectContext *context){
        [self rz_updateBuffersWithSize:self.bounds.size];
        [self rz_setEffect:self.effect];

        self.renderLoop = [RZRenderLoop renderLoop];
        [self.renderLoop setUpdateTarget:self action:@selector(rz_update:)];
        [self.renderLoop setRenderTarget:self action:@selector(rz_render)];

        self.framesPerSecond = kRZEffectViewDefaultFPS;

        context.clearColor = self.backgroundColor.CGColor;

        context.depthTestEnabled = YES;
        context.cullFace = GL_BACK;
    }];
}

- (void)rz_createBuffers
{
    [self.context runBlock:^(RZEffectContext *context) {
        glGenFramebuffers(2, _fbos);
        glGenRenderbuffers(1, &_crb);

        glBindFramebuffer(GL_FRAMEBUFFER, _fbos[0]);
        glBindRenderbuffer(GL_RENDERBUFFER, _crb);

        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];

        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);

        glGenRenderbuffers(2, _drbs);
        glBindRenderbuffer(GL_RENDERBUFFER, _drbs[0]);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, _backingWidth, _backingHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _drbs[0]);

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
    }];
}

- (void)rz_updateBuffersWithSize:(CGSize)size
{
    [self rz_destroyBuffers];
    
    if ( size.width > 0.0f && size.height > 0.0f ) {
        [self rz_createBuffers];
        
        CGFloat aspectRatio = (CGRectGetWidth(self.bounds) / CGRectGetWidth(self.bounds));
        self.effectCamera.aspectRatio = aspectRatio;
        
        GLKVector3 camTrans = GLKVector3Make(0.0f, 0.0f, -1.0f / tanf(self.effectCamera.fieldOfView / 2.0f));
        self.effectTransform.translation = GLKVector3Add(self.effectTransform.translation, camTrans);
    }
}

- (void)rz_destroyBuffers
{
    if ( _fbos[0] != 0 ) {
        glDeleteFramebuffers(2, _fbos);
        glDeleteRenderbuffers(1, &_crb);
        glDeleteRenderbuffers(2, _drbs);
        glDeleteTextures(2 * RZ_EFFECT_AUX_TEXTURES, _auxTex[0]);
    }
    
    memset(_fbos, 0, 2 * sizeof(GLuint));
    _crb = 0;
    memset(_drbs, 0, 2 * sizeof(GLuint));
    memset(_auxTex, 0, 2 * RZ_EFFECT_AUX_TEXTURES * sizeof(GLuint));
    
    _backingWidth = 0;
    _backingHeight = 0;
}

- (void)rz_createTexture
{
    if ( self.sourceView != nil ) {
        [self.context runBlock:^(RZEffectContext *context){
            [self rz_setViewTexture:[RZViewTexture textureWithSize:self.sourceView.bounds.size]];
        }];
    }
}

- (void)rz_setEffect:(RZEffect *)effect
{
//    [_effect teardownGL];

    if ( !effect.isLinked ) {
        [effect setupGL];
    }

    if ( effect.isLinked || [effect link] ) {
        if ( self.sourceView != nil ) {
            [self rz_setModel:[RZQuadMesh quadWithSubdivisionLevel:effect.preferredLevelOfDetail]];
        }
        
        _effect = effect;
    }
    else {
        [self rz_setModel:nil];
        _effect = nil;
    }
}

- (void)rz_setViewTexture:(RZViewTexture *)viewTexture
{
    [_viewTexture teardownGL];
    _viewTexture = viewTexture;
    [_viewTexture setupGL];
}

- (void)rz_setModel:(id<RZRenderable>)model
{
    [_model teardownGL];
    _model = model;
    [_model setupGL];
}

- (void)rz_update:(CFTimeInterval)dt
{
    if ( self.isDynamic || !self.textureLoaded ) {
#warning Calling drawViewHierarchyInRect with synchronous=NO can cause a crash in this particular example. Set synchronous=YES to avoid the crash.
        [self.viewTexture updateWithView:self.sourceView synchronous:NO];
        self.textureLoaded = YES;
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

- (void)rz_render
{
    [self.context runBlock:^(RZEffectContext *context){
        context.activeTexture = GL_TEXTURE0;
        
        [self.viewTexture bindGL];

        [self rz_congfigureEffect];

        int fbo = 0;

        GLuint downsample = self.effect.downsampleLevel;
        GLint denom = pow(2.0, downsample);

        while ( [self.effect prepareToDraw] ) {
            context.viewport = CGRectMake(0.0f, 0.0f, _backingWidth/denom, _backingHeight/denom);
            glBindFramebuffer(GL_FRAMEBUFFER, _fbos[fbo]);

            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _auxTex[fbo][downsample], 0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            [self display];

            glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, s_GLDiscards);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 0, 0);
            glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, &s_GLDiscards[1]);

            glBindTexture(GL_TEXTURE_2D, _auxTex[fbo][downsample]);
            fbo = 1 - fbo;

            downsample = self.effect.downsampleLevel;
            denom = pow(2.0, downsample);
        };

//        glFinish();

        // TODO: what if the last effect has lower downsample?

        context.viewport = CGRectMake(0.0f, 0.0f, _backingWidth, _backingHeight);

        glBindFramebuffer(GL_FRAMEBUFFER, _fbos[fbo]);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _crb);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        [self display];

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

@end
