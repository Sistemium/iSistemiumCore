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


@interface STMUnsyncedDataHelperState : NSObject <STMDataSyncingState>

@end


@implementation STMUnsyncedDataHelperState

@synthesize isInSyncingProcess = _isInSyncingProcess;


@end


@interface STMUnsyncedDataHelper()

@property (nonatomic, strong) NSMutableArray <STMPersistingObservingSubscriptionID> *subscriptions;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableSet <NSString *> *> *erroredObjectsByEntity;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSMutableArray *> *> *pendingObjectsByEntity;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableArray *> *syncedPendingObjectsByEntity;


@end


@implementation STMUnsyncedDataHelper

@synthesize subscriberDelegate = _subscriberDelegate;
@synthesize syncingState = _syncingState;

+ (STMUnsyncedDataHelper *)unsyncedDataHelperWithPersistence:(id <STMPersistingFullStack>)persistenceDelegate subscriber:(id <STMDataSyncingSubscriber>)subscriberDelegate {
    
    STMUnsyncedDataHelper *unsyncedDataHelper = [[STMUnsyncedDataHelper alloc] init];
    unsyncedDataHelper.persistenceDelegate = persistenceDelegate;
    unsyncedDataHelper.subscriberDelegate = subscriberDelegate;
    
    return unsyncedDataHelper;
    
}

- (void)setSyncingState:(id <STMDataSyncingState>)syncingState {

    _syncingState = syncingState;
    
    if (_syncingState) {
        [self startHandleUnsyncedObjects];
    }
    
}


#pragma mark - STMDataSyncing

- (void)startSyncing {
    
    @synchronized (self) {
        
        if (!self.syncingState) {
            self.syncingState = [[STMUnsyncedDataHelperState alloc] init];
        }

    }
    
}

- (void)pauseSyncing {
    self.syncingState = nil;
}

- (void)setSubscriberDelegate:(id <STMDataSyncingSubscriber>)subscriberDelegate {
    
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

- (NSUInteger)numberOfUnsyncedObjects {
    return 0;
}


#pragma mark - Private helpers

- (void)subscribeUnsynced {
    
    if (!self.subscriberDelegate) return;
    
    self.subscriptions = [NSMutableArray array];
    self.erroredObjectsByEntity = [NSMutableDictionary dictionary];
    self.pendingObjectsByEntity = @{}.mutableCopy;
    self.syncedPendingObjectsByEntity = @{}.mutableCopy;
    
    for (NSString *entityName in [STMEntityController uploadableEntitiesNames]) {
        
        NSPredicate *predicate = [self predicateForUnsyncedObjectsWithEntityName:entityName];
        
        NSLog(@"subscribe to %@", entityName);
        
        [self.subscriptions addObject:[self.persistenceDelegate observeEntity:entityName
                                                                    predicate:predicate
                                                                     callback:^(NSArray * _Nullable data)
                                       {
                                           NSLog(@"observeEntity %@ data count %u", entityName, data.count);
                                           [self startHandleUnsyncedObjects];
                                       }]];
        
    }
    
    [self startHandleUnsyncedObjects];
    
}

- (void)unsubscribeUnsynced {
    NSLog(@"unsubscribeUnsynced");
    
    [self.subscriptions enumerateObjectsUsingBlock:^(NSString * _Nonnull subscriptionId, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.persistenceDelegate cancelSubscription:subscriptionId];
    }];
    
    self.subscriptions = nil;
    self.erroredObjectsByEntity = nil;
    self.pendingObjectsByEntity = nil;
    self.syncedPendingObjectsByEntity = nil;
    
}

#pragma mark - state control

- (void)startHandleUnsyncedObjects {
    
    if (!self.subscriberDelegate) return;

    if (!self.syncingState) return;
    
    if (self.syncingState.isInSyncingProcess) return;
    
    self.syncingState.isInSyncingProcess = YES;
    
    NSLogMethodName;
    
    [self sendNextUnsyncedObject];

}

- (void)finishHandleUnsyncedObjects {
    
    NSLogMethodName;
    
    [self.erroredObjectsByEntity enumerateKeysAndObjectsUsingBlock:^(NSString * entityName, NSMutableSet<NSString *> * ids, BOOL * stop) {
        NSLog(@"finishHandleUnsyncedObjects errored %@ of %@", @(ids.count), entityName);
    }];
    
    self.syncingState.isInSyncingProcess = NO;
    
}


#pragma mark - handle unsynced objects

- (void)sendNextUnsyncedObject {

    if (!self.syncingState) {
        
        [self finishHandleUnsyncedObjects];
        return;
        
    }

    NSDictionary *objectToSend = [self anyObjectToSend];
    
    if (objectToSend) {
        
        NSString *entityName = objectToSend[@"entityName"];
        NSDictionary *object = objectToSend[@"object"];
        
//        NSLog(@"object to send: %@ %@", entityName, object[@"id"]);
        
        if (self.subscriberDelegate) {
            
            BOOL isCoreData = [self.persistenceDelegate storageForEntityName:entityName] == STMStorageTypeCoreData;
            NSString *objectVersion = isCoreData ? object[@"ts"] : object[STMPersistingKeyVersion];
            
            [self.subscriberDelegate haveUnsynced:entityName
                                         itemData:object
                                      itemVersion:objectVersion];
            
        }
        
    } else {
        
        [self finishHandleUnsyncedObjects];
        
    }

}

