//
//  STMUnsyncedDataHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMUnsyncedDataHelper.h"

#import "STMConstants.h"
#import "STMEntityController.h"

#import "STMLogger.h"
#import "STMCoreSettingsController.h"
#import "STMLogMessage.h"


@interface STMUnsyncedDataHelperState : NSObject <STMDataSyncingState>

@end


@implementation STMUnsyncedDataHelperState

@end


@interface STMUnsyncedDataHelper()

@property (nonatomic, strong) NSMutableArray <STMPersistingObservingSubscriptionID> *subscriptions;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableSet <NSString *> *> *erroredObjectsByEntity;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSMutableArray *> *> *pendingObjectsByEntity;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableArray *> *syncedPendingObjectsByEntity;
@property (nonatomic, strong) STMUnsyncedDataHelperState *syncingState;

@property (nonatomic) BOOL isPaused;

@end


@implementation STMUnsyncedDataHelper

@synthesize subscriberDelegate = _subscriberDelegate;

+ (STMUnsyncedDataHelper *)unsyncedDataHelperWithPersistence:(id <STMPersistingFullStack>)persistenceDelegate subscriber:(id <STMDataSyncingSubscriber>)subscriberDelegate {
    
    STMUnsyncedDataHelper *unsyncedDataHelper = [self controllerWithPersistenceDelegate:persistenceDelegate];

    unsyncedDataHelper.subscriberDelegate = subscriberDelegate;
    
    return unsyncedDataHelper;
    
}

#pragma mark - STMDataSyncing

- (void)startSyncing {
    
    @synchronized (self) {
        
        self.isPaused = NO;
        
        [self startHandleUnsyncedObjects];

    }
    
}

- (void)pauseSyncing {
    self.isPaused = YES;
}

- (void)setSubscriberDelegate:(id <STMDataSyncingSubscriber>)subscriberDelegate {
    
    self.isPaused = YES;
    _subscriberDelegate = subscriberDelegate;
    
    (_subscriberDelegate) ? [self subscribeUnsynced] : [self unsubscribeUnsynced];
    
}

- (BOOL)setSynced:(BOOL)success entity:(NSString *)entityName itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    
    if (!success) {
        
        NSLog(@"failToSync %@ %@", entityName, itemData[@"id"]);
        
        [self declineFromSync:itemData entityName:entityName];
        [self releasePendingObject:itemData entityName:entityName];
        
    } else {
        
        if (itemVersion) {
            
            NSLog(@"sync success %@ %@", entityName, itemData[@"id"]);
            
            if ([self isPendingObject:itemData entityName:entityName]) {
                
                [self didSyncPendingObject:itemData entityName:entityName];

            } else {

                NSError *error;
                [self.persistenceDelegate mergeSync:entityName
                                         attributes:itemData
                                            options:@{STMPersistingOptionLts: itemVersion}
                                              error:&error];
                
            }
            
            [self checkForPendingParentsForObject:itemData];
            
        } else {
            NSLog(@"No itemVersion for %@ %@", entityName, itemData[@"id"]);
        }
        
    }
    
    [self sendNextUnsyncedObject];
    
    return YES;
    
}

- (NSPredicate *)predicateForUnsyncedObjectsWithEntityName:(NSString *)entityName {
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
        
        NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                           forGroup:@"syncer"];
        
        NSArray *logMessageSyncTypes = [[STMLogger sharedLogger] syncingTypesForSettingType:uploadLogType];
        
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
        
    }
    
    [subpredicates addObject:[NSPredicate predicateWithFormat:@"deviceTs > lts OR lts == nil"]];
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    return predicate;
    
}

//- (NSUInteger)numberOfUnsyncedObjects {
//    return 0;
//}


#pragma mark - Private helpers

- (void)subscribeUnsynced {
    
    if (!self.subscriberDelegate) return;
    
    [self.subscriptions enumerateObjectsUsingBlock:^(NSString * _Nonnull subscriptionId, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.persistenceDelegate cancelSubscription:subscriptionId];
    }];
    
    self.subscriptions = [NSMutableArray array];
    self.erroredObjectsByEntity = [NSMutableDictionary dictionary];
    self.pendingObjectsByEntity = @{}.mutableCopy;
    self.syncedPendingObjectsByEntity = @{}.mutableCopy;
    
    for (NSString *entityName in [STMEntityController uploadableEntitiesNames]) {
        
        NSPredicate *predicate = [self.subscriberDelegate predicateForUnsyncedObjectsWithEntityName:entityName];
        
        NSDictionary *onlyLocalChanges = @{STMPersistingOptionLts:@NO};
        
        STMPersistingObservingSubscriptionID sid =
        [self.persistenceDelegate observeEntity:entityName predicate:predicate options:onlyLocalChanges callback:^(NSArray *data) {
            NSLog(@"observeEntity %@ data count %u", entityName, data.count);
            [self startHandleUnsyncedObjects];
        }];
        
        [self.subscriptions addObject:sid];
        
//        NSLog(@"subscribe to %@ %@", entityName, sid);
        
    }
    
    [self startHandleUnsyncedObjects];
    
}

