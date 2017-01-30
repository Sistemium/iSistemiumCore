//
//  STMPersister.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMConstants.h"

#import "STMPersister.h"
#import "STMPersister+CoreData.h"
#import "STMPersister+Observable.h"

#import "STMCoreAuthController.h"
#import "STMCoreObjectsController.h"

@interface STMPersister()

@end

@implementation STMPersistingObservingSubscription

@end

@implementation STMPersister

+ (instancetype)persisterWithModelName:(NSString *)modelName uid:(NSString *)uid iSisDB:(NSString *)iSisDB completionHandler:(void (^)(BOOL success))completionHandler {

    STMPersister *persister = [[[STMPersister alloc] init] initWithModelName:modelName];
    
    persister.fmdb = [[STMFmdb alloc] initWithModelling:persister];
    persister.document = [STMDocument documentWithUID:uid
                                               iSisDB:iSisDB
                                        dataModelName:modelName];
    
    // TODO: call completionHandler after document is ready to rid off documentReady subscriptions
    if (completionHandler) completionHandler(YES);

    return persister;
    
}

- (instancetype)init {
    
    self = [super init];
    _subscriptions = [NSMutableDictionary dictionary];
    return self;
    
}

#pragma mark - Private methods

- (STMStorageType)storageForEntityName:(NSString *)entityName options:(NSDictionary*)options {
    
    STMStorageType storeTo = [self storageForEntityName:entityName];
    
    if (options[STMPersistingOptionForceStorage]) {
        storeTo = [options[STMPersistingOptionForceStorage] integerValue];
    }
    
    return storeTo;
}

- (NSDictionary *) mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error inSTMFmdb:(STMFmdb *)db{
    
    [db startTransaction];
    
    NSString *now = [STMFunctions stringFromNow];
    NSMutableDictionary *savingAttributes = attributes.mutableCopy;
    BOOL returnSaved = !([options[STMPersistingOptionReturnSaved] isEqual:@NO] || options[STMPersistingOptionLts]) || [options[STMPersistingOptionReturnSaved] isEqual:@YES];
    
    if (options[STMPersistingOptionLts]) {
        [savingAttributes setValue:options[STMPersistingOptionLts] forKey:STMPersistingOptionLts];
        [savingAttributes removeObjectForKey:@"deviceTs"];
    } else {
        [savingAttributes setValue:now forKey:@"deviceTs"];
        [savingAttributes removeObjectForKey:STMPersistingOptionLts];
    }
    
    savingAttributes[@"deviceAts"] = now;
    
    if (!savingAttributes[@"deviceCts"] || [savingAttributes[@"deviceCts"] isEqual:[NSNull null]]) {
        savingAttributes[@"deviceCts"] = now;
    }
    
    if(!returnSaved){
        [db mergeInto:entityName
           dictionary:savingAttributes
                error:error];
        return nil;
    } else {
        return [db mergeIntoAndResponse:entityName
                             dictionary:savingAttributes
                                  error:error];
    }
    
}

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    if ([entityName isEqualToString:@"STMRecordStatus"]) {
        
        if (![attributes[@"isRemoved"] isEqual:NSNull.null] ? [attributes[@"isRemoved"] boolValue] : false) {
            
            NSPredicate* predicate;
            
            NSString *objectXid = attributes[@"objectXid"];
            NSString *entityNameToDestroy = [STMFunctions addPrefixToEntityName:attributes[@"name"]];
            
            switch ([self storageForEntityName:entityNameToDestroy]) {
                case STMStorageTypeFMDB:
                    predicate = [NSPredicate predicateWithFormat:@"id = %@", objectXid];
                    break;
                    
                case STMStorageTypeCoreData: {
                    NSData *objectXidData = [STMFunctions xidDataFromXidString:objectXid];
                    predicate = [NSPredicate predicateWithFormat:@"xid = %@", objectXidData];
                    break;
                }
                default: {
                    
                }
            }

            if (predicate) {
                [self destroyWithoutSave:attributes[@"name"]
                               predicate:predicate
                                 options:@{STMPersistingOptionRecordstatuses:@NO}
                                   error:error];
            }
            
        }
        
        if (![attributes[@"isTemporary"] isEqual:NSNull.null] && [attributes[@"isTemporary"] boolValue]) return nil;
    }
    
    switch ([self storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:
            return [self mergeWithoutSave:entityName
                               attributes:attributes
                                  options:options
                                    error:error
                                inSTMFmdb:self.fmdb];
        case STMStorageTypeCoreData:
            
            return [self mergeWithoutSave:entityName
                               attributes:attributes
                                  options:options
                                    error:error
                   inManagedObjectContext:self.document.managedObjectContext];
        default:
            // TODO: set the error
            return nil;
    }
    
}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSArray* objects = @[];
    
    // TODO: expendable fetch on one object destroy
    if (!options[STMPersistingOptionRecordstatuses] || [options[STMPersistingOptionRecordstatuses] boolValue]){
        objects = [self findAllSync:entityName
                          predicate:predicate
                            options:options
                              error:error];
    }
    
    NSString* idKey;
    
    NSUInteger result = 0;
    
    switch ([self storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:
            idKey = @"id";
            
            result = [self.fmdb destroy:entityName
                              predicate:predicate
                                  error:error];
            break;
        
        case STMStorageTypeCoreData:
            idKey = @"xid";
            
            result = [self removeObjectForPredicate:predicate
                                         entityName:entityName];
            break;
            
        default: break;
    }
    
    for (NSDictionary* object in objects){
        
        NSDictionary *recordStatus = @{
                                       @"objectXid":object[idKey],
                                       @"name":[STMFunctions removePrefixFromEntityName:entityName],
                                       @"isRemoved": @YES};
        
        [self mergeWithoutSave:@"STMRecordStatus"
                    attributes:recordStatus
                       options:nil error:error];
        
    }
    
    return result;
    
}


