//
//  STMOperationQueue.m
//  iSisSales
//
//  Created by Alexander Levin on 23/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMOperationQueue.h"
#import "STMFunctions.h"

#define KEYPATH_IS_FINISHED @"isFinished"


@interface STMOperationQueue ()

@property (nonatomic,strong) NSDate *startedAt;
@property (nonatomic) NSTimeInterval finishedIn;

@property (atomic) NSUInteger iterationsCount;
@property (atomic) NSUInteger finishedOperationsCount;
@property (atomic) NSTimeInterval finishedOperationsDuration;

@end


@implementation STMOperationQueue


+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue {
    return [[self alloc] initWithDispatchQueue:dispatchQueue];
}


+ (instancetype)queueWithDispatchQueue:(dispatch_queue_t)dispatchQueue maxConcurrent:(NSUInteger)maxConcurrent {
    STMOperationQueue *queue = [self queueWithDispatchQueue:dispatchQueue];
    queue.maxConcurrentOperationCount = maxConcurrent;
    return queue;
}

- (instancetype)init {
    
    self = [super init];
    self.finishedIn = 0;
    self.iterationsCount = 0;
    self.finishedOperationsCount = 0;
    self.finishedOperationsDuration = 0;
    self.maxConcurrentOperationCount = STM_OPERATION_MAX_CONCURRENT_DEFAULT;
    
    return self;
    
}

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)dispatchQueue {

    self = [self init];
    
    if (dispatchQueue) self.underlyingQueue = dispatchQueue;
    
    return self;
    
}


- (void)addOperation:(STMOperation *)op {
    op.queue = self;
    [op addObserver:self forKeyPath:KEYPATH_IS_FINISHED options:NSKeyValueObservingOptionNew context:nil];
    [super addOperation:op];
}


- (NSString *)printableFinishedIn {
    return [STMFunctions printableTimeInterval:self.finishedIn];
}


- (NSString *)printableFinishedOperationsDuration {
    return [STMFunctions printableTimeInterval:self.finishedOperationsDuration];
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:KEYPATH_IS_FINISHED] && [object respondsToSelector:@selector(finishedIn)]) {
        
        self.finishedOperationsDuration += [object finishedIn];
        self.finishedOperationsCount ++;
        
        [object removeObserver:self forKeyPath:KEYPATH_IS_FINISHED];
        
        if (!self.operationCount) {
            self.finishedIn += -[self.startedAt timeIntervalSinceNow];
        }
        
    }
    
}


- (void)setSuspended:(BOOL)willBeSuspended {
    
    if (self.suspended && !willBeSuspended) {
        self.startedAt = [NSDate date];
        self.iterationsCount ++;
    }
    
    [super setSuspended:willBeSuspended];
    
}


@end

