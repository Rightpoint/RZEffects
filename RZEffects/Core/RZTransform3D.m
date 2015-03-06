//
//  RZTransform3D.m
//
//  Created by Rob Visentin on 1/11/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZTransform3D.h"

@interface RZTransform3D () {
    GLKMatrix4 *_cachedModelMatrix;
}

@end

@implementation RZTransform3D

#pragma mark - lifecycle

+ (instancetype)transform
{
    return [[[self class] alloc] init];
}

+ (instancetype)transformWithTranslation:(GLKVector3)trans rotation:(GLKQuaternion)rot scale:(GLKVector3)scale
{
    return [[[self class] alloc] initWithTranslation:trans rotation:rot scale:scale];
}

- (instancetype)init
{
    return [self initWithTranslation:GLKVector3Make(0.0f, 0.0f, 0.0f) rotation:GLKQuaternionIdentity scale:GLKVector3Make(1.0f, 1.0f, 1.0f)];
}

- (void)dealloc
{
    [self rz_invalidateModelMatrixCache];
}

#pragma mark - public methods

- (BOOL)isEqual:(id)object
{
    BOOL equal = NO;

    if ( self == object ) {
        equal = YES;
    }
    else if ( [object isKindOfClass:[RZTransform3D class]] ) {
        GLKMatrix4 otherModelMatrix = [(RZTransform3D *)object modelMatrix];

        if ( memcmp(self.modelMatrix.m, otherModelMatrix.m, sizeof(otherModelMatrix.m)) == 0 ) {
            equal = YES;
        }
    }

    return equal;
}

- (GLKMatrix4)modelMatrix
{
    @synchronized (self) {
        if ( _cachedModelMatrix == NULL ) {
            GLKMatrix4 scale = GLKMatrix4MakeScale(_scale.x, _scale.y, _scale.z);
            GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(_rotation);
            
            GLKMatrix4 mat = GLKMatrix4Multiply(rotation, scale);
            
            mat.m[12] += _translation.x;
            mat.m[13] += _translation.y;
            mat.m[14] += _translation.z;
            
            _cachedModelMatrix = (GLKMatrix4 *)malloc(sizeof(GLKMatrix4));
            memcpy(_cachedModelMatrix, &mat, sizeof(GLKMatrix4));
        }
        
        return *_cachedModelMatrix;
    }
}

- (void)setTranslation:(GLKVector3)translation
{
    _translation = translation;
    [self rz_invalidateModelMatrixCache];
}

- (void)setScale:(GLKVector3)scale
{
    _scale = scale;
    [self rz_invalidateModelMatrixCache];
}

- (void)setRotation:(GLKQuaternion)rotation
{
    _rotation = rotation;
    [self rz_invalidateModelMatrixCache];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    RZTransform3D *copy = [[[self class] alloc] init];
    
    copy.translation = _translation;
    copy.rotation = _rotation;
    copy.scale = _scale;
    
    return copy;
}

#pragma mark - private methods

- (instancetype)initWithTranslation:(GLKVector3)trans rotation:(GLKQuaternion)rot scale:(GLKVector3)scale
{
    self = [super init];
    if ( self ) {
        _translation = trans;
        _rotation = rot;
        _scale = scale;
        
        _cachedModelMatrix = NULL;
    }
    return self;
}

- (void)rz_invalidateModelMatrixCache
{
    @synchronized (self) {
        free(_cachedModelMatrix);
        _cachedModelMatrix = NULL;
    }
}

@end