- (void)unsubscribeUnsynced {
    
    NSLog(@"unsubscribeUnsynced");
    
    self.erroredObjectsByEntity = nil;
    self.pendingObjectsByEntity = nil;
    self.syncedPendingObjectsByEntity = nil;
    
    [self checkUnsyncedObjects];

    [self finishHandleUnsyncedObjects];

}

- (void)checkUnsyncedObjects {
    
    NSString *notificationName = [self anyObjectToSend] ? NOTIFICATION_SYNCER_HAVE_UNSYNCED_OBJECTS : NOTIFICATION_SYNCER_HAVE_NO_UNSYNCED_OBJECTS;
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                        object:self];

}


#pragma mark - state control

- (void)startHandleUnsyncedObjects {
    
    @synchronized (self) {
        
        if (!self.subscriberDelegate || self.isPaused) {
            
            [self checkUnsyncedObjects];
            return;
            
        }

        if (!self.syncingState) {
            NSLogMethodName;
            self.syncingState = [[STMUnsyncedDataHelperState alloc] init];
            [self sendNextUnsyncedObject];
        }
        
    }

}

- (void)finishHandleUnsyncedObjects {
    
    NSLogMethodName;
    
    [self.erroredObjectsByEntity enumerateKeysAndObjectsUsingBlock:^(NSString * entityName, NSMutableSet<NSString *> * ids, BOOL * stop) {
        NSLog(@"finishHandleUnsyncedObjects errored %@ of %@", @(ids.count), entityName);
    }];
    
    self.syncingState = nil;
    
    [self checkUnsyncedObjects];

    self.erroredObjectsByEntity = [NSMutableDictionary dictionary];
    self.pendingObjectsByEntity = @{}.mutableCopy;
    self.syncedPendingObjectsByEntity = @{}.mutableCopy;
    
    [self.subscriberDelegate finishUnsyncedProcess];
    
}


#pragma mark - handle unsynced objects

- (void)sendNextUnsyncedObject {

    if (!self.syncingState) {
        return [self finishHandleUnsyncedObjects];
    }
    
    NSDictionary *objectToSend = [self anyObjectToSend];
    
    if (!objectToSend) {
        return [self finishHandleUnsyncedObjects];
    }
    
    if (!self.subscriberDelegate) {
        return;
    }
    
    NSString *entityName = objectToSend[@"entityName"];
    NSDictionary *itemData = objectToSend[@"object"];
    
    BOOL isCoreData = [self.persistenceDelegate storageForEntityName:entityName] == STMStorageTypeCoreData;
    NSString *itemVersion = itemData[isCoreData ? @"ts" : STMPersistingKeyVersion];
    
    [self.subscriberDelegate haveUnsynced:entityName itemData:itemData itemVersion:itemVersion];
    

}

- (NSDictionary *)anyObjectToSend {
   
    for (NSString *entityName in [STMEntityController uploadableEntitiesNames]) {

        NSDictionary *anyObjectToSend = [self findSyncableObjectWithEntityName:entityName];
        
        if (anyObjectToSend) {
            return @{
                     @"entityName": entityName,
                     @"object": anyObjectToSend
                     };
        }
        
    }
    
    return nil;
    
}

- (NSDictionary *)findSyncableObjectWithEntityName:(NSString *)entityName {
    
    NSDictionary *unsyncedObject = [self unsyncedObjectWithEntityName:entityName];
    
    if (!unsyncedObject) return nil;
        
    NSDictionary *unsyncedParents = [self checkUnsyncedParentsForObject:unsyncedObject withEntityName:entityName];
    
    if (unsyncedParents.count) {
        
        [self addPendingObject:unsyncedObject entityName:entityName withHoldingParents:unsyncedParents.allValues];
    
        NSMutableDictionary *alteredObject = unsyncedObject.mutableCopy;
        
        [unsyncedParents enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
            alteredObject[key] = [NSNull null];
        }];
        
        return alteredObject.copy;

    }
    
    return unsyncedObject;
    
}

