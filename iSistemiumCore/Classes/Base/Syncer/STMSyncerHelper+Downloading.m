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
#import "STMLogger.h"
#import "STMFunctions.h"

// TODO: this could depend on device
#define STM_DOWNLOADING_IN_PROGRESS_MAX 4

@interface STMDataDownloadingState ()

@property (nonatomic, strong) NSMutableArray <NSString *> *entitySyncNames;
@property (nonatomic, strong) NSMutableArray <NSString *> *pendingEntities;
@property (nonatomic, strong) NSMutableSet <NSString *> *inProgressEntities;
@property (nonatomic) NSUInteger inProgressMax;

@end


@implementation STMDataDownloadingState
@end


@implementation STMSyncerHelper (Downloading)

@dynamic dataDownloadingOwner;

#pragma mark - STMDataDownloading

- (id <STMDataSyncingState>)startDownloading {
    return [self startDownloading:nil];
}

- (id <STMDataSyncingState>)startDownloading:(NSArray <NSString *> *)entitiesNames {
    
    @synchronized (self) {
        
        if (self.downloadingState) return self.downloadingState;
        
        STMDataDownloadingState *downloadingState = [[STMDataDownloadingState alloc] init];

        downloadingState.inProgressMax = STM_DOWNLOADING_IN_PROGRESS_MAX;
        
        if (!entitiesNames) {
            
            NSMutableOrderedSet *entitiesNames = [NSMutableOrderedSet orderedSetWithObject:@"STMEntity"];
            
            if ([STMEntityController entityWithName:@"STMSetting"]) [entitiesNames addObject:@"STMSetting"];
            
            [[STMEntityController stcEntities] enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *entity, BOOL *stop) {
                if ([STMFunctions isNotNull:entity[@"url"]]) [entitiesNames addObject:name];
            }];
            
            downloadingState.entitySyncNames = entitiesNames.reversedOrderedSet.array.mutableCopy;
            
        } else {
            
            downloadingState.entitySyncNames = entitiesNames.mutableCopy;
            
        }
        
        downloadingState.pendingEntities = downloadingState.entitySyncNames.mutableCopy;

        self.downloadingState = downloadingState;
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED];

        NSLog(@"will download %@ entities", @(downloadingState.entitySyncNames.count));
        
        downloadingState.inProgressEntities = [NSMutableSet set];
        [self popPendingEntity];
        
        return downloadingState;
    }
    
}


- (void)popPendingEntity {
    
    NSString *nextEntity = [STMFunctions popArray:self.downloadingState.pendingEntities];
    
    if (!nextEntity) return;
        
    @synchronized (self) {
        [self.downloadingState.inProgressEntities addObject:nextEntity];
    }
    
    [self tryDownloadEntityName:nextEntity];
    
    if (self.downloadingState.inProgressEntities.count < self.downloadingState.inProgressMax) {
        [self popPendingEntity];
    }
    
}

- (void)stopDownloading {
    
    NSLogMethodName;
    [self receivingDidFinishWithError:nil];
    
}

- (void)dataReceivedSuccessfully:(BOOL)success entityName:(NSString *)entityName result:(NSArray *)result offset:(NSString *)offset pageSize:(NSUInteger)pageSize error:(NSError *)error {
    
    if (!success) {
        return [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
    }
    
    if (!entityName) {
        return [self receivingDidFinishWithError:@"called parseFindAllAckResponseData with empty entityName"];
    }
    
    if (!result.count) {
        NSLog(@"    %@: have no new data", entityName);
        return [self doneDownloadingEntityName:entityName];
    }
    
    if (!offset) {
        NSLog(@"    %@: receive data w/o offset", entityName);
        return [self doneDownloadingEntityName:entityName];
    }
    
    [self.persistenceDelegate mergeManyAsync:entityName attributeArray:result options:@{STMPersistingOptionLtsNow} completionHandler:^(BOOL success, NSArray<NSDictionary *> *result, NSError *error) {
        
        if (!success) {
            return [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
        }
        
        [self findAllResultMergedWithSuccess:result entityName:entityName offset:offset pageSize:pageSize];
        
    }];

}


#pragma mark - private methods


- (void)logErrorMessage:(NSString *)errorMessage {
    
    // TODO: need a method in owner's protocol
    [[STMLogger sharedLogger] saveLogMessageWithText:errorMessage numType:STMLogMessageTypeError];
    
}

- (void)tryDownloadEntityName:(NSString *)entityName {

    NSLog(@"tryDownloadEntityName: %@", entityName);
    
    NSString *lastKnownEtag = [STMClientEntityController clientEntityWithName:entityName][@"eTag"];
    
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
    
    STMDataDownloadingState *state = self.downloadingState;
    
    @synchronized (self) {
        
        [state.entitySyncNames removeObject:entityName];
        [state.inProgressEntities removeObject:entityName];
        
        NSUInteger remainCount = state.entitySyncNames.count;
        NSLog(@"remain %@ entities to receive with %@ in progress", @(remainCount), @(state.inProgressEntities.count));
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                    userInfo:@{@"countdownValue": @(remainCount)}];
        
        if (state && remainCount) return [self popPendingEntity];
        
    }
    
    [self receivingDidFinishWithError:nil];
    
}

- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        [self logErrorMessage:[NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString]];
    } else {
        NSLog(@"receivingDidFinish");
    }
    
    self.downloadingState = nil;
    [self.dataDownloadingOwner dataDownloadingFinished];
    
}



#pragma mark findAll ack handler

- (void)findAllResultMergedWithSuccess:(NSArray *)result entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    NSLog(@"    %@: get %@ objects", entityName, @(result.count));
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                userInfo:@{@"count": @(result.count),
                                           @"entityName": entityName
                                           }];
    
    if (result.count < pageSize) {
        
        NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
        
        [STMClientEntityController clientEntityWithName:entityName setETag:offset];
        
        [self doneDownloadingEntityName:entityName];
        
    } else {
        
        [self.dataDownloadingOwner receiveData:entityName offset:offset];
        
    }
    
}


@end
