//
//  RZXVertexObjectIndices.h
//  RZXSceneDemo
//
//  Created by John Stricker on 3/20/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/gltypes.h>

@interface RZXVertexObjectData : NSObject

@property (assign, nonatomic) GLuint vaoIndex;
@property (assign, nonatomic) GLuint vboIndex;
@property (assign, nonatomic) GLuint vioIndex;
@property (assign, nonatomic) GLuint vertexCount;

@end
