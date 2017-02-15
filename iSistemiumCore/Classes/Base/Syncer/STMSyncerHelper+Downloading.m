//
//  STMSyncerHelper+Downloading.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Private.h"
#import "STMSyncerHelper+Downloading.h"

#import "STMClientEntityController.h"
#import "STMEntityController.h"

#import <objc/runtime.h>


@interface STMDataDownloadingState ()

@property (nonatomic, strong) NSMutableArray *entitySyncNames;
@property (nonatomic) NSUInteger entityCount;
@property (nonatomic) BOOL entitiesWasUpdated;
@property (nonatomic) NSUInteger fetchLimit;
@end


@implementation STMDataDownloadingState

- (instancetype)initWithFetchLimit:(NSUInteger)fetchLimit {
    
    self = [super init];
    
    self.entitySyncNames = [NSMutableArray array];
    self.fetchLimit = fetchLimit;
    
    return self;
}

- (void)setEntityCount:(NSUInteger)entityCount {

    _entityCount = entityCount;
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                userInfo:@{@"countdownValue": @(entityCount)}];
    
}


@end


@implementation STMSyncerHelper (Downloading)

@dynamic dataDownloadingOwner;

#pragma mark - variables


- (NSDictionary *)stcEntities {
    
    return [STMEntityController stcEntities];
    
}

#pragma mark - STMDataDownloading

- (void)startDownloading {
    [self startDownloading:nil];
}

- (void)startDownloading:(NSArray <NSString *> *)entitiesNames {
    
    @synchronized (self) {
        
        if (self.downloadingState) return;

        NSDictionary *settings = [self.session.settingsController currentSettingsForGroup:@"syncer"];
        NSUInteger fetchLimit = [settings[@"fetchLimit"] integerValue];
        
        self.downloadingState = [[STMDataDownloadingState alloc] initWithFetchLimit:fetchLimit];

    }
    
//    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self receiveStarted];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!entitiesNames || [entitiesNames containsObject:@"STMEntity"]) {
            
            self.downloadingState.entityCount = 1;
            
            [self checkConditionForReceivingEntityWithName:@"STMEntity"];
            
        } else {
            
            self.downloadingState.entitySyncNames = entitiesNames.mutableCopy;
            self.downloadingState.entityCount = self.downloadingState.entitySyncNames.count;
            
            [self checkConditionForReceivingEntityWithName:self.downloadingState.entitySyncNames.firstObject];
            
        }
    });
    
}

- (void)stopDownloading:(NSString *)stopMessage {
    
    [self entityCountDecreaseWithError:stopMessage
                       finishReceiving:YES];
    
    self.downloadingState = nil;
    
}

- (void)dataReceivedSuccessfully:(BOOL)success entityName:(NSString *)entityName result:(NSArray *)result offset:(NSString *)offset pageSize:(NSUInteger)pageSize error:(NSError *)error {
    
    if (success) {
        
        [self parseFindAllAckResponseData:result entityName:entityName offset:offset pageSize:pageSize];
        
    } else {
        
        if (self.downloadingState.entityCount > 0) {
            [self entityCountDecreaseWithError:error.localizedDescription];
        } else {
            [self receivingDidFinishWithError:error.localizedDescription];
        }
        
    }

}


#pragma mark - private methods

- (void)receiveStarted {
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED userInfo:nil];
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
    
    
    if (![self.persistenceDelegate isConcreteEntityName:entityName]) {
        
        NSString *errorMessage = [NSString stringWithFormat:@"    %@: does not exist in local data model", entityName];
        return [self entityCountDecreaseWithError:errorMessage];
        
    }
    
    STMEntity *entity = self.stcEntities[entityName];
    NSString *resource = [entity resource];
            
    if (!resource) {
        
        NSString *errorMessage = [NSString stringWithFormat:@"    %@: have no url", entityName];
        return [self entityCountDecreaseWithError:errorMessage];
        
    }
    
    NSString *lastKnownEtag = [STMClientEntityController clientEntityWithName:entity.name][@"eTag"];
    
    if (!lastKnownEtag || [lastKnownEtag isEqual:[NSNull null]]) lastKnownEtag = @"*";
                           
    [self receiveDataForEntityName:entityName eTag:lastKnownEtag];
    
}


