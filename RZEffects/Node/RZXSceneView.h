//
//  RZXSceneView.h
//  RZXSceneDemo
//
//  Created by John Stricker on 4/17/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "RZGLView.h"

@class RZXScene;

@interface RZXSceneView : RZGLView

@property (strong, nonatomic) RZXScene *scene;

@end
