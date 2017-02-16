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
@property (nonatomic) NSUInteger entityCount;
@property (nonatomic) BOOL entitiesWasUpdated;

@end


@implementation STMDataDownloadingState

- (instancetype)init {
    
    self = [super init];
    
    self.entitySyncNames = [NSMutableArray array];
    
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

        self.downloadingState.entityCount = self.downloadingState.entitySyncNames.count;
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED];

        NSLog(@"will download %@ entities", @(self.downloadingState.entityCount));
        
        [self tryDownloadEntityName:self.downloadingState.entitySyncNames.firstObject];
        
        return self.downloadingState;
    }
    
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

- (void)entityCountDecrease {
    [self entityCountDecreaseWithError:nil];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage {
    [self entityCountDecreaseWithError:errorMessage finishReceiving:NO];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage finishReceiving:(BOOL)finishReceiving {
    
    if (errorMessage) {
        
        [self logErrorMessage:[NSString stringWithFormat:@"entityCountDecreaseWithError: %@", errorMessage]];
        
    }
    
    if (finishReceiving || --self.downloadingState.entityCount) {
        
        NSLog(@"remain %@ entities to receive", @(self.downloadingState.entityCount));
        
        // TODO: pass here entityName to avoid async problems
        
        NSString *entityName = self.downloadingState.entitySyncNames.firstObject;
        
        if (entityName) {
            [self.downloadingState.entitySyncNames removeObject:entityName];
        }
        
        if (self.downloadingState.entitySyncNames.firstObject) {
            
            return [self tryDownloadEntityName:self.downloadingState.entitySyncNames.firstObject];
            
        }
            
    }
        
    NSLog(@"remain %@ entities to receive", @(self.downloadingState.entityCount));
    
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
        NSString *logMessage = [NSString stringWithFormat:@"ERROR: unknown entity response: %@", entityName];
        return [self logErrorMessage:logMessage];
    }
        
    if (!responseData.count) {
        NSLog(@"    %@: have no new data", entityName);
        return [self entityCountDecrease];
    }
        
    if (!offset) {
        NSLog(@"    %@: receive data w/o offset", entityName);
        return [self entityCountDecrease];
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
    
    if (result.count < pageSize) {
        
        NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
        
        STMEntity *entity = self.stcEntities[entityName];
        
        [STMClientEntityController clientEntityWithName:entity.name setETag:offset];
        
        [self entityCountDecrease];
        
    } else {
        
        [self.dataDownloadingOwner receiveData:entityName offset:offset];
        
    }
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                userInfo:@{@"count": @(result.count),
                                           @"entityName": entityName
                                           }];
    
}


@end
