//
//  STMSyncerHelper+Defantomizing.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Defantomizing.h"
#import "STMConstants.h"
#import "STMEntityController.h"

#import <objc/runtime.h>


@interface STMSyncerHelperDefantomizingProperties : NSObject

@property (nonatomic, strong) NSMutableArray *failToResolveFantomsIdsArray;
@property (atomic) NSUInteger fantomsCount;


@end


@implementation STMSyncerHelperDefantomizingProperties

- (instancetype)init {

    self = [super init];
    
    if (self) {
        _failToResolveFantomsIdsArray = @[].mutableCopy;
    }
    return self;
    
}


@end


static void *defantomizingPropertiesVar;
static void *defantomizingOwnerVar;
static void *persistenceFantomsDelegateVar;

@implementation STMSyncerHelper (Defantomizing)


- (STMSyncerHelperDefantomizingProperties *)defantomizingProperties {
    
    STMSyncerHelperDefantomizingProperties *result = objc_getAssociatedObject(self, &defantomizingPropertiesVar);
    
    if (!result) {
        
        result = [[STMSyncerHelperDefantomizingProperties alloc] init];
        objc_setAssociatedObject(self, &defantomizingPropertiesVar, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    }
    
    return result;

}

- (id <STMDefantomizingOwner>)defantomizingOwner {
    
    id <STMDefantomizingOwner> result = objc_getAssociatedObject(self, &defantomizingOwnerVar);
    
    return result;
    
}

- (void)setDefantomizingOwner:(id<STMDefantomizingOwner>)defantomizingOwner {
    objc_setAssociatedObject(self, &defantomizingOwnerVar, defantomizingOwner, OBJC_ASSOCIATION_ASSIGN);
}

- (id <STMPersistingFantoms>)persistenceFantomsDelegate {
    
    id <STMPersistingFantoms> result = objc_getAssociatedObject(self, &persistenceFantomsDelegateVar);
    
    return result;

}

- (void)setPersistenceFantomsDelegate:(id<STMPersistingFantoms>)persistenceFantomsDelegate {
    objc_setAssociatedObject(self, &persistenceFantomsDelegateVar, persistenceFantomsDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark - defantomizing

- (void)startDefantomization {
    
    NSMutableArray <NSDictionary *> *fantomsArray = @[].mutableCopy;
    
    NSArray *entityNamesWithResolveFantoms = [STMEntityController entityNamesWithResolveFantoms];
    
    for (NSString *entityName in entityNamesWithResolveFantoms) {
        
        STMEntity *entity = [STMEntityController stcEntities][entityName];
        
        if (!entity.url) {
            
            NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
            continue;
            
        }

        NSArray *results = [self.persistenceFantomsDelegate findAllFantomsIdsSync:entityName
                                                                     excludingIds:[self defantomizingProperties].failToResolveFantomsIdsArray];
                
        if (results.count > 0) {
            
            NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);
            
            for (NSDictionary *fantomId in results) {
                
                NSDictionary *fantomDic = @{@"entityName":entityName, @"id":fantomId};
                [fantomsArray addObject:fantomDic];
                
            }
            
        } else {
            //            NSLog(@"have no fantoms for %@", entityName);
        }
        
    }
    
    if (fantomsArray.count > 0) {
        
        NSLog(@"DEFANTOMIZING_START");
        
        [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_START
                                    userInfo:@{@"fantomsCount": @(fantomsArray.count)}];
        
        [self defantomizingProperties].fantomsCount = fantomsArray.count;
        
        for (NSDictionary *fantomDic in fantomsArray) {
            [self.defantomizingOwner defantomizeObject:fantomDic];
        }
        
    } else {
        [self defantomizingFinished];
    }
    
}

- (void)stopDefantomization {
    [self defantomizingFinished];
}

- (void)defantomize:(NSDictionary *)fantomDic success:(BOOL)success entityName:(NSString *)entityName result:(NSDictionary *)result error:(NSError *)error {
    
    if (success) {
        
        [self receiveFindAckWithResponse:result
                              entityName:entityName
                               fantomDic:fantomDic];
        
    } else {
        
        [self defantomizingObject:fantomDic
                            error:error.localizedDescription];
        
    }

}

- (void)defantomizingObject:(NSDictionary *)fantomDic error:(NSString *)errorString {
    
    BOOL deleteObject = [errorString hasSuffix:@"404"] || [errorString hasSuffix:@"403"];
    
    [self defantomizingObject:fantomDic error:errorString deleteObject:deleteObject];
    
}

- (void)defantomizingObject:(NSDictionary *)fantomDic error:(NSString *)errorString deleteObject:(BOOL)deleteObject {
    
    NSLog(@"defantomize error: %@", errorString);

    NSString *fantomId = fantomDic[@"id"];

    if (deleteObject) {
        
        NSString *entityName = fantomDic[@"entityName"];
        
        NSLog(@"delete fantom %@ %@", entityName, fantomId);
        
        [self.persistenceFantomsDelegate destroyFantomSync:entityName
                                         identifier:fantomId];
        
    } else {
        
        @synchronized (self) {
            [[self defantomizingProperties].failToResolveFantomsIdsArray addObject:fantomId];
        }
        
    }
    
    [self fantomsCountDecrease];
    
    return;
    
}

- (void)fantomsCountDecrease {
    
    if (!--[self defantomizingProperties].fantomsCount) {
        
        [self startDefantomization];
        
    } else {
        
        [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_UPDATE
                                    userInfo:@{@"fantomsCount": @([self defantomizingProperties].fantomsCount)}];
        
    }
    
}

- (void)defantomizingFinished {
    
    NSLog(@"DEFANTOMIZING_FINISHED");
    
    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_FINISH userInfo:nil];
    
    // do not nil object used in syncronized()
    [[self defantomizingProperties].failToResolveFantomsIdsArray removeAllObjects];
    
    [self.defantomizingOwner defantomizingFinished];
    
}


#pragma mark find ack handler

- (void)receiveFindAckWithResponse:(NSDictionary *)response entityName:(NSString *)entityName fantomDic:(NSDictionary *)fantomDic {
    
    if (!entityName) {
        
        NSString *errorMessage = @"Syncer parseFindAckResponseData !entityName";
        
        return [self defantomizingObject:fantomDic error:errorMessage];
    }
    
    [self.persistenceFantomsDelegate mergeFantomAsync:entityName attributes:response callback:^
     (STMP_ASYNC_DICTIONARY_RESULT_CALLBACK_ARGS) {
         
         if (error) {
             return [self defantomizingObject:fantomDic error:error.localizedDescription];
         }
         
         NSLog(@"successfully defantomize %@ %@", fantomDic[@"entityName"], fantomDic[@"id"]);
         
         [self fantomsCountDecrease];
         
     }];

    
}


@end
