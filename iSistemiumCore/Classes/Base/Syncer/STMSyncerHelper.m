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

@property (nonatomic, strong) NSMutableArray *notFoundFantomsArray;

@property (nonatomic, strong) void (^unsyncedSubscriptionBlock)(NSString *entity, NSDictionary *itemData, NSString *itemVersion);


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

- (NSMutableArray *)notFoundFantomsArray {
    
    if (!_notFoundFantomsArray) {
        _notFoundFantomsArray = @[].mutableCopy;
    }
    return _notFoundFantomsArray;
    
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
    
    NSArray <NSDictionary *> *unsyncedObjects = [self unsyncedObjects];
    
    NSLog(@"%@ unsynced total", @(unsyncedObjects.count));
    
}

- (NSArray <NSDictionary *> *)unsyncedObjects {
    
    NSMutableArray *unsyncedObjects = @[].mutableCopy;
    
    NSArray *uploadableEntitiesNames = [STMEntityController uploadableEntitiesNames];
    
    for (NSString *entityName in uploadableEntitiesNames) {
        
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


@end
