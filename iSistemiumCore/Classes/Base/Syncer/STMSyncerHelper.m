//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"

#import "STMConstants.h"
#import "STMEntityController.h"
#import "STMCoreObjectsController.h"


@interface STMSyncerHelper()

@property (nonatomic, strong) NSMutableArray <NSDictionary *> *unsyncedObjects;
@property (nonatomic, strong) NSMutableArray *notFoundFantomsArray;
@property (nonatomic, strong) NSMutableDictionary *failToSyncObjects;

@property (nonatomic, strong) void (^unsyncedSubscriptionBlock)(NSString *entity, NSDictionary *itemData, NSString *itemVersion);
@property (nonatomic) BOOL isHandlingUnsyncedObjects;


@end


@implementation STMSyncerHelper


- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {
    [self addObservers];
}

- (NSMutableArray <NSDictionary *> *)unsyncedObjects {
    
    if (!_unsyncedObjects) {
        _unsyncedObjects = @[].mutableCopy;
    }
    return _unsyncedObjects;
    
}

- (NSMutableArray *)notFoundFantomsArray {
    
    if (!_notFoundFantomsArray) {
        _notFoundFantomsArray = @[].mutableCopy;
    }
    return _notFoundFantomsArray;
    
}

- (NSMutableDictionary *)failToSyncObjects {
    
    if (!_failToSyncObjects) {
        _failToSyncObjects = @{}.mutableCopy;
    }
    return _failToSyncObjects;
    
}


#pragma mark - observers

- (void)addObservers {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(persisterHaveUnsyncedObjects:)
                                                 name:NOTIFICATION_PERSISTER_HAVE_UNSYNCED
                                               object:nil];
    
}

- (void)removeObservers {
    
#warning - have to remove observers if helper dealloc/nullify
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)persisterHaveUnsyncedObjects:(NSNotification *)notification {
    
    NSLogMethodName;
    
    if (self.unsyncedSubscriptionBlock) {
        [self handleUnsyncedObjects];
    }
    
}


#pragma mark - defantomizing

- (void)findFantomsWithCompletionHandler:(void (^)(NSArray <NSDictionary *> *fantomsArray))completionHandler {
    
    NSMutableArray <NSDictionary *> *fantomsArray = @[].mutableCopy;
    
    NSArray *entityNamesWithResolveFantoms = [STMEntityController entityNamesWithResolveFantoms];
    
    for (NSString *entityName in entityNamesWithResolveFantoms) {
        
        STMEntity *entity = [STMEntityController stcEntities][entityName];
        
        if (!entity.url) {
            
            NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
            continue;
            
        }

        NSError *error = nil;
        NSArray *results = [self.persistenceDelegate findAllSync:entityName
                                                       predicate:nil
                                                         options:@{@"fantoms":@YES}
                                                           error:&error];
        
        NSArray *notFoundFantomsIds = [self.notFoundFantomsArray valueForKeyPath:@"id"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (id IN %@)", notFoundFantomsIds];
        
        results = [results filteredArrayUsingPredicate:predicate];

        if (results.count > 0) {
            
            NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);

            for (NSDictionary *fantomObject in results) {
                
                if (!fantomObject[@"id"]) {

                    NSLog(@"fantomObject have no id: %@", fantomObject);
                    continue;
                    
                }

                NSDictionary *fantomDic = @{@"entityName":entityName, @"id":fantomObject[@"id"]};
                [fantomsArray addObject:fantomDic];

            }

        } else {
//            NSLog(@"have no fantoms for %@", entityName);
        }
        
    }
    
    if (fantomsArray.count > 0) {
        
        NSLog(@"DEFANTOMIZING_START");
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_START
                                                            object:self
                                                          userInfo:@{@"fantomsCount": @(fantomsArray.count)}];

        completionHandler(fantomsArray);
        
    } else {
        completionHandler(nil);
    }
    
}

- (void)defantomizeErrorWithObject:(NSDictionary *)fantomDic {
    
    @synchronized (self.notFoundFantomsArray) {
        [self.notFoundFantomsArray addObject:fantomDic];
    }
    
}

- (void)defantomizingFinished {
    
    NSLog(@"DEFANTOMIZING_FINISHED");

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_FINISH
                                                        object:self
                                                      userInfo:nil];
    
    self.notFoundFantomsArray = nil;

}