- (NSDictionary *)anyObjectToSend {
   
    NSDictionary *anyObjectToSend = nil;
    
    for (NSString *entityName in [STMEntityController uploadableEntitiesNames]) {

        anyObjectToSend = [self findSyncableObjectWithEntityName:entityName];
        
        if (anyObjectToSend) break;
        
    }
    
    return anyObjectToSend;
    
}

- (NSDictionary *)findSyncableObjectWithEntityName:(NSString *)entityName {
    
    NSDictionary *unsyncedObject = [self unsyncedObjectWithEntityName:entityName];
    
    __block NSMutableDictionary *resultObject = nil;
    
    if (unsyncedObject) {
        
        [self checkUnsyncedParentsForObject:unsyncedObject withEntityName:entityName completionHandler:^(BOOL haveUnsyncedParent, NSDictionary <NSString *, NSDictionary *> *optionalUnsyncedParents) {
            
            if (!haveUnsyncedParent || (haveUnsyncedParent && optionalUnsyncedParents.count > 0)) {
                
                resultObject = @{}.mutableCopy;
                resultObject[@"entityName"] = entityName;
                
                if (optionalUnsyncedParents.count > 0) {
                    
                    [self pendingObject:unsyncedObject
                             entityName:entityName
                     withHoldingParents:optionalUnsyncedParents.allValues];
                
                    NSMutableDictionary *alteredObject = unsyncedObject.mutableCopy;
                    
                    [optionalUnsyncedParents enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull obj, BOOL * _Nonnull stop) {
                        alteredObject[key] = [NSNull null];
                    }];
                    
                    resultObject[@"object"] = alteredObject;

                } else {
                    
                    resultObject[@"object"] = unsyncedObject;
                    
                }
                
            }
            
        }];
        
    }
    
    return resultObject;

}

- (NSDictionary *)unsyncedObjectWithEntityName:(NSString *)entityName {

    NSError *error = nil;
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    [subpredicates addObject:[self predicateForUnsyncedObjectsWithEntityName:entityName]];
    
    NSPredicate *erroredExclusion = [self excludingErroredPredicateWithEntityName:entityName];
    if (erroredExclusion) [subpredicates addObject:erroredExclusion];
    
    NSPredicate *pendingObjectsExclusion = [self excludingPendingObjectsPredicateWithEntityName:entityName];
    if (pendingObjectsExclusion) [subpredicates addObject:pendingObjectsExclusion];

    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    NSDictionary *options = @{STMPersistingOptionPageSize   : @1,
                              STMPersistingOptionOrder      :@"deviceTs,id",
                              STMPersistingOptionOrderDirectionAsc};
    
    NSArray *result = [self.persistenceDelegate findAllSync:entityName
                                                  predicate:predicate
                                                    options:options
                                                      error:&error];
    return result.firstObject;

}

- (void)checkUnsyncedParentsForObject:(NSDictionary *)object withEntityName:(NSString *)entityName completionHandler:(void (^)(BOOL haveUnsyncedParent, NSDictionary <NSString *, NSDictionary *> *optionalUnsyncedParents))completionHandler {
    
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
            
            NSString *parentLts = parent[@"lts"];
            
            BOOL isEmptyLts = (!parentLts || [parentLts isEqualToString:@""]);
            
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

    completionHandler(haveUnsyncedParent, optionalUnsyncedParents);
    
}


#pragma mark - handle dictionaries

- (void)declineFromSync:(NSDictionary *)object entityName:(NSString *)entityName{
    
    NSString *pk = object[@"id"];
    
//    NSLog(@"declineFromSync: %@ %@", entityName, pk);
    
    @synchronized (self) {
        NSMutableSet *errored = self.erroredObjectsByEntity[entityName];
        
        if (!errored) errored = [NSMutableSet set];
        
        [errored addObject:pk];
        
        self.erroredObjectsByEntity[entityName] = errored;
    }

}

- (void)pendingObject:(NSDictionary *)object entityName:(NSString *)entityName withHoldingParents:(NSArray *)parents {
    
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
                
                copyOfPendingObjectsByEntity[entityName] = copyOfPendingObjects;
                
            } else {
                
                [copyOfPendingObjectsByEntity removeObjectForKey:entityName];
                
            }
            
        }];
        
        self.pendingObjectsByEntity = copyOfPendingObjectsByEntity;
        
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
    
    NSArray *erroredIdsArray = [STMFunctions mapArray:errored.allObjects withBlock:^id _Nonnull(NSString * _Nonnull idString) {
        return [STMFunctions xidDataFromXidString:idString];
    }];
        
    return [NSPredicate predicateWithFormat:@"NOT (xid IN %@)", erroredIdsArray];

}

- (NSPredicate *)excludingPendingObjectsPredicateWithEntityName:(NSString *)entityName {
    
    NSDictionary *pendingObjects = self.pendingObjectsByEntity[entityName];

    if (!pendingObjects.count) return nil;

    return [NSPredicate predicateWithFormat:@"NOT (xid IN %@)", pendingObjects.allKeys];
    
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


@end
