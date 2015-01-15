//
//  RZEffectView.m
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <OpenGLES/ES2/glext.h>

#import "RZEffectView.h"
#import "RZRenderLoop.h"
#import "RZViewTexture.h"
#import "RZQuadMesh.h"

@interface RZEffectView () {
    GLuint _fbo;
    GLuint _crb;
    GLuint _drb;
    
    GLint _backingWidth;
    GLint _backingHeight;
}

@property (strong, nonatomic) EAGLContext *context;
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
        
        [self _commonInit];
        [self _createTexture];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if ( self ) {
        _dynamic = NO;
        [self _commonInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self _createTexture];
}

- (void)dealloc
{
    if( [EAGLContext currentContext] == self.context ) {
        [EAGLContext setCurrentContext:nil];
    }
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat aspectRatio = (CGRectGetWidth(self.bounds) / CGRectGetWidth(self.bounds));
    self.effectCamera.aspectRatio = aspectRatio;
    
    GLKVector3 camTrans = GLKVector3Make(0.0f, 0.0f, -1.0f / tanf(self.effectCamera.fieldOfView / 2.0f));
    self.effectTransform.translation = GLKVector3Add(self.effectTransform.translation, camTrans);
}

#pragma mark - public methods

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if ( self.context != nil ) {
        [EAGLContext setCurrentContext:self.context];
        [self _updateBuffers];
    }
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    if ( self.context != nil ) {
        [EAGLContext setCurrentContext:self.context];
        [self _updateBuffers];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    
    if ( self.context != nil ) {
        [self _setClearColorWithColor:backgroundColor];
    }
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
    [EAGLContext setCurrentContext:self.context];
    
    [self _setEffect:effect];
}

- (void)setModel:(id<RZRenderable>)model
{
    [EAGLContext setCurrentContext:self.context];
    
    [self _setModel:model];
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

+ (EAGLContext *)bestContext
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    
    if ( context == nil ) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    
    return context;
}

- (void)_commonInit
{
    CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
    glLayer.contentsScale = [UIScreen mainScreen].scale;
    
    glLayer.drawableProperties = @{ kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8,
                                    kEAGLDrawablePropertyRetainedBacking : @(NO) };
    
    self.context = [[self class] bestContext];
    
    self.effectCamera = [RZCamera cameraWithFieldOfView:GLKMathDegreesToRadians(30.0f) aspectRatio:1.0f nearClipping:0.001f farClipping:10.0f];
    
    self.effectTransform = [RZTransform3D transform];
    
    if ( [EAGLContext setCurrentContext:self.context] ) {
        [self _updateBuffers];
        [self _setEffect:self.effect];
        
        self.renderLoop = [RZRenderLoop renderLoop];
        [self.renderLoop setUpdateTarget:self action:@selector(_update:)];
        [self.renderLoop setRenderTarget:self action:@selector(_render)];

        self.framesPerSecond = 60;
        
        [self _setClearColorWithColor:self.backgroundColor];
        
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
    }
}

- (void)_createBuffers
{
    glGenFramebuffers(1, &_fbo);
    glGenRenderbuffers(1, &_crb);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glBindRenderbuffer(GL_RENDERBUFFER, _crb);
    
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _crb);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    glGenRenderbuffers(1, &_drb);
    glBindRenderbuffer(GL_RENDERBUFFER, _drb);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, _backingWidth, _backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _drb);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _crb);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

- (void)_updateBuffers
{
    [self _destroyBuffers];
    
    if ( CGRectGetWidth(self.bounds) > 0.0f && CGRectGetHeight(self.bounds) > 0.0f ) {
        [self _createBuffers];
    }
    
    glViewport(0, 0, _backingWidth, _backingHeight);
}

- (void)_destroyBuffers
{
    glDeleteFramebuffers(1, &_fbo);
    glDeleteRenderbuffers(1, &_crb);
    glDeleteRenderbuffers(1, &_drb);
    
    _fbo = 0;
    _crb = 0;
    _drb = 0;
    
    _backingWidth = 0;
    _backingHeight = 0;
}

- (void)_createTexture
{
    if ( self.sourceView != nil ) {
        [EAGLContext setCurrentContext:self.context];
        [self _setViewTexture:[RZViewTexture textureWithSize:self.sourceView.bounds.size]];
    }
}

- (void)_setEffect:(RZEffect *)effect
{
    [_effect teardownGL];
    
    [effect setupGL];
    
    if ( [effect link] ) {
        if ( self.sourceView != nil ) {
            [self _setModel:[RZQuadMesh quadWithSubdivisionLevel:effect.preferredLevelOfDetail]];
        }
        
        _effect = effect;
    }
    else {
        [self _setModel:nil];
        _effect = nil;
    }
}

- (void)_setViewTexture:(RZViewTexture *)viewTexture
{
    [_viewTexture teardownGL];
    _viewTexture = viewTexture;
    [_viewTexture setupGL];
}

- (void)_setModel:(id<RZRenderable>)model
{
    [_model teardownGL];
    _model = model;
    [_model setupGL];
}

- (void)_setClearColorWithColor:(UIColor *)color
{
    [EAGLContext setCurrentContext:self.context];
    
    if ( color != nil ) {
        CGColorRef cgColor = color.CGColor;
        const CGFloat *comps = CGColorGetComponents(cgColor);
        
        size_t numComps = CGColorGetNumberOfComponents(cgColor);
        CGFloat r, g, b, a;
        
        if ( numComps == 2 ) {
            const CGFloat *comps = CGColorGetComponents(cgColor);
            r = b = g = comps[0];
            a = comps[1];
        }
        else if ( numComps == 4 ) {
            r = comps[0];
            g = comps[1];
            b = comps[2];
            a = comps[3];
        }
        
        glClearColor(r, g, b, a);
    }
    else {
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    }
}

- (void)_update:(CFTimeInterval)dt
{
    if ( self.isDynamic || !self.textureLoaded ) {
        [self.viewTexture updateWithView:self.sourceView synchronous:NO];
        self.textureLoaded = YES;
    }
}

- (void)_render
{
    [EAGLContext setCurrentContext:self.context];
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE0);
    [self.viewTexture bindGL];
    
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
    
    self.effect.modelViewMatrix = GLKMatrix4Multiply(view, model);
    self.effect.projectionMatrix = projection;

    [self.effect prepareToDraw];
    
    [self display];
    
    const GLenum discards[]  = {GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT};
    glDiscardFramebufferEXT(GL_FRAMEBUFFER, 2, discards);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _crb);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

@end
