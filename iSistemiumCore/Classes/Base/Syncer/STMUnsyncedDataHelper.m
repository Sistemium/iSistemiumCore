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
    [self finishHandleUnsyncedObjects];
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