#pragma mark - STMDataSyncing

- (NSString *)subscribeUnsyncedWithCompletionHandler:(void (^)(NSString *entity, NSDictionary *itemData, NSString *itemVersion))completionHandler {
    
    self.unsyncedSubscriptionBlock = completionHandler;
    
    return nil; // have to return subscriptionId if it will be needed

}

- (BOOL)unSubscribe:(NSString *)subscriptionId {
    
    self.unsyncedSubscriptionBlock = nil;
    return YES;
    
}

- (BOOL)setSynced:(NSString *)entity itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    return YES;
}


#pragma mark - handle unsynced objects

- (void)handleUnsyncedObjects {
    
    self.unsyncedObjects = [self findUnsyncedObjects];
    
    NSLog(@"%@ unsynced total", @(self.unsyncedObjects.count));

    [self sendNextUnsyncedObject];
    
}

- (void)sendNextUnsyncedObject {
    
    NSDictionary *objectToSend = [self findObjectToSendFromSyncArray:self.unsyncedObjects];
    
    [self.unsyncedObjects removeObject:objectToSend];
    
    self.unsyncedSubscriptionBlock(objectToSend[@"entityName"], objectToSend, nil);

}

- (NSMutableArray <NSDictionary *> *)findUnsyncedObjects {
    
    NSMutableArray *unsyncedObjects = @[].mutableCopy;
    
    NSArray *uploadableEntitiesNames = [STMEntityController uploadableEntitiesNames];
    
    for (NSString *entityName in uploadableEntitiesNames) {
        
        if ([entityName isEqualToString:@"STMLogMessage"]) {
            continue;
        }
        
        if ([[STMCoreObjectsController localDataModelEntityNames] containsObject:entityName]) {
            
            NSError *error = nil;
            NSPredicate *predicate = [self predicateForUnsyncedObjectsWithEntityName:entityName];

            NSArray <NSDictionary *> *result = [self.persistenceDelegate findAllSync:entityName
                                                                           predicate:predicate
                                                                             options:nil
                                                                               error:&error];
            
            if (result.count > 0) {
            
                NSMutableArray *finalArray = @[].mutableCopy;
                
                [result enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                   
                    NSMutableDictionary *object = obj.mutableCopy;
                    object[@"entityName"] = entityName;
                    
                    [finalArray addObject:object];
                    
                }];
                
                NSLog(@"%@ unsynced %@", @(finalArray.count), entityName);
                
                [unsyncedObjects addObjectsFromArray:finalArray];

            }
            
        }

    }

    return unsyncedObjects;
    
}

- (NSPredicate *)predicateForUnsyncedObjectsWithEntityName:(NSString *)entityName {
    
    NSMutableArray *subpredicates = @[].mutableCopy;
    
    if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
        
        NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                           forGroup:@"syncer"];
        
        NSArray *logMessageSyncTypes = [[STMLogger sharedLogger] syncingTypesForSettingType:uploadLogType];
        
//        [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
        
        NSMutableArray *syncTypesSubpredicates = @[].mutableCopy;
        
        for (NSString *type in logMessageSyncTypes) {
            [syncTypesSubpredicates addObject:[NSPredicate predicateWithFormat:@"type == %@", type]];
        }
        
        [subpredicates addObject:[NSCompoundPredicate orPredicateWithSubpredicates:syncTypesSubpredicates]];
        
    }
    
    [subpredicates addObject:[NSPredicate predicateWithFormat:@"deviceTs > lts"]];
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];

    return predicate;
    
}

- (NSDictionary *)findObjectToSendFromSyncArray:(NSArray <NSDictionary *> *)syncArray {
    
    NSDictionary *object = syncArray.firstObject;
    
    if (!object) {
        return nil;
    }

    NSDictionary *unsyncedObject = [self unsyncedObjectForObject:object
                                                     inSyncArray:syncArray];
    
    return unsyncedObject;
    
}

