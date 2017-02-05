//
//  STMSyncerHelper+Downloading.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Downloading.h"

#import "STMCoreObjectsController.h"
#import "STMClientEntityController.h"
#import "STMEntityController.h"

#import <objc/runtime.h>


@interface STMDataDownloadingState : NSObject <STMDataSyncingState>

@end


@implementation STMDataDownloadingState

@synthesize isInSyncingProcess = _isInSyncingProcess;


@end

static void *entityCountVar;
static void *fetchLimitVar;
static void *temporaryETagVar;
static void *entitySyncNamesVar;
static void *receivingEntitiesNamesVar;
static void *stcEntitiesVar;
static void *downloadingStateVar;


@implementation STMSyncerHelper (Downloading)


#pragma mark - variables

- (NSUInteger)entityCount {
    
    id result = objc_getAssociatedObject(self, &entityCountVar);
    
    if (!result) {
        
//        result = @0;
//        self.entityCount = result;
        
    }
    
    return [result integerValue];

}

- (void)setEntityCount:(NSUInteger)entityCount {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                                            object:self
                                                          userInfo:@{@"countdownValue": @(entityCount)}];
        
    });
    
    objc_setAssociatedObject(self, &entityCountVar, @(entityCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (NSUInteger)fetchLimit {
    
    id result = objc_getAssociatedObject(self, &fetchLimitVar);
    
    if (!result) {
        
        NSDictionary *settings = [self.session.settingsController currentSettingsForGroup:@"syncer"];
        NSUInteger fetchLimit = [settings[@"fetchLimit"] integerValue];

        result = @(fetchLimit);
        objc_setAssociatedObject(self, &fetchLimitVar, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    }
    
    return [result integerValue];
    
}

- (NSMutableDictionary *)temporaryETag {
    
    NSMutableDictionary *result = objc_getAssociatedObject(self, &temporaryETagVar);
    
    if (!result) {
        
        result = @{}.mutableCopy;
        objc_setAssociatedObject(self, &temporaryETagVar, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    }
    
    return result;

}

- (NSMutableArray *)entitySyncNames {
    
    NSMutableArray *result = objc_getAssociatedObject(self, &entitySyncNamesVar);
    
    if (!result) {
        
        result = @[].mutableCopy;
        self.entitySyncNames = result;
        
    }
    
    return result;

}

- (void)setEntitySyncNames:(NSMutableArray *)entitySyncNames {
    objc_setAssociatedObject(self, &entitySyncNamesVar, entitySyncNames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)receivingEntitiesNames {
    
    NSArray *result = objc_getAssociatedObject(self, &receivingEntitiesNamesVar);
    
    if (!result) {
        
//        result = @[];
//        self.receivingEntitiesNames = result;

    }
    
    return result;
    
}

- (void)setReceivingEntitiesNames:(NSArray *)receivingEntitiesNames {
    objc_setAssociatedObject(self, &receivingEntitiesNamesVar, receivingEntitiesNames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)stcEntities {
    
    NSMutableDictionary *result = objc_getAssociatedObject(self, &stcEntitiesVar);
    
    if (!result) {
        
        result = [STMEntityController stcEntities].mutableCopy;
        self.stcEntities = result;
        
    }
    
    return result;
    
}

- (void)setStcEntities:(NSMutableArray *)stcEntities {
    objc_setAssociatedObject(self, &stcEntitiesVar, stcEntities, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id <STMDataSyncingState>)downloadingState {
    
    id <STMDataSyncingState> result = objc_getAssociatedObject(self, &downloadingStateVar);
    
    if (!result) {
        
    }
    
    return result;
    
}

- (void)setDownloadingState:(id <STMDataSyncingState>)downloadingState {
    objc_setAssociatedObject(self, &downloadingStateVar, downloadingState, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark - STMDataDownloading

- (void)startDownloading {
    
    self.downloadingState = [[STMDataDownloadingState alloc] init];
    [self receiveData];
    
}

- (void)stopDownloading:(NSString *)stopMessage {
    
    [self entityCountDecreaseWithError:stopMessage
                       finishReceiving:YES];
    
    self.downloadingState = nil;
    
}

- (void)dataReceivedSuccessfully:(BOOL)success entityName:(NSString *)entityName result:(NSArray *)result offset:(NSString *)offset pageSize:(NSUInteger)pageSize error:(NSError *)error {
    
    if (success) {
        
        [self parseFindAllAckResponseData:result
                               entityName:entityName
                                   offset:offset
                                 pageSize:pageSize];
        
    } else {
        
        if (self.entityCount > 0) {
            [self entityCountDecreaseWithError:error.localizedDescription];
        } else {
            [self receivingDidFinishWithError:error.localizedDescription];
        }
        
    }

}


#pragma mark - private methods

- (void)receiveData {
    
    if (!self.downloadingState.isInSyncingProcess) {
        
        self.downloadingState.isInSyncingProcess = YES;
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self receiveStarted];
        
        if (!self.receivingEntitiesNames || [self.receivingEntitiesNames containsObject:@"STMEntity"]) {
            
            self.entityCount = 1;
            
            [self checkConditionForReceivingEntityWithName:@"STMEntity"];
            
        } else {
            
            self.entitySyncNames = self.receivingEntitiesNames.mutableCopy;
            self.receivingEntitiesNames = nil;
            self.entityCount = self.entitySyncNames.count;
            
            [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
            
        }
        
    }
    
}

- (void)receiveStarted {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_RECEIVE_STARTED
                                                            object:self];
        
    });
    
}

- (void)receiveFinished {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_RECEIVE_FINISHED
                                                            object:self];
        
    });
    
}

- (void)checkConditionForReceivingEntityWithName:(NSString *)entityName {
    
    if (!self.downloadingState) {
        return;
    }

    NSLog(@"checkConditionForReceivingEntityWithName: %@", entityName);
    
    if (![self.dataDownloadingOwner downloadingTransportIsReady]) {
        
        [self receivingDidFinishWithError:@"socket transport is not ready"];
        return;
        
    }
    
    NSString *errorMessage = nil;
    
    STMEntity *entity = self.stcEntities[entityName];
    
    NSArray *localDataModelEntityNames = [STMCoreObjectsController localDataModelEntityNames];
    
    if (entity.roleName) {
        
        NSString *roleOwner = entity.roleOwner;
        NSString *roleOwnerEntityName = [ISISTEMIUM_PREFIX stringByAppendingString:roleOwner];
        
        if (![localDataModelEntityNames containsObject:roleOwnerEntityName]) {
            errorMessage = [NSString stringWithFormat:@"local data model have no %@ entity for relationship %@", roleOwnerEntityName, entityName];
        } else {
            
            NSString *roleName = entity.roleName;
            NSDictionary *ownerRelationships = [STMCoreObjectsController ownObjectRelationshipsForEntityName:roleOwnerEntityName];
            NSString *destinationEntityName = ownerRelationships[roleName];
            
            if (![localDataModelEntityNames containsObject:destinationEntityName]) {
                errorMessage = [NSString stringWithFormat:@"local data model have no %@ entity for relationship %@", destinationEntityName, entityName];
            }
            
        }
        
    }
    
    if (errorMessage) {
        
        [self entityCountDecreaseWithError:errorMessage];
        
    } else {
        
        if (entity.roleName || [localDataModelEntityNames containsObject:entityName]) {
            
            NSString *resource = [entity resource];
            
            if (resource) {
                
                STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:entity.name];
                
                NSString *eTag = clientEntity.eTag;
                eTag = eTag ? eTag : @"*";
                
                [self receiveDataForEntityName:entityName
                                          eTag:eTag];
                
            } else {
                
                NSString *errorMessage = [NSString stringWithFormat:@"    %@: have no url", entityName];
                [self entityCountDecreaseWithError:errorMessage];
                
            }
            
        } else {
            
            NSString *errorMessage = [NSString stringWithFormat:@"    %@: do not exist in local data model", entityName];
            [self entityCountDecreaseWithError:errorMessage];
            
        }
        
    }
    
}

- (void)receiveDataForEntityName:(NSString *)entityName eTag:(NSString * _Nonnull)eTag {
    
    [self.dataDownloadingOwner receiveData:entityName
                                    offset:eTag
                                  pageSize:self.fetchLimit];

}

- (void)entityCountDecrease {
    [self entityCountDecreaseWithError:nil];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage {
    [self entityCountDecreaseWithError:errorMessage finishReceiving:NO];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage finishReceiving:(BOOL)finishReceiving {
    
    if (errorMessage) {
        
        NSString *logMessage = [NSString stringWithFormat:@"entityCountDecreaseWithError: %@", errorMessage];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
    if (!finishReceiving && --self.entityCount) {
        
        NSLog(@"remain %@ entities to receive", @(self.entityCount));
        
        if (self.entitySyncNames.firstObject) [self.entitySyncNames removeObject:(id _Nonnull)self.entitySyncNames.firstObject];
        
        if (self.entitySyncNames.firstObject) {
            
            [self.document saveDocument:^(BOOL success) {}];
            
            [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
            
        } else {
            
            [self receivingDidFinish];
            
        }
        
    } else {
        
        NSLog(@"remain %@ entities to receive", @(self.entityCount));
        
        [self receivingDidFinish];
        
    }
    
}

- (void)receiveNoContentStatusForEntityWithName:(NSString *)entityName {
    
    if ([entityName isEqualToString:@"STMEntity"]) {

        [self.dataDownloadingOwner entitiesWasUpdated];
        
        self.stcEntities = nil;
        
        NSMutableArray *entitiesNames = [self.stcEntities keysOfEntriesPassingTest:^BOOL(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            return [obj valueForKey:@"url"] ? YES : NO;
        }].allObjects.mutableCopy;
        
        [entitiesNames removeObject:entityName];
        
        NSUInteger settingsIndex = [entitiesNames indexOfObject:@"STMSetting"];
        if (settingsIndex != NSNotFound) [entitiesNames exchangeObjectAtIndex:settingsIndex
                                                            withObjectAtIndex:0];
        
        self.entitySyncNames = entitiesNames;
        self.entityCount = entitiesNames.count;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"entitiesReceivingDidFinish"
                                                                object:self];
            
        });
        
        [self.document saveDocument:^(BOOL success) {}];
        
        [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
        
    } else {
        [self entityCountDecrease];
    }
    
}

- (void)fillETagWithTemporaryValueForEntityName:(NSString *)entityName {
    
    NSString *eTag = self.temporaryETag[entityName];
    STMEntity *entity = self.stcEntities[entityName];
    STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:entity.name];
    
    clientEntity.eTag = eTag;
    
}

- (void)nextReceiveEntityWithName:(NSString *)entityName {
    
    [self fillETagWithTemporaryValueForEntityName:entityName];
    [self checkConditionForReceivingEntityWithName:entityName];
    
}

- (void)receivingDidFinish {
    [self receivingDidFinishWithError:nil];
}

- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        
        NSString *logMessage = [NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    } else {
        
#warning - do it only if have no error or always?
        [self saveReceiveDate];
        
    }
    
    if (self.receivingEntitiesNames) {
        
        [self receiveData];
        
    } else {
        
        [self.dataDownloadingOwner dataDownloadingFinished];

        [self receiveFinished];

        self.downloadingState.isInSyncingProcess = NO;
        
    }
    
}

- (void)saveReceiveDate {
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSString *key = [@"receiveDate" stringByAppendingString:self.session.uid];
    
    NSString *receiveDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:receiveDateString forKey:key];
    [defaults synchronize];
    
}


#pragma mark findAll ack handler

- (void)parseFindAllAckResponseData:(NSArray *)responseData entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    if (entityName) {
        
        if (responseData.count > 0) {
            
            if (offset) {
                
                BOOL isLastPage = responseData.count < pageSize;
                
                if (entityName) self.temporaryETag[entityName] = offset;
                
                [self parseSocketFindAllResponseData:responseData
                                       forEntityName:entityName
                                          isLastPage:isLastPage];
                
            } else {
                
                NSLog(@"    %@: receive data w/o offset", entityName);
                [self receiveNoContentStatusForEntityWithName:entityName];
                
            }
            
        } else {
            
            NSLog(@"    %@: have no new data", entityName);
            [self receiveNoContentStatusForEntityWithName:entityName];
            
        }
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"ERROR: unknown entity response: %@", entityName];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
}