- (NSDictionary *)unsyncedObjectWithEntityName:(NSString *)entityName {

    NSError *error = nil;
    
    NSMutableArray *subpredicates = [NSMutableArray array];
    
    NSPredicate *unsyncedPredicate = [self predicateForUnsyncedObjectsWithEntityName:entityName];
    
    if (!unsyncedPredicate) return nil;
    
    [subpredicates addObject:unsyncedPredicate];
    
    NSPredicate *erroredExclusion = [self excludingErroredPredicateWithEntityName:entityName];
    if (erroredExclusion) [subpredicates addObject:erroredExclusion];
    
    NSPredicate *pendingObjectsExclusion = [self excludingPendingObjectsPredicateWithEntityName:entityName];
    if (pendingObjectsExclusion) [subpredicates addObject:pendingObjectsExclusion];

    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    NSDictionary *options = @{STMPersistingOptionPageSize   : @1,
                              STMPersistingOptionOrder      : @"deviceTs,id",
                              STMPersistingOptionOrderDirectionAsc};
    
    NSArray *result = [self.persistenceDelegate findAllSync:entityName
                                                  predicate:predicate
                                                    options:options
                                                      error:&error];
    return result.firstObject;

}

- (NSDictionary <NSString *, NSDictionary *> *)checkUnsyncedParentsForObject:(NSDictionary *)object withEntityName:(NSString *)entityName {
    
    BOOL haveUnsyncedParent = NO;
    
    NSMutableDictionary <NSString *, NSDictionary *> *optionalUnsyncedParents = @{}.mutableCopy;
    
    NSEntityDescription *entityDesciption = [self.persistenceDelegate entitiesByName][entityName];

    NSArray *relNames = [self.persistenceDelegate toOneRelationshipsForEntityName:entityName].allKeys;
    
    for (NSString *relName in relNames) {

        NSString *relKey = [relName stringByAppendingString:RELATIONSHIP_SUFFIX];
        
        NSString *parentId = object[relKey];
        
        if (!parentId || [parentId isKindOfClass:[NSNull class]]) continue;
        
        NSString *parentEntityName = [entityDesciption.relationshipsByName[relName] destinationEntity].name;
        
        NSError *error = nil;
        
        NSDictionary *parent = [self.persistenceDelegate findSync:parentEntityName
                                                       identifier:parentId
                                                          options:nil
                                                            error:&error];
        
        BOOL haveToCheckRelationship = NO;
        
        if (parent) {
            
            NSString *parentLts = parent[STMPersistingOptionLts];
            
            BOOL isEmptyLts = (![STMFunctions isNotNull:parentLts] || [parentLts isEqualToString:@""]);
            
            if (isEmptyLts) {
                
                BOOL isSynced = [self isSyncedPendingObject:parent entityName:parentEntityName];
                
                haveToCheckRelationship = !isSynced;
                
            }
            
        } else {
            
            if (error) {
                NSLog(@"error to find %@ %@: %@", parentEntityName, parentId, error.localizedDescription);
            } else {
                NSLog(@"we have relation's id but have no both object with this id and error — something wrong with it");
            }
            
            haveToCheckRelationship = YES;
            
        }
        
        if (haveToCheckRelationship) {
            
            haveUnsyncedParent = YES;
            
            NSRelationshipDescription *relationship = entityDesciption.relationshipsByName[relName];
            
            if (relationship.inverseRelationship.deleteRule != NSCascadeDeleteRule) {
                
                if (parent) {
                    optionalUnsyncedParents[relKey] = parent;
                } else {
                    NSLog(@"have no parent to wait for sync — something wrong with it");
                }
                
            }
            
        }
        
    }

    return haveUnsyncedParent ? optionalUnsyncedParents.copy : nil;
    
}


#pragma mark - handle dictionaries

- (void)declineFromSync:(NSDictionary *)object entityName:(NSString *)entityName{
    
    NSString *pk = object[@"id"];
    
    if (!pk) {
        
        NSLog(@"have no object id");
        return;
        
    }
    
//    NSLog(@"declineFromSync: %@ %@", entityName, pk);
    
    @synchronized (self) {
        
        NSMutableSet *errored = self.erroredObjectsByEntity[entityName];
        if (!errored) errored = [NSMutableSet set];
        
        [errored addObject:pk];
        
        self.erroredObjectsByEntity[entityName] = errored;
        
    }

}

- (void)addPendingObject:(NSDictionary *)object entityName:(NSString *)entityName withHoldingParents:(NSArray *)parents {
    
    NSString *pk = object[@"id"];
    
    NSLog(@"pendingObject: %@", object);
    
    @synchronized (self) {
        
        NSMutableDictionary <NSString *, NSMutableArray *> *pendingObjects = self.pendingObjectsByEntity[entityName];
        
        if (!pendingObjects) pendingObjects = @{}.mutableCopy;
        
        pendingObjects[pk] = [[parents valueForKeyPath:@"id"] mutableCopy];
        
        self.pendingObjectsByEntity[entityName] = pendingObjects;
        
    }

}

