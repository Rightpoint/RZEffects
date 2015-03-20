//
//  RZXMesh.h
//  RZXSceneDemo
//
//  Created by John Stricker on 3/19/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RZEffectsCommon.h"

@interface RZXMesh : NSObject<RZRenderable>

+ (instancetype)meshWithName:(NSString *)name meshFileName:(NSString *)meshFileName;

@end