- (void)receiveDataForEntityName:(NSString *)entityName eTag:(NSString * _Nonnull)eTag {
    
    [self.dataDownloadingOwner receiveData:entityName
                                    offset:eTag
                                  pageSize:self.downloadingState.fetchLimit];

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
        [self.session.logger saveLogMessageWithText:logMessage
                                            numType:STMLogMessageTypeError];
        
    } else {
        
        [self saveReceiveDate];

    }
    
    if (finishReceiving || --self.downloadingState.entityCount) {
        
        NSLog(@"remain %@ entities to receive", @(self.downloadingState.entityCount));
        
        // TODO: pass here entityName to avoid async problems
        
        NSString *entityName = self.downloadingState.entitySyncNames.firstObject;
        
        if (entityName) {
            [self.downloadingState.entitySyncNames removeObject:entityName];
        }
        
        if (self.downloadingState.entitySyncNames.firstObject) {
            
            return [self checkConditionForReceivingEntityWithName:self.downloadingState.entitySyncNames.firstObject];
            
        }
            
    }
        
    NSLog(@"remain %@ entities to receive", @(self.downloadingState.entityCount));
    
    [self receivingDidFinishWithError:nil];

    
}

- (void)receiveNoContentStatusForEntityWithName:(NSString *)entityName {
    
    if (![entityName isEqualToString:@"STMEntity"]) {
        return [self entityCountDecrease];
    }

    
    // Special hanling of first time receiving entities
    // TODO: move this somewhere else
    
    if (self.downloadingState.entitiesWasUpdated) {
     
        [self.dataDownloadingOwner entitiesWasUpdated];
        self.downloadingState.entitiesWasUpdated = NO;
        
    }
    
    NSMutableArray *entitiesNames = [self.stcEntities keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return [obj valueForKey:@"url"] ? YES : NO;
    }].allObjects.mutableCopy;
    
    [entitiesNames removeObject:entityName];
    
    NSUInteger settingsIndex = [entitiesNames indexOfObject:@"STMSetting"];
    if (settingsIndex != NSNotFound) [entitiesNames exchangeObjectAtIndex:settingsIndex
                                                        withObjectAtIndex:0];
    
    self.downloadingState.entitySyncNames = entitiesNames;
    self.downloadingState.entityCount = entitiesNames.count;
    
    [self postAsyncMainQueueNotification:@"entitiesReceivingDidFinish" userInfo:nil];
    
    [self checkConditionForReceivingEntityWithName:self.downloadingState.entitySyncNames.firstObject];
 
    
}

- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        
        NSString *logMessage = [NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
    NSLog(@"receivingDidFinish");
    
    self.downloadingState = nil;
    [self.dataDownloadingOwner dataDownloadingFinished];

    
}

- (void)saveReceiveDate {
    
    if (!self.session.uid) return;
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSString *key = [@"receiveDate" stringByAppendingString:self.session.uid];
    
    NSString *receiveDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:receiveDateString forKey:key];
    [defaults synchronize];
    
}


#pragma mark findAll ack handler

- (void)parseFindAllAckResponseData:(NSArray *)responseData entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    if (!entityName) {
        NSString *logMessage = [NSString stringWithFormat:@"ERROR: unknown entity response: %@", entityName];
        return [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
    }
        
    if (!responseData.count) {
        NSLog(@"    %@: have no new data", entityName);
        return [self receiveNoContentStatusForEntityWithName:entityName];
    }
        
    if (!offset) {
        NSLog(@"    %@: receive data w/o offset", entityName);
        return [self receiveNoContentStatusForEntityWithName:entityName];
    }
    
    NSDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]};
    
    [self.persistenceDelegate mergeMany:entityName attributeArray:responseData options:options]
    .thenInBackground(^(NSArray *data){
        
        [self findAllResultMergedWithSuccess:data entityName:entityName offset:offset pageSize:pageSize];
        
    }).catch(^(NSError *error){
        
        [self entityCountDecreaseWithError:error.localizedDescription];
        
    });
    
}


- (void)findAllResultMergedWithSuccess:(NSArray *)result entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    NSLog(@"    %@: get %@ objects", entityName, @(result.count));
    
    if ([entityName isEqualToString:@"STMEntity"]) {
        self.downloadingState.entitiesWasUpdated = YES;
    }
    
    if (result.count < pageSize) {
        
        NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
        
        [self receiveNoContentStatusForEntityWithName:entityName];
        
        STMEntity *entity = self.stcEntities[entityName];
        
        [STMClientEntityController clientEntityWithName:entity.name setETag:offset];
        
    } else {
        
        [self receiveDataForEntityName:entityName eTag:offset];
        
    }
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                userInfo:@{@"count": @(result.count),
                                           @"entityName": entityName
                                           }];
    
}


@end
