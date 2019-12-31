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

    if (self.isCancelled) {
        NSLog(@"operation cancelled");
        return [self finish];
    }

    self.startedAt = [NSDate date];

    [self willChangeValueForKey:@"isExecuting"];

    _executing = YES;

    [self didChangeValueForKey:@"isExecuting"];

    [self main];

}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

- (void)finish {

    if (self.startedAt) {
        self.finishedIn = -[self.startedAt timeIntervalSinceNow];
    }

    if (!_finished) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = YES;
        [self didChangeValueForKey:@"isFinished"];
    }

    if (_executing) {
        [self willChangeValueForKey:@"isExecuting"];
        _executing = NO;
        [self didChangeValueForKey:@"isExecuting"];
    }

}

- (NSString *)printableFinishedIn {
    return [STMFunctions printableTimeInterval:self.finishedIn];
}

- (void)cancel {
    [self finish];
    [super cancel];
}

@end
