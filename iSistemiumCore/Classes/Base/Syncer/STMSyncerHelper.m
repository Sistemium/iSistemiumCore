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

@property (nonatomic, strong) void (^unsyncedSubscriptionBlock)(NSString *entityName, NSDictionary *itemData, NSString *itemVersion);
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
        [self startHandleUnsyncedObjects];
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

- (BOOL)setSynced:(BOOL)success entity:(NSString *)entity itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    
    if (!success) {
        
        self.failToSyncObjects[itemData[@"id"]] = itemData;
        NSLog(@"failToSync %@ %@", itemData[@"entityName"], itemData[@"id"]);
        
    }

    [self sendNextUnsyncedObject];
    
    return YES;
    
}


#pragma mark - handle unsynced objects

- (void)startHandleUnsyncedObjects {
    
    if (self.isHandlingUnsyncedObjects) {
        return;
    }
    
    self.isHandlingUnsyncedObjects = YES;
    
    self.unsyncedObjects = [self findUnsyncedObjects];
    
    NSLog(@"%@ unsynced total", @(self.unsyncedObjects.count));

    [self sendNextUnsyncedObject];
    
}

- (void)sendNextUnsyncedObject {
    
    NSError *error = nil;
    NSDictionary *objectToSend = [self findObjectToSendFromSyncArray:self.unsyncedObjects
                                                               error:&error];

    if (objectToSend) {
        
        [self.unsyncedObjects removeObject:objectToSend];
        
        NSLog(@"object to send: %@ %@", objectToSend[@"entityName"], objectToSend[@"id"]);
        
        if (self.unsyncedSubscriptionBlock) {
            self.unsyncedSubscriptionBlock(objectToSend[@"entityName"], objectToSend, nil);
        }
        
    } else {

        if (error) {
            
            [self sendNextUnsyncedObject];
            
        } else {

            [self finishHandleUnsyncedObjects];

        }

        
    }
    
}

- (void)finishHandleUnsyncedObjects {
    
    self.isHandlingUnsyncedObjects = NO;
    self.unsyncedObjects = nil;
    self.failToSyncObjects = nil;

}

- (NSMutableArray <NSDictionary *> *)findUnsyncedObjects {
    
    NSMutableArray *unsyncedObjects = @[].mutableCopy;
    
    NSArray *uploadableEntitiesNames = [STMEntityController uploadableEntitiesNames];
    
    for (NSString *entityName in uploadableEntitiesNames) {
        
#warning don't forget to remove it
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
            
                NSLog(@"%@ unsynced %@", @(result.count), entityName);
                [unsyncedObjects addObjectsFromArray:result];

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

- (NSDictionary *)findObjectToSendFromSyncArray:(NSArray <NSDictionary *> *)syncArray error:(NSError *__autoreleasing *)error {
    
    NSDictionary *object = syncArray.firstObject;
    
    if (!object) {
        return nil;
    }
    
    NSError *localError = nil;

    NSDictionary *unsyncedObject = [self unsyncedObjectForObject:object
                                                     inSyncArray:syncArray
                                                           error:&localError];
    
    if (localError) {

        [STMCoreObjectsController error:error
                            withMessage:nil];
        return nil;
        
    } else {
    
        return unsyncedObject;

    }
    
}

- (NSDictionary *)unsyncedObjectForObject:(NSDictionary *)object inSyncArray:(NSArray <NSDictionary *> *)syncArray error:(NSError *__autoreleasing *)error {
    
//    NSLog(@"check %@ %@", object[@"entityName"], object[@"id"]);
    
    NSMutableArray *syncArrayCopy = syncArray.mutableCopy;
    [syncArrayCopy removeObject:object];
    
    NSArray *relKeys = [object.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", RELATIONSHIP_SUFFIX]];
    
    BOOL needToGoDeeper = NO;
    BOOL declineFromSync = NO;
    
    for (NSString *relObjectKey in relKeys) {
        
        id relObjectId = object[relObjectKey];
        
        if (!relObjectId || [relObjectId isKindOfClass:[NSNull class]]) {
            continue;
        }
        
        if ([relObjectId isKindOfClass:[NSString class]] && [relObjectId isEqualToString:@""]) {
            continue;
        }
        
        if (self.failToSyncObjects[relObjectId]) {

            declineFromSync = YES;
            break;
            
        }
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"id = %@", relObjectId];
        NSDictionary *relObject = [syncArrayCopy filteredArrayUsingPredicate:predicate].firstObject;
        
        if (!relObject) {
            continue;
        }

/* move object to the head to avoid repeating checking chain of objects:

 instead of:
 check STMVisitAnswer -> check STMVisit -> check STMOutlet -> check STMPartner -> send STMPartner
 check STMVisitAnswer -> check STMVisit -> check STMOutlet -> send STMOutlet
 check STMVisitAnswer -> check STMVisit -> send STMVisit
 check STMVisitAnswer -> send STMVisitAnswer
 
 it will be like this:
 check STMVisitAnswer -> check STMVisit -> check STMOutlet -> check STMPartner -> send STMPartner
 check STMOutlet -> send STMOutlet
 check STMVisit -> send STMVisit
 check STMVisitAnswer -> send STMVisitAnswer
 
 use moveObjectToTheHeadOfUnsyncedObjectsArray if using syncArray.firstObject in findObjectToSendFromSyncArray:
 use moveObjectToTheTailOfUnsyncedObjectsArray if using syncArray.lastObject in findObjectToSendFromSyncArray:
 
*/
        [self moveObjectToTheHeadOfUnsyncedObjectsArray:object];
//        [self moveObjectToTheTailOfUnsyncedObjectsArray:object];

        object = relObject;
        needToGoDeeper = YES;
        break;
        
    }
    
    if (declineFromSync) {
        
        [self declineFromSyncObject:object error:error];
        return nil;
        
    } else {
        
        if (needToGoDeeper) {
            
            NSLog(@"-- needToGoDeeper --");
            
            NSError *localError = nil;
            NSDictionary *objectToSend = [self unsyncedObjectForObject:object
                                                           inSyncArray:syncArrayCopy
                                                                 error:&localError];

            if (objectToSend) {
                return objectToSend;
            }
            
            if (localError) {
                [self declineFromSyncObject:object error:error];
            }
            return nil;
            
        } else {
            
//            NSLog(@"sync ok for %@ %@", object[@"entityName"], object[@"id"]);
            return object;
            
        }
        
    }
    
}

- (void)moveObjectToTheHeadOfUnsyncedObjectsArray:(NSDictionary *)object {
    
    [STMFunctions moveObject:object
            toTheHeadOfArray:self.unsyncedObjects];

}

- (void)moveObjectToTheTailOfUnsyncedObjectsArray:(NSDictionary *)object {
    
    [STMFunctions moveObject:object
            toTheTailOfArray:self.unsyncedObjects];
    
}

- (void)declineFromSyncObject:(NSDictionary *)object error:(NSError **)error {
    
//    NSLog(@"declineFromSync %@ %@", object[@"entityName"], object[@"id"]);
    
    self.failToSyncObjects[object[@"id"]] = object;
    [self.unsyncedObjects removeObject:object];
    
    [STMCoreObjectsController error:error
                        withMessage:nil];

}


@end