- (BOOL)saveWithEntityName:(NSString *)entityName{
    
    if ([self.fmdb hasTable:entityName]){
        return [self.fmdb commit];
    } else {
        NSError *error;
        [self.document.managedObjectContext save:&error];
        return !error;
    }
    
}

#pragma mark - STMPersistingSync

- (NSUInteger)countSync:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options
                  error:(NSError **)error {
    if ([self.fmdb hasTable:entityName]){
#warning predicates not supported yet
        // TODO: make generic predicate to SQL method with predicate filtering
        return [self.fmdb count:entityName
                  withPredicate:[NSPredicate predicateWithFormat:@"isFantom == 0"]];
    } else {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        return [[self document].managedObjectContext countForFetchRequest:request
                                                                    error:error];
    }
    
}

- (NSDictionary *)findSync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate* predicate;
    
    if ([self.fmdb hasTable:entityName]) {
        
        predicate = [NSPredicate predicateWithFormat:@"isFantom = 0 and id == %@", identifier];
        
    } else {
        
        NSData *identifierData = [STMFunctions xidDataFromXidString:identifier];
        predicate = [NSPredicate predicateWithFormat:@"xid == %@", identifierData];
        
    }
    
    NSArray *results = [self findAllSync:entityName
                               predicate:predicate
                                 options:options
                                   error:error];
    
    if (results.count) {
        return results.firstObject;
    } else {
        return nil;
    }
    
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger pageSize = [options[@"pageSize"] integerValue];
    NSUInteger offset = [options[@"startPage"] integerValue];
    if (offset) {
        offset -= 1;
        offset *= pageSize;
    }
    NSString *orderBy = options[@"sortBy"];
    
    BOOL asc = options[@"order"] ? [[options[@"order"] lowercaseString] isEqualToString:@"asc"] : YES;
    
    // TODO: maybe could be simplified
    NSMutableArray *predicates = [[NSMutableArray alloc] init];
    
    BOOL isFantom = [options[STMPersistingOptionFantoms] boolValue];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom = %@", @(isFantom)]];
    
    if (predicate) {
        [predicates addObject:predicate];
    }
    
    NSCompoundPredicate *predicateWithFantoms = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    
    if (!orderBy) orderBy = @"id";
    
    if ([self.fmdb hasTable:entityName]){
        
        return [self.fmdb getDataWithEntityName:entityName
                                  withPredicate:predicateWithFantoms
                                        orderBy:orderBy
                                      ascending:asc
                                     fetchLimit:options[@"pageSize"] ? &pageSize : nil
                                    fetchOffset:options[@"offset"] ? &offset : nil];
    } else {
        
        NSArray* objectsArray = [self objectsForEntityName:entityName
                                                   orderBy:orderBy
                                                 ascending:asc
                                                fetchLimit:pageSize
                                               fetchOffset:offset
                                               withFantoms:YES
                                                 predicate:predicateWithFantoms
                                                resultType:NSManagedObjectResultType
                                    inManagedObjectContext:[self document].managedObjectContext
                                                     error:error];
        
        return [self.class arrayForJSWithObjects:objectsArray];
//        return [STMCoreObjectsController arrayForJSWithObjectsDics:objectsArray
//                                                        entityName:entityName];
        
    }
    
}

