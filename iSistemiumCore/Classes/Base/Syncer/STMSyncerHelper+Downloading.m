//
//  STMSyncerHelper+Downloading.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMConstants.h"

#import "STMSyncerHelper+Private.h"
#import "STMSyncerHelper+Downloading.h"

#import "STMClientEntityController.h"
#import "STMEntityController.h"

@interface STMDataDownloadingState ()

@property (nonatomic, strong) NSMutableArray *entitySyncNames;

@end


@implementation STMDataDownloadingState
@end


@implementation STMSyncerHelper (Downloading)

@dynamic dataDownloadingOwner;

#pragma mark - variables


- (NSDictionary *)stcEntities {
    
    return [STMEntityController stcEntities];
    
}

#pragma mark - STMDataDownloading

- (id <STMDataSyncingState>)startDownloading {
    return [self startDownloading:nil];
}

- (id <STMDataSyncingState>)startDownloading:(NSArray <NSString *> *)entitiesNames {
    
    @synchronized (self) {
        
        if (self.downloadingState) return self.downloadingState;
        
        self.downloadingState = [[STMDataDownloadingState alloc] init];

        if (!entitiesNames) {
            
            NSMutableOrderedSet *entitiesNames = [NSMutableOrderedSet orderedSetWithObject:@"STMEntity"];
            
            if (self.stcEntities[@"STMSetting"]) [entitiesNames addObject:@"STMSetting"];
            
            [self.stcEntities enumerateKeysAndObjectsUsingBlock:^(NSString *name, STMEntity *entity, BOOL *stop) {
                if (entity.url) [entitiesNames addObject:name];
            }];
            
            self.downloadingState.entitySyncNames = entitiesNames.array.mutableCopy;
            
        } else {
            
            self.downloadingState.entitySyncNames = entitiesNames.mutableCopy;
            
        }
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED];

        NSLog(@"will download %@ entities", @(self.downloadingState.entitySyncNames.count));
        
        [self tryDownloadEntityName:self.downloadingState.entitySyncNames.firstObject];
        
        return self.downloadingState;
    }
    
}

- (void)stopDownloading:(NSString *)stopMessage {
    
    NSLogMethodName;
    [self receivingDidFinishWithError:nil];
    
}

- (void)dataReceivedSuccessfully:(BOOL)success entityName:(NSString *)entityName result:(NSArray *)result offset:(NSString *)offset pageSize:(NSUInteger)pageSize error:(NSError *)error {
    
    if (success) {
        
        [self parseFindAllAckResponseData:result entityName:entityName offset:offset pageSize:pageSize];
        
    } else {
        
        [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
        
    }

}


#pragma mark - private methods


- (void)logErrorMessage:(NSString *)errorMessage {
    
    // TODO: need a method in owner's protocol
    [[STMLogger sharedLogger] saveLogMessageWithText:errorMessage numType:STMLogMessageTypeError];
    
}

- (void)tryDownloadEntityName:(NSString *)entityName {
    
    if (!self.downloadingState) {
        // TODO: call finish download
        return;
    }

    NSLog(@"tryDownloadEntityName: %@", entityName);
    
    // TODO: not sure it is needed
    if (![self.dataDownloadingOwner downloadingTransportIsReady]) {
        
        [self receivingDidFinishWithError:@"socket transport is not ready"];
        return;
        
    }
    
    STMEntity *entity = self.stcEntities[entityName];
    
    NSString *lastKnownEtag = [STMClientEntityController clientEntityWithName:entity.name][@"eTag"];
    
    if (!lastKnownEtag || [lastKnownEtag isEqual:[NSNull null]]) lastKnownEtag = @"*";
                           
    [self.dataDownloadingOwner receiveData:entityName offset:lastKnownEtag];
    
}

- (void)doneDownloadingEntityName:(NSString *)entityName {
    [self doneDownloadingEntityName:entityName errorMessage:nil];
}

- (void)doneDownloadingEntityName:(NSString *)entityName errorMessage:(NSString *)errorMessage {
    
    if (errorMessage) {
        [self logErrorMessage:[NSString stringWithFormat:@"doneDownloadingEntityName error: %@", errorMessage]];
    }
    
    @synchronized (self) {
        
        [self.downloadingState.entitySyncNames removeObject:entityName];
        
        NSUInteger remainCount = self.downloadingState.entitySyncNames.count;
        NSLog(@"remain %@ entities to receive", @(remainCount));
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                    userInfo:@{@"countdownValue": @(remainCount)}];
        
        if (self.downloadingState && self.downloadingState.entitySyncNames.count) {
            return [self tryDownloadEntityName:self.downloadingState.entitySyncNames.firstObject];
        }
        
    }
    
    [self receivingDidFinishWithError:nil];

    
}

- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        [self logErrorMessage:[NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString]];
    }
    
    NSLogMethodName;
    
    self.downloadingState = nil;
    [self.dataDownloadingOwner dataDownloadingFinished];
    
}



#pragma mark findAll ack handler

- (void)parseFindAllAckResponseData:(NSArray *)responseData entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    if (!entityName) {
        return [self receivingDidFinishWithError:@"called parseFindAllAckResponseData with empty entityName"];
    }
        
    if (!responseData.count) {
        NSLog(@"    %@: have no new data", entityName);
        return [self doneDownloadingEntityName:entityName];
    }
        
    if (!offset) {
        NSLog(@"    %@: receive data w/o offset", entityName);
        return [self doneDownloadingEntityName:entityName];
    }
    
    NSDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]};
    
    [self.persistenceDelegate mergeMany:entityName attributeArray:responseData options:options]
    .thenInBackground(^(NSArray *data){
        
        [self findAllResultMergedWithSuccess:data entityName:entityName offset:offset pageSize:pageSize];
        
    }).catch(^(NSError *error){
        
        [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
        
    });
    
}


- (void)findAllResultMergedWithSuccess:(NSArray *)result entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    NSLog(@"    %@: get %@ objects", entityName, @(result.count));
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                userInfo:@{@"count": @(result.count),
                                           @"entityName": entityName
                                           }];
    
    if (result.count < pageSize) {
        
        NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
        
        STMEntity *entity = self.stcEntities[entityName];
        
        [STMClientEntityController clientEntityWithName:entity.name setETag:offset];
        
        [self doneDownloadingEntityName:entityName];
        
    } else {
        
        [self.dataDownloadingOwner receiveData:entityName offset:offset];
        
    }
    
}


@end
