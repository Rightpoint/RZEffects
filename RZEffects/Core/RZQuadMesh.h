//
//  RZQuadMesh.h
//
//  Created by Rob Visentin on 1/10/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZEffectsCommon.h"

OBJC_EXTERN NSInteger const kRZQuadMeshMaxSubdivisions;

@interface RZQuadMesh : NSObject <RZRenderable>

+ (instancetype)quad;
+ (instancetype)quadWithSubdivisionLevel:(NSInteger)subdivisons;

@end
