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

@interface STMPersisterTransactionCoordinator()

@property (nonatomic, strong) NSDictionary<NSNumber *, id<STMPersistingTransaction>>* adapters;
@property (nonatomic, strong) id <STMModelling> modellingDelegate;

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
    
    _modellingDelegate = modellingDelegate;
    
    return self;
    
    
}

- (NSDictionary<NSNumber *, id<STMPersistingTransaction>>*)adapters{
    if (!_adapters){
        _adapters = @{
                      
                      };
    }
    
    return _adapters;
}

- (void)commit{

    
    
}

- (void)rollback{

    
    
}

- (STMStorageType)storageForEntityName:(NSString *)entityName options:(NSDictionary *)options {
    
    STMStorageType storeTo = [self.modellingDelegate storageForEntityName:entityName];
    
    if (options[STMPersistingOptionForceStorage]) {
        storeTo = [options[STMPersistingOptionForceStorage] integerValue];
    }
    
    return storeTo;
}

#pragma mark - PersistingTransaction protocol

- (id <STMModelling>)modellingDelegate {
    return _modellingDelegate;
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    STMStorageType storageType = [self storageForEntityName:entityName options:options];
    
    if ([self.adapters.allKeys containsObject:@(storageType)]){
        
        return [[self.adapters objectForKey:@(storageType)] findAllSync:entityName predicate:predicate options:options error:error];
        
    }else{
    
        [self wrongEntityName:entityName error:error];
        return nil;

    }
    
}


- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    STMStorageType storageType = [self storageForEntityName:entityName options:options];
    
    if ([self.adapters.allKeys containsObject:@(storageType)]){
        
        return [[self.adapters objectForKey:@(storageType)] mergeWithoutSave:entityName attributes:attributes options:options error:error];
        
    }else{
        
        [self wrongEntityName:entityName error:error];
        return nil;
        
    }
    
}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    STMStorageType storageType = [self storageForEntityName:entityName options:options];
    
    if ([self.adapters.allKeys containsObject:@(storageType)]){
        
        return [[self.adapters objectForKey:@(storageType)] destroyWithoutSave:entityName predicate:predicate options:options error:error];
        
    }else{
        
        [self wrongEntityName:entityName error:error];
        return 0;
        
    }
    
}


- (NSDictionary *)updateWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    STMStorageType storageType = [self storageForEntityName:entityName options:options];
    
    if ([self.adapters.allKeys containsObject:@(storageType)]){
        
        return [[self.adapters objectForKey:@(storageType)] updateWithoutSave:entityName attributes:attributes options:options error:error];
        
    }else{
        
        [self wrongEntityName:entityName error:error];
        return nil;
        
    }
    
}

- (NSUInteger)count:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    STMStorageType storageType = [self storageForEntityName:entityName options:options];
    
    if ([self.adapters.allKeys containsObject:@(storageType)]){
        
        return [[self.adapters objectForKey:@(storageType)] count:entityName predicate:predicate options:options error:error];
        
    }else{
        
        [self wrongEntityName:entityName error:error];
        return 0;
        
    }
    
}

#pragma mark - Private helpers

- (void)wrongEntityName:(NSString *)entityName error:(NSError **)error {
    NSString *message = [NSString stringWithFormat:@"'%@' is not a concrete entity name", entityName];
    [STMFunctions error:error withMessage:message];
}

@end
