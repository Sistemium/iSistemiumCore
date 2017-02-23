//
//  STMOperationQueue.h
//  iSisSales
//
//  Created by Alexander Levin on 23/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMOperation.h"

@interface STMOperationQueue : NSOperationQueue

+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue;
+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue maxConcurrent:(NSUInteger)maxConcurrent;

@end