- (void)parseSocketFindAllResponseData:(NSArray *)data forEntityName:(NSString *)entityName isLastPage:(BOOL)isLastPage {
    
    STMEntity *entity = self.stcEntities[entityName];
    
    if (entity) {
        
        NSMutableDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]}.mutableCopy;
        
        NSString *roleName = entity.roleName;
        
        if (roleName) {
            options[@"roleName"] = roleName;
        }
        
        // sync
        //        NSError *error = nil;
        //        NSArray *result = [self.persistenceDelegate mergeManySync:entityName attributeArray:data options:options error:&error];
        //
        //        if (error) {
        //            [self findAllResultMergedWithError:error.localizedDescription];
        //        } else {
        //
        //            [self findAllResultMergedWithSuccess:data
        //                                      entityName:entityName
        //                                      isLastPage:isLastPage];
        //
        //        }
        
        // async
        [self.persistenceDelegate mergeManyAsync:entityName
                                  attributeArray:data
                                         options:options
                               completionHandler:^(BOOL success, NSArray *result, NSError *error) {
                                   
                                   if (success) {
                                       
                                       [self findAllResultMergedWithSuccess:data
                                                                 entityName:entityName
                                                                 isLastPage:isLastPage];
                                       
                                   } else {
                                       [self findAllResultMergedWithError:error.localizedDescription];
                                   }
                                   
                               }];
        
        // promised
        //        [self.persistenceDelegate mergeMany:entityName attributeArray:data options:options].then(^(NSArray *result){
        //
        //            [self findAllResultMergedWithSuccess:data
        //                                      entityName:entityName
        //                                      isLastPage:isLastPage];
        //
        //        }).catch(^(NSError *error){
        //
        //            [self findAllResultMergedWithError:error.localizedDescription];
        //
        //        });
        
        // old style — same as promised
        //        [STMCoreObjectsController processingOfDataArray:data withEntityName:entityName andRoleName:entity.roleName withCompletionHandler:^(BOOL success) {
        //
        //            if (success) {
        //
        //                [self findAllResultMergedWithSuccess:data
        //                                         entityName:entityName
        //                                         isLastPage:isLastPage];
        //
        //            } else {
        //
        //                NSString *errorString = [NSString stringWithFormat:@"error in processingOfDataArray:%@ withEntityName: %@", data, entityName];
        //                [self findAllResultMergedWithError:errorString];
        //
        //            }
        //
        //        }];
        
    }
    
}

- (void)findAllResultMergedWithSuccess:(NSArray *)result entityName:(NSString *)entityName isLastPage:(BOOL)isLastPage {
    
    NSLog(@"    %@: get %@ objects", entityName, @(result.count));
    
    if (isLastPage) {
        
        NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
        
        [self fillETagWithTemporaryValueForEntityName:entityName];
        [self receiveNoContentStatusForEntityWithName:entityName];
        
    } else {
        
        [self nextReceiveEntityWithName:entityName];
        
    }
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                                            object:self
                                                          userInfo:@{@"count"         :@(result.count),
                                                                     @"entityName"    :entityName}];
        
    }];
    
}

- (void)findAllResultMergedWithError:(NSString *)errorString {
    [self entityCountDecreaseWithError:errorString];
}


@end
