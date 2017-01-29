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

#import "STMCoreAuthController.h"
#import "STMCoreObjectsController.h"

@interface STMPersister()

@property (nonatomic, weak) id <STMSession> session;

@end


@implementation STMPersister

@synthesize subscriptions = _subscriptions;

+ (instancetype)initWithSession:(id <STMSession>)session {
    
    NSString *dataModelName = session.startSettings[@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }
    
    STMPersister *persister = [[[STMPersister alloc] init] initWithModelName:dataModelName];
    
    persister.session = session;
    
    persister.fmdb = [[STMFmdb alloc] initWithModelling:persister];

    persister.document = [STMDocument documentWithUID:session.uid
                                               iSisDB:session.iSisDB
                                        dataModelName:dataModelName];

    return persister;
    
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self addObservers];
    }
    return self;
    
}

#pragma mark - observers

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:self.session];

    [nc addObserver:self
           selector:@selector(documentReady:)
               name:NOTIFICATION_DOCUMENT_READY
             object:nil];
    
    [nc addObserver:self
           selector:@selector(documentNotReady:)
               name:NOTIFICATION_DOCUMENT_NOT_READY
             object:nil];

}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    if ([notification.object conformsToProtocol:@protocol(STMSession)]) {
        
        id <STMSession>session = (id <STMSession>)notification.object;
        
        if (session == self.session) {
            
            if (session.status == STMSessionRemoving) {
                
                [self removeObservers];
                self.session = nil;
                
            }
            
        }
        
    }

}

- (void)documentReady:(NSNotification *)notification {
    
    if ([[notification.userInfo valueForKey:@"uid"] isEqualToString:self.session.uid]) {
        
        [self.session persisterCompleteInitializationWithSuccess:YES];
        // here we can remove document observers
        
    }

}

- (void)documentNotReady:(NSNotification *)notification {

    if ([[notification.userInfo valueForKey:@"uid"] isEqualToString:self.session.uid]) {
        
        [self.session persisterCompleteInitializationWithSuccess:NO];
        // here we can remove document observers

    }

}

- (NSMutableDictionary *)subscriptions {
    if (!_subscriptions) {
        _subscriptions = [NSMutableDictionary dictionary];
    }
    return _subscriptions;
}

#pragma mark - Private methods

- (NSDictionary *) mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error inSTMFmdb:(STMFmdb *)db{
    
    [db startTransaction];
    
    NSString *now = [STMFunctions stringFromNow];
    NSMutableDictionary *savingAttributes = attributes.mutableCopy;
    BOOL returnSaved = !([options[@"returnSaved"] isEqual:@NO] || options[@"lts"]);
    
    if (options[@"lts"]) {
        [savingAttributes setValue:options[@"lts"] forKey:@"lts"];
        [savingAttributes removeObjectForKey:@"deviceTs"];
    } else {
        [savingAttributes setValue:now forKey:@"deviceTs"];
        [savingAttributes removeObjectForKey:@"lts"];
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
                                 options:@{@"createRecordStatuses":@NO}
                                   error:error];
            }
            
        }
        
        if (![attributes[@"isTemporary"] isEqual:NSNull.null] && [attributes[@"isTemporary"] boolValue]) return nil;
    }
    
    if ([self.fmdb hasTable:entityName]){
        
        return [self mergeWithoutSave:entityName
                           attributes:attributes
                              options:options
                                error:error
                            inSTMFmdb:self.fmdb];
        
    } else {
        
        if (options[@"roleName"]){
            [STMCoreObjectsController setRelationshipFromDictionary:attributes
                                              withCompletionHandler:^(BOOL sucess)
             {
                 if (!sucess) {
                     [STMFunctions error:error
                             withMessage:[NSString stringWithFormat:@"Error inserting %@", entityName]];
                 }
             }];
        } else {
            [STMCoreObjectsController insertObjectFromDictionary:attributes
                                                  withEntityName:entityName
                                           withCompletionHandler:^(BOOL sucess)
             {
                 if (!sucess) {
                     [STMFunctions error:error
                             withMessage:[NSString stringWithFormat:@"Relationship error %@", entityName]];
                 }
             }];
        }
        
        return attributes;
    }
}

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSArray* objects = @[];
    
    // TODO: expendable fetch on one object destroy
    if (!options[@"createRecordStatuses"] || [options[@"createRecordStatuses"] boolValue]){
        objects = [self findAllSync:entityName
                          predicate:predicate
                            options:options
                              error:error];
    }
    
    NSString* idKey;
    
    NSUInteger result = 0;
    
    if ([self.fmdb hasTable:entityName]){
        
        idKey = @"id";
        
        result = [self.fmdb destroy:entityName
                          predicate:predicate
                              error:error];
        
    }else{
        
        idKey = @"xid";
        // TODO: return deleted count from CoreData
        [self removeObjectForPredicate:predicate
                            entityName:entityName];

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
        [self.document saveDocument:^(BOOL success){}];
        return YES;
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
    
    BOOL isFantom = [options[@"fantoms"] boolValue];
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
                                                resultType:NSDictionaryResultType
                                    inManagedObjectContext:[self document].managedObjectContext
                                                     error:error];
        
        return [STMCoreObjectsController arrayForJSWithObjectsDics:objectsArray
                                                        entityName:entityName];
        
    }
    
}

- (NSDictionary *)mergeSync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error{
    
    NSDictionary* result = [self mergeWithoutSave:entityName
                                       attributes:attributes
                                          options:options error:error];
    
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
    
    return result;

}

- (NSArray *)mergeManySync:(NSString *)entityName attributeArray:(NSArray *)attributeArray options:(NSDictionary *)options error:(NSError **)error{
    
    NSMutableArray *result = @[].mutableCopy;
    
    for (NSDictionary* dictionary in attributeArray){
        
        NSDictionary* dict = [self mergeWithoutSave:entityName
                                         attributes:dictionary
                                            options:options
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
    if ([self saveWithEntityName:entityName]){
        return result;
    } else {
        [STMFunctions error:error
                withMessage: [NSString stringWithFormat:@"Error saving %@", entityName]];
    }
    return nil;
}

- (BOOL)destroySync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error{
    
    NSPredicate* predicate;
    
    if ([self.fmdb hasTable:entityName]) {
        
        predicate = [NSPredicate predicateWithFormat:@"id = %@", identifier];
        
    } else {
        
        NSData *identifierData = [STMFunctions xidDataFromXidString:identifier];
        predicate = [NSPredicate predicateWithFormat:@"xid = %@", identifierData];
        
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