//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"

/*
#import "STMCoreObjectsController.h"
#import "STMEntityController.h"
*/

@interface STMSyncerHelper() //<NSFetchedResultsControllerDelegate>

/*
@property (nonatomic, strong) NSMutableArray *resultsControllers;
@property (nonatomic, strong) NSArray *unsyncedObjects;
@property (nonatomic, strong) NSMutableArray *currentSyncObjects;
@property (nonatomic, strong) NSMutableArray *doNotSyncObjectXids;
@property (nonatomic, strong) NSMutableDictionary *syncDateDictionary;
*/

@end


@implementation STMSyncerHelper

/*
- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {
    [self reloadResultsControllers];
}

- (NSMutableArray *)doNotSyncObjectXids {
    
    if (!_doNotSyncObjectXids) {
        _doNotSyncObjectXids = @[].mutableCopy;
    }
    return _doNotSyncObjectXids;
    
}

- (NSMutableDictionary *)syncDateDictionary {
    
    if (!_syncDateDictionary) {
        _syncDateDictionary = @{}.mutableCopy;
    }
    return _syncDateDictionary;
    
}


#pragma mark - NSFetchedResultsController

- (void)reloadResultsControllers {
    
    self.resultsControllers = nil;
    [self performFetches];
    
}

- (void)performFetches {
    
    NSArray *entityNamesForSending = [STMEntityController uploadableEntitiesNames];
    
    self.resultsControllers = @[].mutableCopy;
    
    for (NSString *entityName in entityNamesForSending) {
        
        NSFetchedResultsController *rc = [self resultsControllerForEntityName:entityName];
        
        if (rc) {
            
            [self.resultsControllers addObject:rc];
            [rc performFetch:nil];
            
        }
        
    }
    
}

- (nullable NSFetchedResultsController *)resultsControllerForEntityName:(NSString *)entityName {
    
    if ([[STMCoreObjectsController localDataModelEntityNames] containsObject:entityName]) {
        
        STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:entityName];
        
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id"
                                                                  ascending:YES
                                                                   selector:@selector(compare:)]];
        request.includesSubentities = YES;
        
        NSMutableArray *subpredicates = @[].mutableCopy;
        
        if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
            
            NSArray *logMessageSyncTypes = [[STMLogger sharedLogger] syncingTypesForSettingType:[self uploadLogType]];
            
            [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
            
        }
        
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"(lts == %@ || deviceTs > lts)", nil]];
        
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
        
        NSManagedObjectContext *context = [STMCoreObjectsController document].managedObjectContext;
        
        NSFetchedResultsController *rc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                             managedObjectContext:context
                                                                               sectionNameKeyPath:nil
                                                                                        cacheName:nil];
        rc.delegate = self;
        
        return rc;
        
    } else {
        
        return nil;
        
    }
    
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_DID_CHANGE_CONTENT
                                                        object:self];
    
//    self.controllersDidChangeContent = YES;
    
}

- (NSString *)uploadLogType {
    
    NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                       forGroup:@"syncer"];
    return uploadLogType;
    
}

- (NSArray *)unsyncedObjects {
    
    if (!_unsyncedObjects) {

        NSArray *unsyncedObjects = [self.resultsControllers valueForKeyPath:@"@distinctUnionOfArrays.fetchedObjects"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (xid IN %@) AND NOT (xid IN %@)", self.doNotSyncObjectXids, self.syncDateDictionary.allKeys];
        
        _unsyncedObjects = [unsyncedObjects filteredArrayUsingPredicate:predicate];
        
        if (_unsyncedObjects.count > 0) {
            
            NSLog(@"have %@ objects to send via Socket", @(_unsyncedObjects.count));
            
            self.currentSyncObjects = _unsyncedObjects.mutableCopy;
            
        } else {
            
            self.currentSyncObjects = nil;
            
        }

    }
    return _unsyncedObjects;
    
}

- (id)objectToSend {

    [self unsyncedObjects]; // fill currentSyncObjects

    if (self.currentSyncObjects.count > 0) {
        
        STMDatum *syncObject = [self findObjectToSendFirstFromSyncArray:self.currentSyncObjects.mutableCopy];

        if (syncObject) {

            [self.currentSyncObjects removeObject:syncObject];

            if (syncObject.xid) {

                NSData *xid = syncObject.xid;

                if (![self.syncDateDictionary objectForKey:xid]) {

                    self.syncDateDictionary[xid] = (syncObject.deviceTs) ? syncObject.deviceTs : [NSDate date];
                    return syncObject;

                } else {

                    NSString *message = [NSString stringWithFormat:@"skip %@ %@, already trying to sync", syncObject.entity.name, syncObject.xid];
                    NSLog(@"%@", message);

                    return [self objectToSend];

                }

            } else {

                NSLog(@"    ERROR: sync object have no xid: %@", syncObject);
                return [self objectToSend];
                
            }
            
        } else {

            self.unsyncedObjects = nil; // refill currentSyncObjects
            return [self objectToSend];
        
        }
        
    } else {
        
        [self haveNoObjectsToSend];
        return nil;
        
    }
    
}

- (void)haveNoObjectsToSend {
    
//    self.currentSyncObjects = nil;
//    self.doNotSyncObjectXids = nil;
//    self.syncDateDictionary = nil;
    
}

- (STMDatum *)findObjectToSendFirstFromSyncArray:(NSMutableArray <STMDatum *> *)syncArray {
    
    if (syncArray.firstObject) {
        return [self checkRelationshipsObjectsForObject:syncArray.firstObject fromSyncArray:syncArray];
    } else {
        return nil;
    }
    
}

- (STMDatum *)checkRelationshipsObjectsForObject:(STMDatum *)syncObject fromSyncArray:(NSMutableArray <STMDatum *> *)syncArray {
    
    [syncArray removeObject:syncObject];
    
    if ([self.doNotSyncObjectXids containsObject:(NSData *)syncObject.xid]) {
        
        return [self findObjectToSendFirstFromSyncArray:syncArray];
        
    } else {
        
        NSEntityDescription *objectEntity = syncObject.entity;
        NSString *entityName = objectEntity.name;
        NSDictionary *relationships = [STMCoreObjectsController toOneRelationshipsForEntityName:entityName];
        
        BOOL shouldFindNext = NO;
        
        for (NSString *relName in relationships.allKeys) {
            
            STMDatum *relObject = [syncObject valueForKey:relName];
            
            if ([self.doNotSyncObjectXids containsObject:(NSData *)relObject.xid]) {
                
                if (![self.doNotSyncObjectXids containsObject:syncObject.xid]) {
                    [self.doNotSyncObjectXids addObject:(NSData *)syncObject.xid];
                }
                
                NSString *log = [NSString stringWithFormat:@"%@ %@ have unsynced relation to %@", syncObject.entity.name, syncObject.xid, relObject.entity.name];
                NSLog(@"%@", log);
                
                shouldFindNext = YES;
                break;
                
            }
            
            if (![syncArray containsObject:relObject]) continue;
            
            NSEntityDescription *relObjectEntity = relObject.entity;
            NSArray *checkingRelationships = [relObjectEntity relationshipsWithDestinationEntity:objectEntity];
            
            BOOL doBreak = NO;
            
            for (NSRelationshipDescription *relDesc in checkingRelationships) {
                
                if (!relDesc.isToMany) continue;
                if (![[relObject valueForKey:relDesc.name] containsObject:syncObject]) continue;
                
                syncObject = [self checkRelationshipsObjectsForObject:relObject fromSyncArray:syncArray];
                doBreak = YES;
                break;
                
            }
            
            if (doBreak) break;
            
        }
        return (shouldFindNext) ? [self findObjectToSendFirstFromSyncArray:syncArray] : syncObject;
        
    }
    
}
*/

@end
