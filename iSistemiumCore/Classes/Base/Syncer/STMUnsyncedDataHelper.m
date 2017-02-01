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


@interface STMUnsyncedDataHelper()

@property (nonatomic, strong) NSString *subscriptionId;
@property (nonatomic, strong) NSMutableDictionary *failToSyncObjects;
@property (nonatomic) BOOL isHandlingUnsyncedObjects;


@end


@implementation STMUnsyncedDataHelper

@synthesize subscriberDelegate = _subscriberDelegate;

- (NSMutableDictionary *)failToSyncObjects {
    
    if (!_failToSyncObjects) {
        _failToSyncObjects = @{}.mutableCopy;
    }
    return _failToSyncObjects;
    
}


#pragma mark - STMDataSyncing

- (void)setSubscriberDelegate:(id <STMDataSyncingSubscriber>)subscriberDelegate {
    
    _subscriberDelegate = subscriberDelegate;
    
    (_subscriberDelegate) ? [self subscribeUnsynced] : [self unsubscribeUnsynced];
    
}

- (void)subscribeUnsynced {
    
    if (self.subscriberDelegate) {
        
        for (NSString *entityName in [STMEntityController uploadableEntitiesNames]) {
            
            NSPredicate *predicate = [self predicateForUnsyncedObjectsWithEntityName:entityName];
            
            self.subscriptionId = [self.persistenceDelegate observeEntity:entityName predicate:predicate callback:^(NSArray * _Nullable data) {
                
                NSLog(@"observeEntity %@ data count %u", entityName, data.count);
                [self startHandleUnsyncedObjects];
                
            }];
            
        }
        
        [self startHandleUnsyncedObjects];
        
    }
    
}

- (void)unsubscribeUnsynced {
    [self.persistenceDelegate cancelSubscription:self.subscriptionId];
}

- (BOOL)setSynced:(BOOL)success entity:(NSString *)entity itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    
    if (!success) {
        
        if (itemData && itemData[@"id"]) {
            self.failToSyncObjects[itemData[@"id"]] = itemData;
        }
        NSLog(@"failToSync %@ %@", itemData[@"entityName"], itemData[@"id"]);
        
    } else {
        
        if (itemVersion) {
            
            NSError *error;
            [self.persistenceDelegate mergeSync:entity
                                     attributes:itemData
                                        options:@{STMPersistingOptionLts: itemVersion}
                                          error:&error];
            
        } else {
            NSLog(@"No itemVersion for %@ %@", entity, itemData[@"id"]);
        }
        
    }
    
    [self sendNextUnsyncedObject];
    
    return YES;
    
}

- (NSUInteger)numberOfUnsyncedObjects {
    return 0;
}

#pragma mark - handle unsynced objects

- (void)startHandleUnsyncedObjects {
    
    if (self.isHandlingUnsyncedObjects) {
        return;
    }
    
    self.isHandlingUnsyncedObjects = YES;
    
    [self sendNextUnsyncedObject];
    
}

- (void)sendNextUnsyncedObject {

    NSDictionary *objectToSend = [self anyObjectToSend];
    
    if (objectToSend) {
        
        NSString *entityName = objectToSend[@"entityName"];
        NSDictionary *object = objectToSend[@"object"];
        
        NSLog(@"object to send: %@ %@", entityName, object[@"id"]);
        
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
        
        NSDictionary *unsyncedObject = [self anyUnsyncedObjectWithEntityName:uploadableEntityName];
        
        if (unsyncedObject) {
            
            NSDictionary *resultObject = @{@"entityName"  : uploadableEntityName,
                                           @"object"      : unsyncedObject};
            
            NSDictionary *unsyncedParent = [self anyUnsyncedParentForObject:unsyncedObject];
            anyObjectToSend = (unsyncedParent) ? unsyncedParent : resultObject;
            
            break;
            
        }
        
    }
    
    return anyObjectToSend;
    
}

- (NSDictionary *)anyUnsyncedObjectWithEntityName:(NSString *)entityName {
    return [self unsyncedObjectWithEntityName:entityName identifier:nil];
}

- (NSDictionary *)unsyncedObjectWithEntityName:(NSString *)entityName identifier:(NSString *)identifier {

    NSError *error = nil;
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    [subpredicates addObject:[self predicateForUnsyncedObjectsWithEntityName:entityName]];
    
    if (identifier) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"id == %@", identifier]];
    }

    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    NSArray *result = [self.persistenceDelegate findAllSync:entityName
                                                  predicate:predicate
                                                    options:@{STMPersistingOptionPageSize : @1}
                                                      error:&error];
    return result.firstObject;

}

- (NSDictionary *)anyUnsyncedParentForObject:(NSDictionary *)object {
    
    NSDictionary *anyUnsyncedParent = nil;
    
    NSArray *relKeys = [object.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", RELATIONSHIP_SUFFIX]];

    for (NSString *relKey in relKeys) {
        
        NSString *entityName = [relKey substringToIndex:(relKey.length - RELATIONSHIP_SUFFIX.length)];
        NSString *capFirstLetter = [entityName substringToIndex:1].capitalizedString;
        NSString *capEntityName = [entityName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
        entityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];

        NSString *parentId = object[relKey];
        
        NSDictionary *unsyncedParent = [self unsyncedObjectWithEntityName:entityName
                                                               identifier:parentId];
        
        if (unsyncedParent) {
            
            NSDictionary *resultObject = @{@"entityName"  : entityName,
                                           @"object"      : unsyncedParent};

            NSDictionary *unsyncedGrandParent = [self anyUnsyncedParentForObject:unsyncedParent];
            anyUnsyncedParent = (unsyncedGrandParent) ? unsyncedGrandParent : resultObject;
            
            break;
            
        }
        
    }
    
    return anyUnsyncedParent;
    
}

- (void)finishHandleUnsyncedObjects {
    
    self.isHandlingUnsyncedObjects = NO;
    self.failToSyncObjects = nil;
    
}

- (NSPredicate *)predicateForUnsyncedObjectsWithEntityName:(NSString *)entityName {
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
        
        NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                           forGroup:@"syncer"];
        
        NSArray *logMessageSyncTypes = [[STMLogger sharedLogger] syncingTypesForSettingType:uploadLogType];
        
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
        
    }
    
#warning predicates could be different if object in CoreData or STMFMDB
    [subpredicates addObject:[NSPredicate predicateWithFormat:@"deviceTs > lts OR lts == nil"]];
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    return predicate;
    
}


@end
