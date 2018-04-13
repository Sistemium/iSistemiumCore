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

#import "STMLazyDictionary.h"

@interface STMUnsyncedDataHelperState : NSObject <STMDataSyncingState>

@end


@implementation STMUnsyncedDataHelperState

@end


@interface STMUnsyncedDataHelper ()

@property (nonatomic, strong) NSMutableArray <STMPersistingObservingSubscriptionID> *subscriptions;
@property (nonatomic, strong) STMLazyDictionary <NSString *, NSMutableSet <NSString *> *> *erroredObjectsByEntity;
@property (nonatomic, strong) STMLazyDictionary <NSString *, NSMutableDictionary <NSString *, NSMutableArray *> *> *pendingObjectsByEntity;
@property (nonatomic, strong) STMLazyDictionary <NSString *, NSMutableArray *> *syncedPendingObjectsByEntity;
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

- (instancetype)init {

    self = [super init];

    if (self) {
        [self initPrivateData];
    }

    return self;

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

        if ([self isPendingObject:itemData entityName:entityName]) {

            [self didSyncPendingObject:itemData entityName:entityName];

        } else if (itemVersion) {

            NSError *error;
            NSDictionary *options = @{STMPersistingOptionLts: itemVersion};

            [self.persistenceDelegate mergeSync:entityName attributes:itemData options:options error:&error];

        }

        [self checkForPendingParentsForObject:itemData];

    }

    [self sendNextUnsyncedObject];

    return YES;

}

#define LOGMESSAGE_MAX_TIME_INTERVAL_TO_UPLOAD 3600 * 24

- (NSPredicate *)predicateForUnsyncedObjectsWithEntityName:(NSString *)entityName {

    NSMutableArray *subpredicates = @[].mutableCopy;

    if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {

        NSString *uploadLogType = [self.session.settingsController stringValueForSettings:@"uploadLog.type" forGroup:@"syncer"];

        NSArray *logMessageSyncTypes = [[STMLogger sharedLogger] syncingTypesForSettingType:uploadLogType];

        [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
        // This is to avoid promlems of sending too much old logmessages
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"deviceCts > %@", [STMFunctions stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-LOGMESSAGE_MAX_TIME_INTERVAL_TO_UPLOAD]]]];

    }

    [subpredicates addObject:[NSPredicate predicateWithFormat:@"deviceTs != nil and (deviceTs > lts OR lts == nil)"]];

    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];

    return predicate;

}

//- (NSUInteger)numberOfUnsyncedObjects {
//    return 0;
//}


#pragma mark - Private helpers

- (void)initPrivateData {

    self.erroredObjectsByEntity = [STMLazyDictionary lazyDictionaryWithItemsClass:[NSMutableSet class]];
    self.pendingObjectsByEntity = [STMLazyDictionary lazyDictionaryWithItemsClass:[NSMutableDictionary class]];
    self.syncedPendingObjectsByEntity = [STMLazyDictionary lazyDictionaryWithItemsClass:[NSMutableArray class]];

}

- (void)subscribeUnsynced {

    if (!self.subscriberDelegate) return;

    [self.subscriptions enumerateObjectsUsingBlock:^(NSString *_Nonnull subscriptionId, NSUInteger idx, BOOL *_Nonnull stop) {
        [self.persistenceDelegate cancelSubscription:subscriptionId];
    }];

    self.subscriptions = [NSMutableArray array];

    [self initPrivateData];

    for (NSString *entityName in [STMEntityController uploadableEntitiesNames]) {

        NSPredicate *predicate = [self.subscriberDelegate predicateForUnsyncedObjectsWithEntityName:entityName];

        NSDictionary *onlyLocalChanges = @{STMPersistingOptionLts: @NO};

        STMPersistingObservingSubscriptionID sid =
        [self.persistenceDelegate observeEntity:entityName predicate:predicate options:onlyLocalChanges callback:^(NSArray *data) {
            NSLog(@"observeEntity %@ data count %u", entityName, data.count);

//            if (data.count && !self.syncingState) {
//                for (NSDictionary *object in data) {
//
//                    NSDictionary *objectToSend = @{
//                                                   @"entityName": entityName,
//                                                   @"object": object
//                                                   };
//
//                    [self sendUnsyncedObject:objectToSend];
//
//                }
//            } else {
            [self startHandleUnsyncedObjects];
//            }


        }];

        [self.subscriptions addObject:sid];

//        NSLog(@"subscribe to %@ %@", entityName, sid);

    }

    [self startHandleUnsyncedObjects];

}

