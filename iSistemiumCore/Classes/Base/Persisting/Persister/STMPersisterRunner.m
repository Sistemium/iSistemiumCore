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

@interface STMPersisterRunner()

@property (nonatomic, strong) NSDictionary<NSNumber *, id<STMAdapting>>* adapters;
@property (nonatomic, strong) id <STMModelling,STMPersistingObserving> persister;

@end

@implementation STMPersisterRunner

- (instancetype)initWithPersister:(id <STMModelling,STMPersistingObserving>)persister adapters:(NSDictionary *)adapters{
    
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    self.adapters = adapters;
    self.persister = persister;
    
    return self;
    
}

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block {
    
    STMPersisterTransactionCoordinator *transactionCoordinator = [[STMPersisterTransactionCoordinator alloc] initWithPersister:self.persister adapters:(NSDictionary *)self.adapters];
    
    BOOL result = block(transactionCoordinator);
    
    [transactionCoordinator endTransactionWithSuccess:result];

}

- (NSArray *)readOnly:(NSArray * (^)(id<STMPersistingTransaction>))block {
    
    __block NSArray *result;
        
    STMPersisterTransactionCoordinator *readOnlyTransactionCoordinator = [[STMPersisterTransactionCoordinator alloc] initWithPersister:self.persister adapters:(NSDictionary *)self.adapters readOny:YES];

    result = block(readOnlyTransactionCoordinator);
    
    [readOnlyTransactionCoordinator endTransactionWithSuccess:YES];

    return result;
}

@end

