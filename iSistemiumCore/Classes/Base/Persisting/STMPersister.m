//
//  STMPersister.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMConstants.h"
#import "STMFunctions.h"
#import "STMEntityController.h"
#import "STMSettingsController.h"

#import "STMPersister.h"
#import "STMPersister+CoreData.h"
#import "STMPersister+Private.h"
#import "STMPersister+Transactions.h"

#import "STMModeller+Interceptable.h"

@implementation STMPersister

+ (instancetype)persisterWithModelName:(NSString *)modelName uid:(NSString *)uid iSisDB:(NSString *)iSisDB completionHandler:(void (^)(BOOL success))completionHandler {

    STMPersister *persister = [[[STMPersister alloc] init] initWithModelName:modelName];
    
    NSString *fmdbFileName = [NSString stringWithFormat:@"%@-%@.db", @"fmdb", iSisDB?iSisDB:uid];
    
    persister.fmdb = [[STMFmdb alloc] initWithModelling:persister fileName:fmdbFileName];
    persister.document = [STMDocument documentWithUID:uid
                                               iSisDB:iSisDB
                                        dataModelName:modelName];
    
    // TODO: call completionHandler after document is ready to rid off documentReady subscriptions
    if (completionHandler) completionHandler(YES);

    return persister;
    
}


- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate *)predicate
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    return [super observeEntity:[STMFunctions addPrefixToEntityName:entityName]
                      predicate:predicate
                       callback:callback];
}

#pragma mark - Private methods

- (void)wrongEntityName:(NSString *)entityName error:(NSError **)error {
    NSString *message = [NSString stringWithFormat:@"'%@' is not a concrete entity name", entityName];
    [STMFunctions error:error withMessage:message];
}

#pragma mark - STMPersistingSync

- (NSUInteger)countSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    predicate = [self predicate:predicate withOptions:options];
    
    switch ([self storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:{
            
            if (![self.fmdb hasTable:entityName]) {
                [STMFunctions error:error
                        withMessage:[NSString stringWithFormat:@"No table for entity %@", entityName]];
                return 0;
            }
            return [self.fmdb count:entityName withPredicate:predicate];
        }
        case STMStorageTypeCoreData: {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
            request.predicate = predicate;
            return [self.document.managedObjectContext countForFetchRequest:request
                                                                      error:error];
            break;
        }
        default:
            [self wrongEntityName:entityName error:error];
            return 0;
    }
    
}

- (NSDictionary *)findSync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate *pkPredicate = [self primaryKeyPredicateEntityName:entityName values:@[identifier] options:options];
    NSPredicate *notFantom = [NSPredicate predicateWithFormat:@"isFantom == 0"];
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[pkPredicate, notFantom]];
    
    NSArray *results = [self findAllSync:entityName predicate:predicate options:options error:error];
    
    if (results.count) {
        return results.firstObject;
    }
    
    return nil;
    
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger pageSize = [options[STMPersistingOptionPageSize] integerValue];
    NSUInteger offset = [options[@"startPage"] integerValue];
    if (offset) {
        offset -= 1;
        offset *= pageSize;
    }
    NSString *orderBy = options[STMPersistingOptionOrder];
    
    BOOL asc = options[STMPersistingOptionOrderDirection] ? [[options[STMPersistingOptionOrderDirection] lowercaseString] isEqualToString:@"asc"] : YES;
    
    
    if (!orderBy) orderBy = @"id";
    
    predicate = [self predicate:predicate withOptions:options];
    
    switch ([self storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:
            
            return [self.fmdb getDataWithEntityName:entityName
                                      withPredicate:predicate
                                            orderBy:orderBy
                                          ascending:asc
                                         fetchLimit:pageSize
                                        fetchOffset:offset];

        case STMStorageTypeCoreData: {
            NSArray* objectsArray = [self objectsForEntityName:entityName
                                                       orderBy:orderBy
                                                     ascending:asc
                                                    fetchLimit:pageSize
                                                   fetchOffset:offset
                                                   withFantoms:YES
                                                     predicate:predicate
                                                    resultType:NSManagedObjectResultType
                                        inManagedObjectContext:[self document].managedObjectContext
                                                         error:error];
            
            return [self arrayForJSWithObjects:objectsArray];
            
        }
        default: 
            [self wrongEntityName:entityName error:error];
            return nil;
    }
    
}


