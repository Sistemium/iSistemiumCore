//
//  STMPersisterRunner.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisterRunner.h"
#import "STMPersisterTransactionCoordinator.h"

@implementation STMPersisterRunner

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block error:(NSError **)error {

    STMPersisterTransactionCoordinator *transactionCoordinator = [[STMPersisterTransactionCoordinator alloc] init];
    
    BOOL result = block(transactionCoordinator);
    
    if (result){
        [transactionCoordinator rollback];
    }else{
        [transactionCoordinator commit];
    }
    
}

- (NSArray *)readOnly:(NSArray * (^)(id<STMPersistingTransaction>))block {
    
    STMPersisterTransactionCoordinator *transactionCoordinator = [[STMPersisterTransactionCoordinator alloc] init];
    
    NSArray *result = block(transactionCoordinator);
    
    return result;
    
}

@end