- (BOOL)isPendingObject:(NSDictionary *)object entityName:(NSString *)entityName {
    
    NSString *pk = object[@"id"];
    
    if (!pk) return NO;
    
    @synchronized (self) {
        
        NSMutableDictionary <NSString *, NSMutableArray *> *pendingObjects = self.pendingObjectsByEntity[entityName];

        return pendingObjects[pk] ? YES : NO;
        
    }

}

- (void)releasePendingObject:(NSDictionary *)object entityName:(NSString *)entityName {
    
    NSString *pk = object[@"id"];
    
    if (!pk) return;
    
    @synchronized (self) {
        
        NSMutableDictionary <NSString *, NSMutableArray *> *pendingObjects = self.pendingObjectsByEntity[entityName];

        if (pendingObjects[pk]) {
            
            NSLog(@"releasePendingObject: %@", object);

            [pendingObjects removeObjectForKey:pk];
            
            self.pendingObjectsByEntity[entityName] = pendingObjects;

        }

    }
    
}

- (void)checkForPendingParentsForObject:(NSDictionary *)object {
    
    NSString *pk = object[@"id"];
    
    if (!pk) return;

    @synchronized (self) {
        
        __block NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSMutableArray *> *> *copyOfPendingObjectsByEntity = self.pendingObjectsByEntity.mutableCopy;
        
        [self.pendingObjectsByEntity enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSMutableDictionary<NSString *,NSMutableArray *> * _Nonnull pendingObjects, BOOL * _Nonnull stop) {
           
            __block NSMutableDictionary<NSString *,NSMutableArray *> *copyOfPendingObjects = pendingObjects.mutableCopy;
                        
            [pendingObjects enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull objectId, NSMutableArray * _Nonnull parents, BOOL * _Nonnull stop) {
                                
                if ([parents containsObject:pk]) {
                    
                    [parents removeObject:pk];
                    
                    if (parents.count > 0) {
                        
                        copyOfPendingObjects[objectId] = parents;
                        
                    } else {
                        
                        [copyOfPendingObjects removeObjectForKey:objectId];
                        
                    }
                    
                }
                
            }];
            
            if (copyOfPendingObjects.count > 0) {
                
                copyOfPendingObjectsByEntity[entityName] = copyOfPendingObjects.mutableCopy;
                
            } else {
                
                [copyOfPendingObjectsByEntity removeObjectForKey:entityName];
                
            }
            
        }];
        
        self.pendingObjectsByEntity = copyOfPendingObjectsByEntity.mutableCopy;
        
    }
    
}

- (void)didSyncPendingObject:(NSDictionary *)object entityName:(NSString *)entityName {
    
    NSString *pk = object[@"id"];
    
    if (!pk) return;
    
    NSLog(@"didSyncPendingObject: %@", object);
    
    @synchronized (self) {
        
        NSMutableArray *syncedObjects = self.syncedPendingObjectsByEntity[entityName];
        
        if (!syncedObjects) syncedObjects = @[].mutableCopy;
        
        [syncedObjects addObject:pk];
        
        self.syncedPendingObjectsByEntity[entityName] = syncedObjects;
        
    }
    
}

- (BOOL)isSyncedPendingObject:(NSDictionary *)object entityName:(NSString *)entityName {
    
    NSString *pk = object[@"id"];
    
    if (!pk) return NO;
    
    @synchronized (self) {
        
        NSMutableArray *syncedObjects = self.syncedPendingObjectsByEntity[entityName];
        
        return [syncedObjects containsObject:pk];
        
    }
    
}


#pragma mark - Predicates

- (NSPredicate *)excludingErroredPredicateWithEntityName:(NSString *)entityName {

    NSSet *errored = self.erroredObjectsByEntity[entityName];
    
    if (!errored.count) return nil;
    
    return [NSCompoundPredicate notPredicateWithSubpredicate:[self.persistenceDelegate primaryKeyPredicateEntityName:entityName values:errored.allObjects]];

}

- (NSPredicate *)excludingPendingObjectsPredicateWithEntityName:(NSString *)entityName {
    
    NSDictionary *pendingObjects = self.pendingObjectsByEntity[entityName];

    if (!pendingObjects.count) return nil;

    return [NSCompoundPredicate notPredicateWithSubpredicate:[self.persistenceDelegate primaryKeyPredicateEntityName:entityName values:pendingObjects.allKeys]];
    
}


@end