- (NSDictionary *)unsyncedObjectForObject:(NSDictionary *)object inSyncArray:(NSArray <NSDictionary *> *)syncArray {
    
    NSMutableArray *syncArrayCopy = syncArray.mutableCopy;
    [syncArrayCopy removeObject:object];
    
    NSString *entityName = object[@"entityName"];
    NSDictionary *relationships = [STMCoreObjectsController toOneRelationshipsForEntityName:entityName];
    
    BOOL needToGoDeeper = NO;
    
    for (NSString *relName in relationships.allKeys) {
        
        NSString *relObjectKey = [relName stringByAppendingString:RELATIONSHIP_SUFFIX];
        NSString *relObjectId = object[relObjectKey];
        
        if (!relObjectId) {
            continue;
        }
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"id = %@", relObjectId];
        NSDictionary *relObject = [syncArrayCopy filteredArrayUsingPredicate:predicate].firstObject;
        
        if (!relObject) {
            continue;
        }
        
        object = relObject;
        needToGoDeeper = YES;
        break;
        
    }

    return (needToGoDeeper) ? [self unsyncedObjectForObject:object inSyncArray:syncArrayCopy] : object;
    
}









//- (NSDictionary *)findObjectToSendFirstFromSyncArray:(NSMutableArray <NSDictionary *> *)syncArray {
//    
//    NSDictionary *firstObject = syncArray.firstObject;
//    
//    if (firstObject) {
//        return [self checkRelationshipsObjectsForObject:firstObject fromSyncArray:syncArray];
//    } else {
//        return nil;
//    }
//    
//}
//
//- (NSDictionary *)checkRelationshipsObjectsForObject:(NSDictionary *)syncObject fromSyncArray:(NSMutableArray <NSDictionary *> *)syncArray {
//    
//    [syncArray removeObject:syncObject];
//    
//    NSString *syncObjectId = syncObject[@"id"];
//    
//    if ([self.failToSyncObjectsIds containsObject:syncObjectId]) {
//        
//        return [self findObjectToSendFirstFromSyncArray:syncArray];
//        
//    } else {
//        
//        NSString *entityName = syncObject[@"entityName"];
//        NSDictionary *relationships = [STMCoreObjectsController toOneRelationshipsForEntityName:entityName];
//        
//        BOOL shouldFindNext = NO;
//        
//        for (NSString *relName in relationships.allKeys) {
//            
//            NSString *relObjectKey = [relName stringByAppendingString:RELATIONSHIP_SUFFIX];
//            NSString *relObjectId = syncObject[relObjectKey];
//            
//            if (!relObjectId) {
//                continue;
//            }
//            
//            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"id = %@", relObjectId];
//            NSDictionary *relObject = [syncArray filteredArrayUsingPredicate:predicate].firstObject;
//            
//            if (!relObject) {
//                continue;
//            }
//
//            
///*
//            
//#warning !!! need to correctly get relObject
//            NSDictionary *relObject = [syncObject valueForKey:relName];
//            
//            if ([self.doNotSyncObjectIds containsObject:relObject[@"id"]]) {
//                
//                if (![self.doNotSyncObjectIds containsObject:syncObjectId]) {
//                    [self.doNotSyncObjectIds addObject:syncObjectId];
//                }
//                
//                NSString *log = [NSString stringWithFormat:@"%@ %@ have unsynced relation to %@", entityName, syncObjectId, @"relObject.entity.name"];
//                NSLog(@"%@", log);
//                
//                shouldFindNext = YES;
//                break;
//                
//            }
//            
//            if (![syncArray containsObject:relObject]) continue;
//            
//            NSEntityDescription *relObjectEntity = relObject.entity;
//            NSArray *checkingRelationships = [relObjectEntity relationshipsWithDestinationEntity:objectEntity];
//            
//            BOOL doBreak = NO;
//            
//            for (NSRelationshipDescription *relDesc in checkingRelationships) {
//                
//                if (!relDesc.isToMany) continue;
//                if (![[relObject valueForKey:relDesc.name] containsObject:syncObject]) continue;
//                
//                syncObject = [self checkRelationshipsObjectsForObject:relObject fromSyncArray:syncArray];
//                doBreak = YES;
//                break;
//                
//            }
//            
//            if (doBreak) break;
//*/
//            
//        }
//        return (shouldFindNext) ? [self findObjectToSendFirstFromSyncArray:syncArray] : syncObject;
// 
//    }
//    
//}


@end
