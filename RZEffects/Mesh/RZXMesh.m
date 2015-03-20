//
//  RZXMesh.m
//  RZXSceneDemo
//
//  Created by John Stricker on 3/19/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZXMesh.h"

#import <OpenGLES/ES2/glext.h>

#import "RZXVertexObjectData.h"
#import "RZEffectContext.h"

static NSMutableDictionary *meshVertexObjectIdentifiers;
static RZEffectContext *effectContext;

@interface RZXMesh()

@property (copy, nonatomic)NSString *meshName;
@property (copy, nonatomic)NSString *meshFileName;

@property (strong, nonatomic)RZXVertexObjectData *vertexObjectData;

@end

@implementation RZXMesh

+ (instancetype) meshWithName:(NSString *)name meshFileName:(NSString *)meshFileName
{
    return [[self alloc] initWithName:name meshFileName:meshFileName];
}

#pragma mark - RZOpenGLObject

- (void)setupGL
{
    RZEffectContext *currentContext = [RZEffectContext currentContext];
    if ( currentContext != nil ) {
        RZXVertexObjectData *vod = [self loadCachedObjectDataForContext:currentContext];
        if ( vod == nil ) {
            self.vertexObjectData = [self generateVertexObjectDataForMeshWithFileName:self.meshFileName inContext:currentContext];
            [self cacheObjectDataForContext:currentContext];
        }
        else {
            self.vertexObjectData = vod;
        }
    }
}

- (void)bindGL
{
    [[RZEffectContext currentContext] bindVertexArray:self.vertexObjectData.vaoIndex];
}

- (void)teardownGL
{
    if ( self.vertexObjectData != nil && self.vertexObjectData.vaoIndex != 0 ) {
        GLuint vaoIndex = self.vertexObjectData.vaoIndex;
        GLuint vboIndex = self.vertexObjectData.vboIndex;
        GLuint vioIndex = self.vertexObjectData.vioIndex;
        glDeleteVertexArraysOES(1, &vaoIndex);
        glDeleteBuffers(1, &vboIndex);
        glDeleteBuffers(1, &vioIndex);
    }
}

#pragma mark - RZRenderable

- (void)render
{
    glDrawElements(GL_TRIANGLES, self.vertexObjectData.vertexCount, GL_UNSIGNED_INT, NULL);
}

#pragma mark - private methods

- (instancetype)initWithName:(NSString *)name meshFileName:(NSString *)meshFileName
{
    self = [super init];
    if ( self != nil ) {
        _meshName = name;
        _meshFileName = meshFileName;
    }
    return self;
}

- (RZXVertexObjectData *)loadCachedObjectDataForContext:(RZEffectContext *)context
{
    if ( meshVertexObjectIdentifiers == nil ) {
        meshVertexObjectIdentifiers = [[NSMutableDictionary alloc] init];
    }
    
    return meshVertexObjectIdentifiers[[self meshKeyForContext:context]];
}

- (void)cacheObjectDataForContext:(RZEffectContext *)context
{
    if ( meshVertexObjectIdentifiers == nil ) {
        meshVertexObjectIdentifiers = [[NSMutableDictionary alloc] init];
    }

    meshVertexObjectIdentifiers[[self meshKeyForContext:context]] = self.vertexObjectData;
}

- (NSString *)meshKeyForContext:(RZEffectContext *)context
{
    return [NSString stringWithFormat:@"%@%p",self.meshName,context];
}

- (RZXVertexObjectData *)generateVertexObjectDataForMeshWithFileName:(NSString *)fileName inContext:(RZEffectContext *)context
{
    NSString* filepathname = [[NSBundle mainBundle] pathForResource:fileName ofType:@"mesh"];
    
    if(!filepathname)
    {
        NSLog(@"UNABLE TO LOCATE MODEL DATA for %@",fileName);
        return nil;
    }
    
    FILE *meshFile = fopen([filepathname cStringUsingEncoding:NSASCIIStringEncoding], "r");
    
    GLushort indexCount;
    fread(&indexCount, sizeof(GLushort), 1, meshFile);
    
    GLushort *indexArray = (GLushort*)malloc(indexCount * sizeof(GLushort));
    fread(&indexArray, sizeof(GLushort), indexCount, meshFile);
    
    GLushort *uniqueVertexCount;
    fread(&uniqueVertexCount, sizeof(GLushort), 1, meshFile);
    
    int uniqueVertexArraySize = (int)uniqueVertexCount * 8 * sizeof(GLfloat);
    GLfloat *uniqueVertexArray = (GLfloat*)malloc(uniqueVertexArraySize);
    fread(&uniqueVertexArray, 1, uniqueVertexArraySize, meshFile);
    
    fclose(meshFile);

    GLuint vao, vbo, vio;
    
    glGenVertexArraysOES(1,&vao);
    glBindVertexArrayOES(vao);
    
    glGenBuffers(1, &vio);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vio);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLint)*indexCount, indexArray, GL_STATIC_DRAW);
    
    glGenBuffers(1,&vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, uniqueVertexArraySize,uniqueVertexArray, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 32, (char*)NULL + 0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 32, (char*)NULL + 12);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 32, (char*)NULL + 24);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    RZXVertexObjectData *obd = [[RZXVertexObjectData alloc] init];
    obd.vaoIndex = vao;
    obd.vboIndex = vbo;
    obd.vioIndex = vio;
    obd.vertexCount = indexCount;
    
    free(indexArray);
    free(uniqueVertexArray);
    
    return obd;
}

@end
