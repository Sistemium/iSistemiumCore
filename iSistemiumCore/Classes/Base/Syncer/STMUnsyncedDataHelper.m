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

@implementation STMDataSyncingState

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

- (void)setSyncingState:(STMDataSyncingState *)syncingState {

    _syncingState = syncingState;
    
    if (_syncingState) {
        [self startHandleUnsyncedObjects];
    }
    
}


#pragma mark - STMDataSyncing

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
            
            BOOL isFMDB = [self.persistenceDelegate storageForEntityName:entityName] == STMStorageTypeFMDB;
            NSString *objectVersion = isFMDB ? object[@"deviceTs"] : object[@"ts"];
            
            [self.subscriberDelegate haveUnsyncedObjectWithEntityName:entityName
                                                             itemData:object
                                                          itemVersion:objectVersion];
            
        }
        
    } else {
        
        [self finishHandleUnsyncedObjects];
        
    }

}

- (NSDictionary *)anyObjectToSend {
   
    NSDictionary *anyObjectToSend = nil;
    
    for (NSString *uploadableEntityName in [STMEntityController uploadableEntitiesNames]) {

        anyObjectToSend = [self findSyncableObjectWithEntityName:uploadableEntityName];
        
        if (anyObjectToSend) break;
        
    }
    
    return anyObjectToSend;
    
}

- (NSDictionary *)findSyncableObjectWithEntityName:(NSString *)entityName {
    
    NSDictionary *unsyncedObject = [self unsyncedObjectWithEntityName:entityName identifier:nil];
    
    if (unsyncedObject) {
        
        NSDictionary *resultObject = @{@"entityName"  : entityName,
                                       @"object"      : unsyncedObject};
        
        NSDictionary *unsyncedParent = [self anyUnsyncedParentForObject:unsyncedObject];
        
        if (unsyncedParent) {
            return unsyncedParent;
        } else {
            return resultObject;
        }
        
    }
    
    return nil;

}

- (NSDictionary *)unsyncedObjectWithEntityName:(NSString *)entityName identifier:(NSString *)identifier {

    NSError *error = nil;
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    [subpredicates addObject:[self predicateForUnsyncedObjectsWithEntityName:entityName]];
    
    if (identifier) {
        
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"id == %@", identifier]];
        
    }
    
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

- (NSDictionary *)anyUnsyncedParentForObject:(NSDictionary *)object {
    
    NSDictionary *anyUnsyncedParent = nil;
    
    NSArray *relKeys = [object.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", RELATIONSHIP_SUFFIX]];

    for (NSString *relKey in relKeys) {

        NSString *parentId = object[relKey];
        
        NSString *entityName = [relKey substringToIndex:(relKey.length - RELATIONSHIP_SUFFIX.length)];
        NSString *capFirstLetter = [entityName substringToIndex:1].capitalizedString;
        NSString *capEntityName = [entityName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
        entityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];
        
        NSDictionary *unsyncedParent = [self unsyncedObjectWithEntityName:entityName
                                                               identifier:parentId];
        
        if (unsyncedParent) {
            
            NSDictionary *resultObject = @{@"entityName"  : entityName,
                                           @"object"      : unsyncedParent};

            NSDictionary *unsyncedGrandParent = [self anyUnsyncedParentForObject:unsyncedParent];
            
            if (unsyncedGrandParent) {
                
                anyUnsyncedParent = unsyncedGrandParent;
                
            } else {
                
                anyUnsyncedParent = resultObject;

                break;

            }
            
        }
        
    }
    
    return anyUnsyncedParent;
    
}

- (void)declineFromSync:(NSDictionary *)object entityName:(NSString *)entityName{
    
    NSString *pk = object[@"id"];
    
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
    
    return [NSPredicate predicateWithFormat:@"NOT (id IN %@)", errored.allObjects];

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
