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


@interface STMSyncerHelper()

@property (nonatomic, strong) NSMutableArray *fantomsArray;
@property (nonatomic, strong) NSMutableArray *notFoundFantomsArray;


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

- (NSMutableArray *)fantomsArray {
    
    if (!_fantomsArray) {
        _fantomsArray = @[].mutableCopy;
    }
    return _fantomsArray;
    
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
}


#pragma mark - defantomizing

- (void)findFantomsWithCompletionHandler:(void (^)(NSArray <NSDictionary *> *fantomsArray))completionHandler {
    
    NSSet *entityNamesWithResolveFantoms = [STMEntityController entityNamesWithResolveFantoms];
    
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
        
        if (results.count > 0) {
            
            NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);

            for (NSDictionary *fantomObject in results) {
                
                if (!fantomObject[@"id"]) {

                    NSLog(@"fantomObject have no id: %@", fantomObject);
                    continue;
                    
                }

                NSDictionary *fantomDic = @{@"entityName":entityName, @"id":fantomObject[@"id"]};

                if ([self.notFoundFantomsArray containsObject:fantomDic] || [self.fantomsArray containsObject:fantomDic]) {
                    continue;
                }

                [self.fantomsArray addObject:fantomDic];

            }

        } else {
            NSLog(@"have no fantoms for %@", entityName);
        }
        
    }
    
    if (self.fantomsArray.count > 0) {
        
        NSLog(@"DEFANTOMIZING_START");
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_START
                                                            object:self
                                                          userInfo:@{@"fantomsCount": @(self.fantomsArray.count)}];

        completionHandler(self.fantomsArray);
        
    } else {
        completionHandler(nil);
    }
    
}

- (void)defantomizingFinished {
    
    NSLog(@"DEFANTOMIZING_FINISHED");

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_FINISH
                                                        object:self
                                                      userInfo:nil];
    
    self.fantomsArray = nil;
    self.notFoundFantomsArray = nil;

}


#pragma mark - STMDataSyncing

- (NSString *)subscribeUnsyncedWithCompletionHandler:(void (^)(NSString *entity, NSDictionary *itemData, NSString *itemVersion))completionHandler {
    return nil;
}

- (BOOL)unSubscribe:(NSString *)subscriptionId {
    return YES;
}

- (BOOL)setSynced:(NSString *)entity itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    return YES;
}


@end
