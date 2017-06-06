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
#import "STMPersister+Transactions.h"

@protocol Adapting

- (id<STMPersistingTransaction>)beginTransaction;
- (void)commit;
- (void)rollback;

@end

@interface STMPersisterTransactionCoordinator()

@property (nonatomic, strong) NSDictionary<NSNumber *, id<Adapting>>* adapters;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<STMPersistingTransaction>>* transactions;
@property (nonatomic, strong) id <STMModelling> modellingDelegate;
@property BOOL readOnly;

@end

@implementation STMPersisterTransactionCoordinator

- (instancetype)initWithModellingDelegate:(id <STMModelling>)modellingDelegate{

    return [self initWithModellingDelegate:modellingDelegate readOny:NO];
    
}

- (instancetype)initWithModellingDelegate:(id <STMModelling>)modellingDelegate readOny:(BOOL) readOnly{
    
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    self.readOnly = readOnly;
    
    _modellingDelegate = modellingDelegate;
    
    return self;
    
    
}

- (NSDictionary<NSNumber *, id<Adapting>>*)adapters{
    if (!_adapters){
        _adapters = @{
                      
                      };
    }
    
    return _adapters;
}

- (NSMutableDictionary<NSNumber *, id<STMPersistingTransaction>>*)transactions{
    if (!_transactions){
        _transactions = @{}.mutableCopy;
    }
    
    return _transactions;
}

- (void)endTransactionWithSuccess:(BOOL *)success{
    
    [self.transactions removeAllObjects];

    for (id<Adapting> adapter in self.adapters.allValues){
        if (success){
            [adapter commit];
        }else{
            [adapter rollback];
        }
    }
    
}

#pragma mark - PersistingTransaction protocol

- (id <STMModelling>)modellingDelegate {
    return _modellingDelegate;
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    id<STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];
    
    return [transaction findAllSync:entityName predicate:predicate options:options error:error];
    
}


- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    id<STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];
    
    return [transaction mergeWithoutSave:entityName attributes:attributes options:options error:error];
    
}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    NSArray* objects = @[];
    
    if (!options[STMPersistingOptionRecordstatuses] || [options[STMPersistingOptionRecordstatuses] boolValue]){
        objects = [self findAllSync:entityName predicate:predicate options:options error:error];
    }
    
    id<STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];
    
    NSUInteger count = [transaction destroyWithoutSave:entityName predicate:predicate options:options error:error];
    
    NSMutableArray *recordStatuses = [NSMutableArray array];
    
    NSString *recordStatusEntity = [STMFunctions addPrefixToEntityName:@"RecordStatus"];
    
    for (NSDictionary *object in objects){
        
        NSDictionary *recordStatus = @{
                                       @"objectXid":object[STMPersistingKeyPrimary],
                                       @"name":[STMFunctions removePrefixFromEntityName:entityName],
                                       @"isRemoved": @YES,
                                       };
        
        recordStatus = [self mergeWithoutSave:recordStatusEntity attributes:recordStatus options:@{STMPersistingOptionRecordstatuses:@NO} error:error];
        
        if (recordStatus) {
            [recordStatuses addObject:recordStatus];
        }
        
    }
    
#warning needs to be moved somewhere
    STMPersister *persister = (STMPersister *) self.modellingDelegate;
    
    if (recordStatuses.count) {
        // will crash if not async
        dispatch_async(persister.dispatchQueue, ^{
            [persister notifyObservingEntityName:recordStatusEntity ofUpdatedArray:recordStatuses options:options];
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
    
    for (NSString *attributeName in attributesToUpdate.allKeys){
        if (![options[STMPersistingOptionFieldstoUpdate] containsObject:attributeName]) {
            [attributesToUpdate removeObjectForKey:attributeName];
        }
    }
    
    attributesToUpdate[STMPersistingKeyPrimary] = attributes[STMPersistingKeyPrimary];
    
    if (!options[STMPersistingOptionSetTs] || [options[STMPersistingOptionSetTs] boolValue]){
        attributesToUpdate[STMPersistingKeyVersion] = [STMFunctions stringFromNow];
    } else {
        [attributesToUpdate removeObjectForKey:STMPersistingKeyVersion];
    }
    
    id<STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];
    
    return [transaction updateWithoutSave:entityName attributes:attributes options:options error:error];
    
}

- (NSUInteger)count:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    id<STMPersistingTransaction> transaction = [self transactionForEntityName:entityName options:options error:error];
    
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

- (id<STMPersistingTransaction>)transactionForEntityName:(NSString *)entityName options:(NSDictionary *)options error:(NSError **)error {
    
    STMStorageType storageType = [self storageForEntityName:entityName options:options];
    
    if (![self.transactions.allKeys containsObject:@(storageType)] && [self.adapters.allKeys containsObject:@(storageType)]){
        self.transactions[@(storageType)] = [self.adapters[@(storageType)] beginTransaction];
    }
    
    if (![self.transactions.allKeys containsObject:@(storageType)]){
        
        [self wrongEntityName:entityName error:error];
        return [self.transactions objectForKey:@(storageType)];
        
    }
    
    return nil;
    
}

@end
