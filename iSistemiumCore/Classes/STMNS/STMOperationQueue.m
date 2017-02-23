//
//  STMOperationQueue.m
//  iSisSales
//
//  Created by Alexander Levin on 23/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMOperationQueue.h"

@implementation STMOperationQueue

+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue {
    return [[self alloc] initWithDispatchQueue:dispatchQueue];
}

+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue maxConcurrent:(NSUInteger)maxConcurrent {
    STMOperationQueue *queue = [self queueWithDispatchQueue:dispatchQueue];
    queue.maxConcurrentOperationCount = maxConcurrent;
    return queue;
}

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)dispatchQueue {

    self = [self init];
    
    self.maxConcurrentOperationCount = STM_OPERATION_MAX_CONCURRENT_DEFAULT;
    if (dispatchQueue) self.underlyingQueue = dispatchQueue;
    
    return self;
    
}

- (void)addOperation:(STMOperation *)op {
    op.queue = self;
    [super addOperation:op];
}

@end

