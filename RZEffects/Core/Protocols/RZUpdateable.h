//
//  RZUpdateable.h
//
//  Created by Rob Visentin on 3/6/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RZUpdateable <NSObject>

- (void)update:(NSTimeInterval)dt;

@end
