//
//  STMOperationQueue.h
//  iSisSales
//
//  Created by Alexander Levin on 23/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMOperation.h"

#define STM_OPERATION_MAX_CONCURRENT_DEFAULT 25

@interface STMOperationQueue : NSOperationQueue

@property (readonly) NSDate *startedAt;
@property (readonly) NSUInteger iterationsCount;

@property (readonly) NSTimeInterval finishedIn;
@property (readonly) NSTimeInterval finishedOperationsDuration;

@property (readonly) NSString *printableFinishedIn;
@property (readonly) NSString *printableFinishedOperationsDuration;

@property (readonly) NSUInteger finishedOperationsCount;

+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue;

+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue maxConcurrent:(NSUInteger)maxConcurrent;

@end
