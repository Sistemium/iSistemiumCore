//
//  STMOperation.m
//  iSisSales
//
//  Created by Alexander Levin on 23/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMOperation.h"
#import "STMFunctions.h"

@implementation STMOperation {
    BOOL _executing;
    BOOL _finished;
    BOOL _asynchronous;
}

+ (instancetype)asynchronousOperation {
    return [[self alloc] initAsynchronous];
}

- (instancetype)initAsynchronous {
    self = [self init];
    _asynchronous = YES;
    return self;
}


- (BOOL)asynchronous {
    return _asynchronous;
}

- (void)start {
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    self.startedAt = [NSDate date];
    
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

- (void)finish {
    
    self.finishedIn = -[self.startedAt timeIntervalSinceNow];
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = NO;
    [self didChangeValueForKey:@"isExecuting"];
    
    [self willChangeValueForKey:@"isFinished"];
    _finished = YES;
    [self didChangeValueForKey:@"isFinished"];
    
}

- (NSString *)printableFinishedIn {
    return [STMFunctions printableTimeInterval:self.finishedIn];
}

@end
