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

@interface STMDataDownloadingState ()

@property (nonatomic, strong) NSMutableArray *entitySyncNames;
@property (nonatomic, strong) NSMutableArray <NSString *> *pendingEntities;

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
        
        STMDataDownloadingState *downloadingState = [[STMDataDownloadingState alloc] init];

        if (!entitiesNames) {
            
            NSMutableOrderedSet *entitiesNames = [NSMutableOrderedSet orderedSetWithObject:@"STMEntity"];
            
            if (self.stcEntities[@"STMSetting"]) [entitiesNames addObject:@"STMSetting"];
            
            [self.stcEntities enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *entity, BOOL *stop) {
                if ([STMFunctions isNotNull:entity[@"url"]]) [entitiesNames addObject:name];
            }];
            
            downloadingState.entitySyncNames = entitiesNames.array.mutableCopy;
            
        } else {
            
            downloadingState.entitySyncNames = entitiesNames.mutableCopy;
            
        }
        
        downloadingState.pendingEntities = downloadingState.entitySyncNames.mutableCopy;

        self.downloadingState = downloadingState;
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED];

        NSLog(@"will download %@ entities", @(downloadingState.entitySyncNames.count));
        
        [self popPendingEntity];
        [self popPendingEntity];
        [self popPendingEntity];
        
        return downloadingState;
    }
    
}


- (void)popPendingEntity {
    @synchronized (self) {
        NSString *nextEntity = [STMFunctions popArray:self.downloadingState.pendingEntities];
        if (nextEntity) {
            [self tryDownloadEntityName:nextEntity];
        }
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
    
    NSDictionary *entity = self.stcEntities[entityName];
    
    NSString *lastKnownEtag = [STMClientEntityController clientEntityWithName:entity[@"name"]][@"eTag"];
    
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
            return [self popPendingEntity];
        }
        
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
        
        NSDictionary *entity = self.stcEntities[entityName];
        
        [STMClientEntityController clientEntityWithName:entity[@"name"] setETag:offset];
        
        [self doneDownloadingEntityName:entityName];
        
    } else {
        
        [self.dataDownloadingOwner receiveData:entityName offset:offset];
        
    }
    
}


@end
