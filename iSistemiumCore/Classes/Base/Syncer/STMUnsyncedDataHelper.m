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


@end


@implementation STMUnsyncedDataHelper

@synthesize subscriberDelegate = _subscriberDelegate;
@synthesize syncingState = _syncingState;

+ (STMUnsyncedDataHelper *)unsyncedDataHelperWithPersistence:(id <STMPersistingFullStack>)persistenceDelegate subscriber:(id <STMDataSyncingSubscriber>)subscriberDelegate{
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
    self.syncingState = [[STMUnsyncedDataHelperState alloc] init];
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
        
    } else {
        
        if (itemVersion) {
            
            NSLog(@"sync success %@ %@", entityName, itemData[@"id"]);

            NSError *error;
            [self.persistenceDelegate mergeSync:entityName
                                     attributes:itemData
                                        options:@{STMPersistingOptionLts: itemVersion}
                                          error:&error];
            
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
    
}

#pragma mark - state control

- (void)startHandleUnsyncedObjects {
    
    if (!self.subscriberDelegate) return;

    if (!self.syncingState) return;
    
    if (self.syncingState.isInSyncingProcess) return;
    
    self.syncingState.isInSyncingProcess = YES;
    
    [self sendNextUnsyncedObject];

}

- (void)finishHandleUnsyncedObjects {
    
    NSLog(@"finishHandleUnsyncedObjects");
    
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
    
    if (unsyncedObject) {
        
        if (![self haveUnsyncedParentForObject:unsyncedObject]) {
        
            NSDictionary *resultObject = @{@"entityName"  : entityName,
                                           @"object"      : unsyncedObject};

            return resultObject;
            
        }
        
    }
    
    return nil;

}

- (NSDictionary *)unsyncedObjectWithEntityName:(NSString *)entityName {

    NSError *error = nil;
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    [subpredicates addObject:[self predicateForUnsyncedObjectsWithEntityName:entityName]];
    
    NSPredicate *erroredExclusion = [self excludingErroredPredicateWithEntityName:entityName];
    
    if (erroredExclusion) [subpredicates addObject:erroredExclusion];

    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    NSDictionary *options = @{STMPersistingOptionPageSize : @1,
                              STMPersistingOptionOrder:@"deviceTs,id",
                              STMPersistingOptionOrderDirectionAsc};
    
    NSArray *result = [self.persistenceDelegate findAllSync:entityName
                                                  predicate:predicate
                                                    options:options
                                                      error:&error];
    return result.firstObject;

}

- (void)checkUnsyncedParentsForObject:(NSDictionary *)object withEntityName:(NSString *)entityName completionHandler:(void (^)(BOOL haveUnsyncedParent, NSDictionary *optionalUnsyncedParents))completionHandler {
    
    BOOL haveUnsyncedParent = NO;
    NSMutableDictionary *optionalUnsyncedParents = @{}.mutableCopy;
    
    NSArray *relKeys = [object.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", RELATIONSHIP_SUFFIX]];
    
    for (NSString *relKey in relKeys) {
        
        NSString *parentId = object[relKey];
        
        if (!parentId || [parentId isKindOfClass:[NSNull class]]) continue;
        
        NSString *relName = [relKey substringToIndex:(relKey.length - RELATIONSHIP_SUFFIX.length)];
        NSString *capFirstLetter = [relName substringToIndex:1].capitalizedString;
        NSString *capEntityName = [relName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
        NSString *parentEntityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];
        
        NSError *error = nil;
        
        NSDictionary *parent = [self.persistenceDelegate findSync:parentEntityName
                                                       identifier:parentId
                                                          options:nil
                                                            error:&error];
        
        BOOL haveToCheckRelationship = NO;
        
        if (parent) {
            
            NSString *parentLts = parent[@"lts"];
            
            if (!parentLts || [parentLts isEqualToString:@""]) {
                
                haveToCheckRelationship = YES;
                
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
            
            NSEntityDescription *entityDesciption = [self.persistenceDelegate entitiesByName][entityName];
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

- (BOOL)haveUnsyncedParentForObject:(NSDictionary *)object {
    
    BOOL haveUnsyncedParent = NO;
    
    NSArray *relKeys = [object.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", RELATIONSHIP_SUFFIX]];

    for (NSString *relKey in relKeys) {

        NSString *parentId = object[relKey];
        
        if (!parentId || [parentId isKindOfClass:[NSNull class]]) continue;

        NSString *entityName = [relKey substringToIndex:(relKey.length - RELATIONSHIP_SUFFIX.length)];
        NSString *capFirstLetter = [entityName substringToIndex:1].capitalizedString;
        NSString *capEntityName = [entityName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
        entityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];
        
        NSError *error = nil;

        NSDictionary *parent = [self.persistenceDelegate findSync:entityName
                                                       identifier:parentId
                                                          options:nil
                                                            error:&error];

        if (parent) {
            
            NSString *parentLts = parent[@"lts"];
            
            if (!parentLts || [parentLts isEqualToString:@""]) {
                
                haveUnsyncedParent = YES;
                break;

            }
            
        } else {
            
            if (error) {
                NSLog(@"error to find %@ %@: %@", entityName, parentId, error.localizedDescription);
            } else {
                // we have relation's id but have no both object with this id and error — something wrong with it
            }
            
            haveUnsyncedParent = YES;
            break;
            
        }
        
    }
    
    return haveUnsyncedParent;
    
}

- (void)declineFromSync:(NSDictionary *)object entityName:(NSString *)entityName{
    
    NSString *pk = object[@"id"];
    
//    NSLog(@"declineFromSync: %@ %@", entityName, pk);
    
    @synchronized (self.erroredObjectsByEntity) {
        NSMutableSet *errored = self.erroredObjectsByEntity[entityName];
        
        if (!errored) errored = [NSMutableSet set];
        
        [errored addObject:pk];
        
        self.erroredObjectsByEntity[entityName] = errored;
    }

}


#pragma mark - Predicates

- (NSPredicate *)excludingErroredPredicateWithEntityName:(NSString *)entityName {

    NSSet *errored = self.erroredObjectsByEntity[entityName];
    
    if (!errored.count) return nil;
    
    NSArray *erroredData = [STMFunctions mapArray:errored.allObjects withBlock:^id _Nonnull(NSString * _Nonnull idString) {
        return [STMFunctions xidDataFromXidString:idString];
    }];
        
    return [NSPredicate predicateWithFormat:@"NOT (xid IN %@)", erroredData];

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
