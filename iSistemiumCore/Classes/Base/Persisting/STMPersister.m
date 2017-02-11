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

#import "STMPersister.h"
#import "STMPersister+CoreData.h"


@interface STMPersister()

@property (nonatomic,strong) NSString * fmdbFileName;

@end

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
            break;
            
        default:
            [self wrongEntityName:entityName error:error];
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
        
#warning - may be make saveWithEntityName: method async to return correct value if using document save
        [self.document saveDocument:^(BOOL success) {
        }];
        
        return YES;
        
//        NSError *error;
//        [self.document.managedObjectContext save:&error];
//        return !error;
        
    }
    
}

- (NSPredicate *)predicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options {
    
    NSMutableArray *predicates = NSMutableArray.array;
    
    BOOL isFantom = [options[STMPersistingOptionFantoms] boolValue];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isFantom = %@", @(isFantom)]];
    
    if (predicate) {
        [predicates addObject:predicate];
    }
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
}

- (void)wrongEntityName:(NSString *)entityName error:(NSError **)error {
    NSString *message = [NSString stringWithFormat:@"'%@' is not a concrete entity name", entityName];
    [STMFunctions error:error withMessage:message];
}

#pragma mark - STMPersistingSync

- (NSUInteger)countSync:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options
                  error:(NSError **)error {
    
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
    
    NSPredicate* predicate;
    
    switch ([self storageForEntityName:entityName options:options]) {
        case STMStorageTypeFMDB:
            // TODO: isFantom = 0 should be only if no withFantoms / fantoms option
            predicate = [NSPredicate predicateWithFormat:@"isFantom = 0 and id == %@",
                         identifier];
            break;
        case STMStorageTypeCoreData:{
            NSData *identifierData = [STMFunctions xidDataFromXidString:identifier];
            predicate = [NSPredicate predicateWithFormat:@"xid == %@", identifierData];
            break;
        }
        default:
            [self wrongEntityName:entityName error:error];
            return nil;
    }

    NSArray *results = [self findAllSync:entityName
                               predicate:predicate
                                 options:options
                                   error:error];
    
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
    
    if ([self.fmdb hasTable:entityName]){
        
        return [self.fmdb getDataWithEntityName:entityName
                                  withPredicate:predicate
                                        orderBy:orderBy
                                      ascending:asc
                                     fetchLimit:options[STMPersistingOptionPageSize] ? &pageSize : nil
                                    fetchOffset:options[@"offset"] ? &offset : nil];
    } else {
        
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
    
}

- (NSDictionary *)fixMergeOptions:(NSDictionary *)options
                       entityName:(NSString *)entityName{
    
    if ([self storageForEntityName:entityName options:options] == STMStorageTypeCoreData && options[STMPersistingOptionLts]) {
        NSDate *lts = [STMFunctions dateFromString:options[STMPersistingOptionLts]];
        // Add 1ms because there are microseconds in deviceTs
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
    
    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
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
    
    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
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
            break;
        }
        default:
            [self wrongEntityName:entityName error:error];
            return NO;
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

- (NSDictionary *)updateSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    NSDictionary *result;
    
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
    
    switch ([self storageForEntityName:entityName options:options]) {
            
        case STMStorageTypeFMDB:
            result = [self.fmdb update:entityName attributes:attributesToUpdate error:error];
            break;
            
        case STMStorageTypeCoreData:
            result = [self update:entityName
                     attributes:attributesToUpdate
                        options:options
                          error:error
         inManagedObjectContext:self.document.managedObjectContext];
            break;
            
        default:
            [self wrongEntityName:entityName error:error];
            return nil;
    }
    
    [self saveWithEntityName:entityName];
    
    [self notifyObservingEntityName:[STMFunctions addPrefixToEntityName:entityName]
                          ofUpdated:result];
    
    return result;
    
}

@end