- (NSDictionary *)mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{

    attributes = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error];
    
    if (!attributes || *error) return nil;

    __block NSDictionary *result;
    
    [self execute:^BOOL(id <STMPersistingTransaction> transaction) {
        
        result = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error inTransaction:transaction];
        
        // Exit if there's no result and no error from the interceptor, but don't rollback
        if (!result || *error) return !*error;
        
        result = [transaction mergeWithoutSave:entityName attributes:result options:options error:error];
        
        return !*error;
        
    }];
    
    if (*error) return nil;
    
    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                          ofUpdated:result ? result : attributes
                            options:options];
    
    return result;

}

- (NSArray *)mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError **)error{
    
    __block NSMutableArray *result = @[].mutableCopy;
    
    attributeArray = [self applyMergeInterceptors:entityName attributeArray:attributeArray options:options error:error];
    
    if (!attributeArray.count || *error) return attributeArray;
    
    [self execute:^BOOL(id <STMPersistingTransaction> transaction) {
        
        for (NSDictionary *attributes in attributeArray) {
            
            NSDictionary *merged = [self applyMergeInterceptors:entityName attributes:attributes options:options error:error inTransaction:transaction];
            
            if (*error) return NO;
            if (!merged) continue;
            
            merged = [transaction mergeWithoutSave:entityName attributes:merged options:options error:error];
            
            if (*error) return NO;
            if (merged) [result addObject:merged];
            
        }
        
        return YES;
        
    }];
    
    if (*error) return nil;
    
    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                     ofUpdatedArray:result.count ? result : attributeArray
                            options:options];
    
    return result;
    
}

- (BOOL)destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger deletedCount = [self destroyAllSync:entityName
                                         predicate:[self primaryKeyPredicateEntityName:entityName values:@[identifier] options:options]
                                           options:options
                                             error:error];
    
    return deletedCount > 0;
    
}

- (NSUInteger)destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    __block NSUInteger count;
    
    [self execute:^BOOL(id <STMPersistingTransaction> transaction) {
        
        count = [transaction destroyWithoutSave:entityName predicate:predicate options:options error:error];
        
        return !*error;
        
    }];
    
    return count;
    
}

- (NSDictionary *)updateSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    NSMutableDictionary *attributesToUpdate;
    
    if (options[STMPersistingOptionFieldstoUpdate]){
        attributesToUpdate = @{}.mutableCopy;
        NSArray *fieldsToUpdate = options[STMPersistingOptionFieldstoUpdate];
        for (NSString* attributeName in attributes.allKeys){
            if ([fieldsToUpdate containsObject:attributeName]) {
                attributesToUpdate[attributeName] = attributes[attributeName];
            }
        }
        attributesToUpdate[@"id"] = attributes[@"id"];
    }else{
        attributesToUpdate = attributes.mutableCopy;
    }
    
    if (!options[STMPersistingOptionSetTs] || [options[STMPersistingOptionSetTs] boolValue]){
        NSString *now = [STMFunctions stringFromNow];
        [attributesToUpdate setValue:now forKey:@"deviceTs"];
    }else{
        [attributesToUpdate removeObjectForKey:@"deviceTs"];
    }
    
    __block NSDictionary *result;
    
    [self execute:^BOOL(id <STMPersistingTransaction> transaction) {
        
        result = [transaction updateWithoutSave:entityName attributes:attributesToUpdate options:options error:error];
        
        return !*error;
        
    }];
    
    
    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                          ofUpdated:result
                            options:options];
    
    return result;
    
}

@end
