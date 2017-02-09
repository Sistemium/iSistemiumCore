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
#import "STMCoreObjectsController.h"

#import <objc/runtime.h>


@interface STMSyncerHelperDefantomizingProperties : NSObject

@property (nonatomic, strong) NSMutableArray *failToResolveFantomsArray;
@property (atomic) NSUInteger fantomsCount;


@end


@implementation STMSyncerHelperDefantomizingProperties

- (instancetype)init {

    self = [super init];
    
    if (self) {
        _failToResolveFantomsArray = @[].mutableCopy;
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
        
        NSArray *results = [self.persistenceFantomsDelegate findAllFantomsSync:entityName];
        
        NSArray *failToResolveFantomsIds = [[self defantomizingProperties].failToResolveFantomsArray valueForKeyPath:@"id"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (id IN %@)", failToResolveFantomsIds];
        
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_START
                                                                object:self
                                                              userInfo:@{@"fantomsCount": @(fantomsArray.count)}];
            
        });
    
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
        
        NSDictionary *context = @{@"type"  : DEFANTOMIZING_CONTEXT,
                                  @"object": fantomDic};
        
        [self receiveFindAckWithResponse:result
                              entityName:entityName
                                 context:context];
        
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
    
    if (deleteObject) {
        
        NSString *entityName = fantomDic[@"entityName"];
        NSString *objId = fantomDic[@"id"];
        
        NSLog(@"delete fantom %@ %@", entityName, objId);
        
        [self.persistenceFantomsDelegate destroyFantomSync:entityName
                                         identifier:objId];
        
    } else {
        
        @synchronized (self) {
            [[self defantomizingProperties].failToResolveFantomsArray addObject:fantomDic];
        }
        
    }
    
    [self fantomsCountDecrease];
    
    return;
    
}

- (void)fantomsCountDecrease {
    
    if (!--[self defantomizingProperties].fantomsCount) {
        
        [self startDefantomization];
        
    } else {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_UPDATE
                                                                object:self
                                                              userInfo:@{@"fantomsCount": @([self defantomizingProperties].fantomsCount)}];
            
            
        }];
        
    }
    
}

- (void)defantomizingFinished {
    
    NSLog(@"DEFANTOMIZING_FINISHED");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_FINISH
                                                            object:self
                                                          userInfo:nil];
        
    });
    
    // do not nil object used in syncronized()
    [[self defantomizingProperties].failToResolveFantomsArray removeAllObjects];
    
    [self.defantomizingOwner defantomizingFinished];
    
}


#pragma mark find ack handler

- (void)receiveFindAckWithResponse:(NSDictionary *)response entityName:(NSString *)entityName context:(NSDictionary *)context {
    
    NSData *xid = [STMFunctions xidDataFromXidString:response[@"id"]];
    
    [self parseFindAckResponseData:response
                    withEntityName:entityName
                               xid:xid
                           context:context];
    
}

- (void)parseFindAckResponseData:(NSDictionary *)responseData withEntityName:(NSString *)entityName xid:(NSData *)xid context:(NSDictionary *)context {
    
    BOOL defantomizing = [context[@"type"] isEqualToString:DEFANTOMIZING_CONTEXT];
    
    //    NSLog(@"find responseData %@", responseData);
    
    if (!entityName) {
        
        NSString *errorMessage = @"Syncer parseFindAckResponseData !entityName";
        
        if (defantomizing) {
            
            [self defantomizingObject:context[@"object"]
                                error:errorMessage];
            
        } else {
            
            [[STMLogger sharedLogger] saveLogMessageWithText:errorMessage
                                                     numType:STMLogMessageTypeError];
            
        }
        
        return;
        
    }
    
    NSError *error = nil;
    
    [self.persistenceFantomsDelegate mergeFantomSync:entityName
                                          attributes:responseData
                                               error:&error];
        
    if (defantomizing) {
        
        NSDictionary *object = context[@"object"];
        
        if (!error) {
            
            NSLog(@"successfully defantomize %@ %@", object[@"entityName"], object[@"id"]);
            
            [self fantomsCountDecrease];
            
        } else {
            
            [self defantomizingObject:object
                                error:error.localizedDescription];
            
        }
        
    }

}


@end
