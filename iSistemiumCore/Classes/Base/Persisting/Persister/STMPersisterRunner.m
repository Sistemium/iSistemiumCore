//
//  STMPersisterRunner.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisterRunner.h"
#import "STMPersisterTransactionCoordinator.h"
#import "STMAdapting.h"

@interface STMPersisterRunner ()

@property (nonatomic, strong) id <STMModelling, STMPersistingObserving> persister;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;


@end

@implementation STMPersisterRunner

@synthesize adapters;

- (instancetype)initWithPersister:(id <STMModelling, STMPersistingObserving>)persister adapters:(NSDictionary *)adapters {

    self = [self init];

    if (!self) {
        return nil;
    }

    self.adapters = adapters;
    self.persister = persister;
    self.dispatchQueue = dispatch_queue_create("com.sistemium.STMRunnerDispatchQueue", DISPATCH_QUEUE_SERIAL);

    return self;

}

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block {

    STMPersisterTransactionCoordinator *coordinator =
            [[STMPersisterTransactionCoordinator alloc] initWithPersister:self.persister adapters:self.adapters];

    coordinator.dispatchQueue = self.dispatchQueue;

    BOOL result = block(coordinator);

    [coordinator endTransactionWithSuccess:result];

}

- (NSArray *)readOnly:(NSArray *(^)(id <STMPersistingTransaction>))block {

    NSArray *result;

    STMPersisterTransactionCoordinator *coordinator =
            [[STMPersisterTransactionCoordinator alloc] initWithPersister:self.persister adapters:self.adapters readOnly:YES];

    coordinator.dispatchQueue = self.dispatchQueue;

    result = block(coordinator);

    [coordinator endTransactionWithSuccess:YES];

    return result;
}

@end

