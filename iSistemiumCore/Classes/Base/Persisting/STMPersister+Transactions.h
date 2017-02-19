//
//  STMPersister+Transactions.h
//  iSisSales
//
//  Created by Alexander Levin on 18/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister.h"
#import "STMPersistingTransaction.h"

@interface STMPersister (Transactions)

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block;
- (NSArray *)readOnly:(NSArray * (^)(id <STMPersistingTransaction> transaction))block;


- (STMStorageType)storageForEntityName:(NSString *)entityName options:(NSDictionary*)options;
- (NSPredicate *)predicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options;
- (NSPredicate *)primaryKeyPredicateEntityName:(NSString *)entityName values:(NSArray <NSString *> *)values options:(NSDictionary *)options;

@end
