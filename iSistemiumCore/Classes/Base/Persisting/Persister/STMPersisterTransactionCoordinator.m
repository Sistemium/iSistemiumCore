//
//  STMPersisterTransactionCoordinator.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 25/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersisterTransactionCoordinator.h"
#import "STMPersisting.h"
#import "STMPersister.h"
#import "STMFunctions.h"
#import "STMCoreSessionManager.h"
#import "STMCoreAuthController.h"

@interface STMPersisterTransactionCoordinator ()

@property (nonatomic, strong) NSDictionary <NSNumber *, id <STMAdapting>> *adapters;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, id <STMPersistingTransaction>> *transactions;
@property (nonatomic, strong) id <STMModelling, STMPersistingObserving> modellingDelegate;
@property BOOL readOnly;

@end

@implementation STMPersisterTransactionCoordinator



+ (instancetype)writableWithPersister:(id <STMModelling, STMPersistingObserving>)persister
                             adapters:(NSDictionary *)adapters {

    return [[self alloc] initWithPersister:persister adapters:adapters];

}

+ (instancetype)readOnlyWithPersister:(id <STMModelling, STMPersistingObserving>)persister
                            adapters:(NSDictionary *)adapters {

    return [[self alloc] initWithPersister:persister adapters:adapters readOnly:YES];

}

- (instancetype)initWithPersister:(id <STMModelling, STMPersistingObserving>)persister
                         adapters:(NSDictionary *)adapters {

    return [self initWithPersister:persister adapters:adapters readOnly:NO];

}

- (instancetype)initWithPersister:(id <STMModelling, STMPersistingObserving>)persister
                         adapters:(NSDictionary *)adapters
                         readOnly:(BOOL)readOnly {

    self = [self init];

    if (!self) {
        return nil;
    }

    self.readOnly = readOnly;

    self.modellingDelegate = persister;

    self.adapters = adapters;

    return self;

}

- (NSMutableDictionary <NSNumber *, id <STMPersistingTransaction>> *)transactions {
    if (!_transactions) {
        _transactions = @{}.mutableCopy;
    }

    return _transactions;
}

- (void)endTransactionWithSuccess:(BOOL)success {

    for (NSNumber *key in self.transactions.allKeys) {
        id <STMPersistingTransaction> transaction = self.transactions[key];
        [self.adapters[key] endTransaction:transaction withSuccess:success];
    }

    [self.transactions removeAllObjects];

}

#pragma mark - PersistingTransaction protocol

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {

    predicate = [self predicate:predicate withOptions:options];

    id <STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];

    return [transaction findAllSync:entityName predicate:predicate options:options error:error];

}


- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {

    id <STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];

    return [transaction mergeWithoutSave:entityName attributes:attributes options:options error:error];

}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {

    NSArray *objects = @[];

    if (!options[STMPersistingOptionRecordstatuses] || [options[STMPersistingOptionRecordstatuses] boolValue]) {
        objects = [self findAllSync:entityName predicate:predicate options:options error:error];
    }

    id <STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];

    NSUInteger count = [transaction destroyWithoutSave:entityName predicate:predicate options:options error:error];

    NSMutableArray *recordStatuses = [NSMutableArray array];

    NSString *recordStatusEntity = [STMFunctions addPrefixToEntityName:@"RecordStatus"];

    for (NSDictionary *object in objects) {

        NSDictionary *recordStatus = @{
                @"objectXid": object[STMPersistingKeyPrimary],
                @"name": [STMFunctions removePrefixFromEntityName:entityName],
                @"isRemoved": @YES,
        };

        recordStatus = [self mergeWithoutSave:recordStatusEntity attributes:recordStatus options:@{STMPersistingOptionRecordstatuses: @NO} error:error];

        if (recordStatus) {
            [recordStatuses addObject:recordStatus];
        }

    }

    if (recordStatuses.count) {
        // will crash if not async
        dispatch_async(self.dispatchQueue, ^{
            [self.modellingDelegate notifyObservingEntityName:recordStatusEntity ofUpdatedArray:recordStatuses options:options];
        });
    }

    return count;

}


- (NSDictionary *)updateWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {

    if (!attributes[STMPersistingKeyPrimary]) {
        [STMFunctions error:error withMessage:@"Update requires primary key"];
        return nil;
    }

    NSMutableDictionary *attributesToUpdate = attributes.mutableCopy;

    for (NSString *attributeName in attributesToUpdate.allKeys) {
        if (![options[STMPersistingOptionFieldstoUpdate] containsObject:attributeName]) {
            [attributesToUpdate removeObjectForKey:attributeName];
        }
    }

    attributesToUpdate[STMPersistingKeyPrimary] = attributes[STMPersistingKeyPrimary];

    if (!options[STMPersistingOptionSetTs] || [options[STMPersistingOptionSetTs] boolValue]) {
        attributesToUpdate[STMPersistingKeyVersion] = [STMFunctions stringFromNow];
    } else {
        [attributesToUpdate removeObjectForKey:STMPersistingKeyVersion];
    }

    id <STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];

    return [transaction updateWithoutSave:entityName attributes:attributesToUpdate.copy options:options error:error];

}

- (NSUInteger)count:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {

    predicate = [self predicate:predicate withOptions:options];

    id <STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];

    if ([STMFunctions isNull:transaction]) {
        return 0;
    }

    return [transaction count:entityName predicate:predicate options:options error:error];

}

#pragma mark - Private helpers

- (void)wrongEntityName:(NSString *)entityName error:(NSError **)error {
    NSString *message = [NSString stringWithFormat:@"'%@' is not a concrete entity name", entityName];
    [STMFunctions error:error withMessage:message];
}

- (STMStorageType)storageForEntityName:(NSString *)entityName options:(NSDictionary *)options {

    STMStorageType storeTo = [self.modellingDelegate storageForEntityName:entityName];

    if (options[STMPersistingOptionForceStorage]) {
        storeTo = [options[STMPersistingOptionForceStorage] integerValue];
    }

    return storeTo;
}

- (id <STMPersistingTransaction>)transactionForEntityName:(NSString *)entityName options:(NSDictionary *)options error:(NSError **)error {

    STMStorageType storageType = [self storageForEntityName:entityName options:options];

    id <STMPersistingTransaction> transaction = self.transactions[@(storageType)];

    if (!transaction && [self.adapters.allKeys containsObject:@(storageType)]) {
        transaction = [self.adapters[@(storageType)] beginTransactionReadOnly:self.readOnly];
        self.transactions[@(storageType)] = transaction;
    }

    if (!transaction) {

        [self wrongEntityName:entityName error:error];

    }

    return transaction;

}

- (NSPredicate *)predicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options {

    NSMutableArray *predicates = [NSMutableArray arrayWithObject:[self phantomPredicateForOptions:options]];

    if (predicate) [predicates addObject:predicate];

    return [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
}

- (NSPredicate *)phantomPredicateForOptions:(NSDictionary *)options {

    BOOL isFantom = [options[STMPersistingOptionFantoms] boolValue];
    return [NSPredicate predicateWithFormat:@"isFantom == %@", @(isFantom)];

}

@end
