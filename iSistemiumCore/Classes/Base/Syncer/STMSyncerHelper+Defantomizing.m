//
//  STMSyncerHelper+Defantomizing.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Defantomizing.h"
#import "STMSyncerHelper+Private.h"

#import "STMConstants.h"
#import "STMEntityController.h"

@interface STMSyncerHelperDefantomizing ()

@property (nonatomic,strong) NSMutableSet *failToResolveIds;
@property (atomic) NSUInteger fantomsCount;
@property (nonatomic,strong) NSMutableArray *pending;
@property (nonatomic,strong) NSMutableArray *queued;

@end


@implementation STMSyncerHelperDefantomizing

- (instancetype)init {

    self = [super init];
    
    if (self) {
        self.failToResolveIds = [NSMutableSet set];
        self.pending = [NSMutableArray array];
        self.queued = [NSMutableArray array];
    }
    
    return self;
    
}

//- (NSUInteger)fantomsCount {
//    return self.queued.count + self.pending.count;
//}


@end


@implementation STMSyncerHelper (Defantomizing)

@dynamic defantomizingOwner;
@dynamic persistenceFantomsDelegate;


#pragma mark - defantomizing

- (void)startDefantomization {

    STMSyncerHelperDefantomizing *defantomizing = [[STMSyncerHelperDefantomizing alloc] init];;

    self.defantomizing = defantomizing;
    
    for (NSString *entityName in [STMEntityController entityNamesWithResolveFantoms]) {
        
        NSDictionary *entity = [STMEntityController stcEntities][entityName];
        
        if (![STMFunctions isNotNull:entity[@"url"]]) {
            NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
            continue;
        }

        NSArray *results = [self.persistenceFantomsDelegate findAllFantomsIdsSync:entityName
                                                                     excludingIds:self.defantomizing.failToResolveIds.allObjects];
                
        if (!results.count) continue;
            
        NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);
        
        for (NSDictionary *fantomId in results) {
            [defantomizing.queued addObject:@{@"entityName":entityName, @"id":fantomId}];
        }
     
    }
    
    defantomizing.fantomsCount = defantomizing.queued.count;
    if (!defantomizing.fantomsCount) return [self defantomizingFinished];
        
    NSLog(@"DEFANTOMIZING_START");
    
    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_START
                                userInfo:@{@"fantomsCount": @(defantomizing.fantomsCount)}];
    
    
    for (NSDictionary *fantomDic in defantomizing.queued) {
        [self.defantomizingOwner defantomizeObject:fantomDic];
    }
    
}

- (void)stopDefantomization {
    [self defantomizingFinished];
}

- (void)defantomize:(NSDictionary *)fantomDic success:(BOOL)success entityName:(NSString *)entityName result:(NSDictionary *)result error:(NSError *)error {
    
    if (!success) {
        return [self defantomizingObject:fantomDic error:error.localizedDescription];
    }
    
    if (!entityName) {
        return [self defantomizingObject:fantomDic error:@"SyncerHelper defantimize got empty entityName"];
    }
    
    [self.persistenceFantomsDelegate mergeFantomAsync:entityName attributes:result callback:^
     (STMP_ASYNC_DICTIONARY_RESULT_CALLBACK_ARGS) {
         
         if (error) {
             return [self defantomizingObject:fantomDic error:error.localizedDescription];
         }
         
         NSLog(@"successfully defantomize %@ %@", entityName, fantomDic[@"id"]);
         
         [self fantomsCountDecrease];
         
    }];


}


#pragma mark - Private helpers

- (void)defantomizingObject:(NSDictionary *)fantomDic error:(NSString *)errorString {
    
    NSLog(@"defantomize error: %@", errorString);
    
    BOOL deleteObject = [errorString hasSuffix:@"404"] || [errorString hasSuffix:@"403"];
    
    NSString *fantomId = fantomDic[@"id"];

    if (deleteObject) {
        
        NSString *entityName = fantomDic[@"entityName"];
        
        NSLog(@"delete fantom %@ %@", entityName, fantomId);
        
        [self.persistenceFantomsDelegate destroyFantomSync:entityName identifier:fantomId];
        
    } else {
        
        @synchronized (self) {
            [self.defantomizing.failToResolveIds addObject:fantomId];
        }
        
    }
    
    [self fantomsCountDecrease];
    
    return;
    
}

- (void)fantomsCountDecrease {
    
    @synchronized (self) {
        if (!--self.defantomizing.fantomsCount) {
            
            [self startDefantomization];
            
        } else {
            
            [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_UPDATE
                                        userInfo:@{@"fantomsCount": @(self.defantomizing.fantomsCount)}];
            
        }
    }
    
    
}

- (void)defantomizingFinished {
    
    NSLog(@"DEFANTOMIZING_FINISHED");
    
    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_FINISH userInfo:nil];
    
    self.defantomizing = nil;
    
    [self.defantomizingOwner defantomizingFinished];
    
}


@end
