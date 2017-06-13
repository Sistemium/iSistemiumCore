//
//  STMPersisterRunner.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisterRunner.h"
#import "STMPersisterTransactionCoordinator.h"

@interface STMPersisterRunner()

@property (nonatomic, strong) STMPersisterTransactionCoordinator *transactionCoordinator;
@property (nonatomic, strong) STMPersisterTransactionCoordinator *readOnlyTransactionCoordinator;

@end

@implementation STMPersisterRunner

- (instancetype)initWithPersister:(id <STMModelling,STMPersistingObserving>)persister adapters:(NSDictionary *)adapters{
    
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    self.transactionCoordinator = [[STMPersisterTransactionCoordinator alloc] initWithPersister:persister adapters:(NSDictionary *)adapters];
    self.readOnlyTransactionCoordinator = [[STMPersisterTransactionCoordinator alloc] initWithPersister:persister adapters:(NSDictionary *)adapters readOny:YES];
    self.maxConcurrentOperationCount = 1;
    
    return self;
    
}

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block error:(NSError **)error {
    
    [self addOperationWithBlock:^{
        
        BOOL result = block(self.transactionCoordinator);
        
        [self.transactionCoordinator endTransactionWithSuccess:result];
        
    }];
    
    [self waitUntilAllOperationsAreFinished];

}

- (NSArray *)readOnly:(NSArray * (^)(id<STMPersistingTransaction>))block {
    
    __block NSArray *result;

    [self addOperationWithBlock:^{
    
        result = block(self.readOnlyTransactionCoordinator);
        
        [self.readOnlyTransactionCoordinator endTransactionWithSuccess:YES];

    }];

    [self waitUntilAllOperationsAreFinished];

    return result;
}

@end