- (NSDictionary *)fixMergeOptions:(NSDictionary *)options
                       entityName:(NSString *)entityName{
    
    if ([self storageForEntityName:entityName options:options] == STMStorageTypeCoreData && options[STMPersistingOptionLts]) {
        NSDate *lts = [STMFunctions dateFromString:options[STMPersistingOptionLts]];
        // Add 1ms because there are nanoseconds in deviceTs
        options = [STMFunctions setValue:[lts dateByAddingTimeInterval:1.0/1000.0]
                                  forKey:STMPersistingOptionLts
                            inDictionary:options];
    }
    
    return options;
    
}

- (NSDictionary *)mergeSync:(NSString *)entityName
                 attributes:(NSDictionary *)attributes
                    options:(NSDictionary *)options
                      error:(NSError **)error{
    
    NSDictionary* result = [self mergeWithoutSave:entityName
                                       attributes:attributes
                                          options:[self fixMergeOptions:options entityName:entityName]
                                            error:error];
    
    if (*error){
        [STMFunctions error:error
                withMessage: [NSString stringWithFormat:@"Error merging %@", entityName]];
        return nil;
    }
    
    if (![self saveWithEntityName:entityName]){
        [STMFunctions error:error
                withMessage: [NSString stringWithFormat:@"Error saving %@", entityName]];
        return nil;
    }
    
    [self notifyObservingEntityName:entityName
                          ofUpdated:result];
    
    return result;

}

- (NSArray *)mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError **)error{
    
    NSMutableArray *result = @[].mutableCopy;
    
    for (NSDictionary* dictionary in attributeArray){
        
        NSDictionary* dict = [self mergeWithoutSave:entityName
                                         attributes:dictionary
                                            options:[self fixMergeOptions:options entityName:entityName]
                                              error:error];
        
        if (dict){
            [result addObject:dict];
        }
        
        if (*error){
            #warning possible danger, will rollback changes from other threads
            [self.fmdb rollback];
            return nil;
        }
    }
    
    if (![self saveWithEntityName:entityName]){
        [STMFunctions error:error
                withMessage:[NSString stringWithFormat:@"Error saving %@", entityName]];
    }
    
    [self notifyObservingEntityName:entityName
                     ofUpdatedArray:result];
    
    return result;
    
}

- (BOOL)destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate* predicate;
    
    switch ([self storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:
            predicate = [NSPredicate predicateWithFormat:@"id = %@", identifier];
            break;
        case STMStorageTypeCoreData: {
            NSData *identifierData = [STMFunctions xidDataFromXidString:identifier];
            predicate = [NSPredicate predicateWithFormat:@"xid = %@", identifierData];
        }
        default:
            break;
    }
    
    NSUInteger deletedCount = [self destroyAllSync:entityName
                                         predicate:predicate
                                           options:options
                                             error:error];
    
    return deletedCount > 0;
    
}

- (NSUInteger)destroyAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger count = [self destroyWithoutSave:entityName
                                      predicate:predicate
                                        options:options
                                          error:error];
    
    if (*error){
        #warning possible danger, will rollback changes from other threads
        [self.fmdb rollback];
        return 0;
    }
    
    if ([self saveWithEntityName:entityName]){
        return count;
    } else {
        [STMFunctions error:error
                withMessage: [NSString stringWithFormat:@"Error saving %@", entityName]];
        return count;
    }
    
}

@end