- (void)unsubscribeUnsynced {

    NSLog(@"unsubscribeUnsynced");

    [self initPrivateData];

    [self checkUnsyncedObjects];

    [self finishHandleUnsyncedObjects];

}

- (void)checkUnsyncedObjects {

    NSDictionary *somethingToUpload = [self anyObjectToSend];

    NSString *notificationName = somethingToUpload ? NOTIFICATION_SYNCER_HAVE_UNSYNCED_OBJECTS : NOTIFICATION_SYNCER_HAVE_NO_UNSYNCED_OBJECTS;

//    if (somethingToUpload) {
//        NSLog(@"%@ %@", somethingToUpload[@"entityName"], somethingToUpload[@"object"][@"id"]);
//    }

    [self postAsyncMainQueueNotification:notificationName];

}


#pragma mark - state control

- (void)startHandleUnsyncedObjects {

    @synchronized (self) {

        if (!self.subscriberDelegate || self.isPaused) {
            return [self checkUnsyncedObjects];
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

#ifdef DEBUG
    for (NSString *entityName in self.erroredObjectsByEntity.allKeys) {

        NSSet *ids = self.erroredObjectsByEntity[entityName];
        if (!ids.count) continue;
        NSLog(@"finishHandleUnsyncedObjects errored %@ of %@", @(ids.count), entityName);

    }
#endif

    self.syncingState = nil;

    [self checkUnsyncedObjects];
    [self initPrivateData];

    [self.subscriberDelegate finishUnsyncedProcess];

}


#pragma mark - handle unsynced objects

- (void)sendNextUnsyncedObject {

    if (!self.syncingState) {
        return [self finishHandleUnsyncedObjects];
    }

    NSDictionary *objectToSend = [self anyObjectToSend];

    [self sendUnsyncedObject:objectToSend];

}

- (void)sendUnsyncedObject:(NSDictionary *)objectToSend {

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

        for (NSString *key in unsyncedParents.allKeys) {
            alteredObject[key] = [NSNull null];
        }

        [alteredObject removeObjectForKey:STMPersistingKeyVersion];

        return alteredObject.copy;

    } else if (unsyncedParents) {
        return nil;
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

    NSDictionary *options = @{STMPersistingOptionPageSize: @1,
            STMPersistingOptionOrder: @"deviceTs,id",
            STMPersistingOptionOrderDirectionAsc};

    NSArray *result = [self.persistenceDelegate findAllSync:entityName predicate:predicate options:options error:&error];

    return result.firstObject;

}

- (NSDictionary <NSString *, NSDictionary *> *)checkUnsyncedParentsForObject:(NSDictionary *)object withEntityName:(NSString *)entityName {

    BOOL hasUnsyncedParent = NO;

    NSMutableDictionary <NSString *, NSDictionary *> *optionalUnsyncedParents = @{}.mutableCopy;

    NSEntityDescription *entityDesciption = [self.persistenceDelegate entitiesByName][entityName];

    NSArray *relNames = [self.persistenceDelegate toOneRelationshipsForEntityName:entityName].allKeys;

    for (NSString *relName in relNames) {

        NSString *relKey = [relName stringByAppendingString:RELATIONSHIP_SUFFIX];
        NSString *parentId = object[relKey];

        if ([STMFunctions isNull:parentId]) continue;

        NSString *parentEntityName = [entityDesciption.relationshipsByName[relName] destinationEntity].name;

        NSError *error;
        NSDictionary *parent = [self.persistenceDelegate findSync:parentEntityName identifier:parentId options:nil error:&error];

        if (!parent) {

            if (error) {
                NSLog(@"error to find %@ %@: %@", parentEntityName, parentId, error.localizedDescription);
            } else {
                NSLog(@"we have relation's id but have no both object with this id and error — something wrong with it");
            }

            continue;
        }

        BOOL theParentWasSynced = ![STMFunctions isEmpty:parent[STMPersistingOptionLts]];

        if (theParentWasSynced || [self isSyncedPendingObject:parent entityName:parentEntityName]) {
            continue;
        }

        hasUnsyncedParent = YES;

        NSRelationshipDescription *relationship = entityDesciption.relationshipsByName[relName];

        BOOL hasUnsyncedRequiredParent = relationship.inverseRelationship.deleteRule == NSCascadeDeleteRule;
        BOOL wasOnceSynced = ![STMFunctions isEmpty:object[STMPersistingOptionLts]];
        BOOL isSyncedPending = [self isSyncedPendingObject:object entityName:entityName];

        if (hasUnsyncedRequiredParent || wasOnceSynced || isSyncedPending) {
            // this means "don't sync"
            return [NSDictionary dictionary];
        }

        optionalUnsyncedParents[relKey] = parent;

    }

    return hasUnsyncedParent ? optionalUnsyncedParents.copy : nil;

}


#pragma mark - handle dictionaries

- (void)declineFromSync:(NSDictionary *)object entityName:(NSString *)entityName {

    NSString *pk = object[STMPersistingKeyPrimary];

    if (!pk) {

        NSLog(@"have no object id");
        return;

    }

//    NSLog(@"declineFromSync: %@ %@", entityName, pk);

    @synchronized (self) {

        [self.erroredObjectsByEntity[entityName] addObject:pk];

    }

}

- (void)addPendingObject:(NSDictionary *)object entityName:(NSString *)entityName withHoldingParents:(NSArray *)parents {

    @synchronized (self) {

        NSLog(@"pendingObject: %@", object);

        NSArray *parentIds = [parents valueForKeyPath:STMPersistingKeyPrimary];

        self.pendingObjectsByEntity[entityName][object[STMPersistingKeyPrimary]] = parentIds.mutableCopy;

    }

}

- (BOOL)isPendingObject:(NSDictionary *)object entityName:(NSString *)entityName {

    @synchronized (self) {

        NSString *pk = object[STMPersistingKeyPrimary];

        if (!pk) return NO;

        return !!self.pendingObjectsByEntity[entityName][pk];

    }

}

- (void)releasePendingObject:(NSDictionary *)object entityName:(NSString *)entityName {

    NSString *pk = object[STMPersistingKeyPrimary];

    if (!pk) return;

    @synchronized (self) {

        NSMutableDictionary *pendingObjects = self.pendingObjectsByEntity[entityName];

        if (!pendingObjects[pk]) {
            return;
        }

        NSLog(@"releasePendingObject: %@", object);

        [pendingObjects removeObjectForKey:pk];

    }

}

- (void)checkForPendingParentsForObject:(NSDictionary *)object {

    NSString *pk = object[STMPersistingKeyPrimary];

    if (!pk) return;

    @synchronized (self) {

        for (NSString *entityName in self.pendingObjectsByEntity.allKeys.copy) {

            NSDictionary *pendingObjects = self.pendingObjectsByEntity[entityName].copy;

            [pendingObjects enumerateKeysAndObjectsUsingBlock:^(NSString *objectId, NSMutableArray *parents, BOOL *stop) {

                if (![parents containsObject:pk]) {
                    return;
                }

                [parents removeObject:pk];

                if (!parents.count) {
                    [self.pendingObjectsByEntity[entityName] removeObjectForKey:objectId];
                }

            }];

        }

    }

}

- (void)didSyncPendingObject:(NSDictionary *)object entityName:(NSString *)entityName {

    NSString *pk = object[@"id"];

    if (!pk) return;

    NSLog(@"didSyncPendingObject: %@", object);

    @synchronized (self) {

        NSMutableArray *syncedObjects = self.syncedPendingObjectsByEntity[entityName];
        [syncedObjects addObject:pk];

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
