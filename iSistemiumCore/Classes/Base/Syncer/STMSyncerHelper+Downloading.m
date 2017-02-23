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

#import "STMOperationQueue.h"

// TODO: this could depend on device
#define STM_DOWNLOADING_MAX_CONCURRENT STM_OPERATION_MAX_CONCURRENT_DEFAULT


@interface STMDownloadingOperation : STMOperation

@property (nonatomic,strong) NSString *entityName;
@property (nonatomic,strong) NSString *identifier;

- (instancetype)initWithEntityName:(NSString *)entityName;

@end


@interface STMDownloadingQueue : STMOperationQueue

@property (nonatomic,weak) STMSyncerHelper *owner;

@end


#pragma mark STMDownloadingQueue


@implementation STMDownloadingQueue

- (void)downloadEntityName:(NSString *)entityName {
    [self addOperation:[[STMDownloadingOperation asynchronousOperation] initWithEntityName:entityName]];
}

- (STMDownloadingOperation *)operationForEntityName:(NSString *)entityName {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entityName == %@", entityName];
    
    return [self.operations filteredArrayUsingPredicate:predicate].firstObject;
}

@end


#pragma mark STMDownloadingOperation


@implementation STMDownloadingOperation

- (STMDownloadingQueue *)dowlonadingQueue {
    return (STMDownloadingQueue *)self.queue;
}

- (instancetype)initWithEntityName:(NSString *)entityName {
    self = [self init];
    self.entityName = entityName;
    return self;
}

- (void)start {
    
    [super start];
    
    NSLog(@"start downloadEntityName: %@", self.entityName);
    
    NSString *lastKnownEtag = [STMClientEntityController clientEntityWithName:self.entityName][@"eTag"];
    
    if (![STMFunctions isNotNull:lastKnownEtag]) lastKnownEtag = @"*";
    
    [self.dowlonadingQueue.owner.dataDownloadingOwner receiveData:self.entityName offset:lastKnownEtag];
    
}

@end


#pragma mark - Category implementation


@interface STMDataDownloadingState ()

@property (nonatomic, strong) STMDownloadingQueue *queue;

@end



@implementation STMDataDownloadingState
@end


@implementation STMSyncerHelper (Downloading)

@dynamic dataDownloadingOwner;


#pragma mark - STMDataDownloading protocol


- (id <STMDataSyncingState>)startDownloading {
    return [self startDownloading:nil];
}


- (id <STMDataSyncingState>)startDownloading:(NSArray <NSString *> *)entitiesNames {
    
    @synchronized (self) {
        
        if (self.downloadingState) return self.downloadingState;
        
        STMDataDownloadingState *state = [[STMDataDownloadingState alloc] init];
        self.downloadingState = state;
        
        state.queue = [STMDownloadingQueue queueWithDispatchQueue:self.dispatchQueue
                                                    maxConcurrent:STM_DOWNLOADING_MAX_CONCURRENT];
        state.queue.owner = self;
        state.queue.suspended = YES;
        
        if (!entitiesNames) {
            
            NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSetWithObject:STM_ENTITY_NAME];
            
            if ([STMEntityController entityWithName:@"STMSetting"]) [names addObject:@"STMSetting"];
            
            [[STMEntityController stcEntities] enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *entity, BOOL *stop) {
                if ([STMFunctions isNotNull:entity[@"url"]]) [names addObject:name];
            }];
            
            entitiesNames = names.reversedOrderedSet.array.copy;
            
        }

        for (NSString *entityName in entitiesNames) [state.queue downloadEntityName:entityName];
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED];

        NSLog(@"will download %@ entities", @(state.queue.operationCount));
        
        state.queue.suspended = NO;
        
        return state;
        
    }
    
}


- (void)stopDownloading {
    
    NSLogMethodName;
    
    [self.downloadingState.queue cancelAllOperations];
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
    
    [self.persistenceDelegate mergeManyAsync:entityName attributeArray:result options:@{STMPersistingOptionLtsNow} completionHandler:^(STMP_ASYNC_ARRAY_RESULT_CALLBACK_ARGS) {
        
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


- (void)doneDownloadingEntityName:(NSString *)entityName {
    [self doneDownloadingEntityName:entityName errorMessage:nil];
}


- (void)doneDownloadingEntityName:(NSString *)entityName errorMessage:(NSString *)errorMessage {
    
    if (errorMessage) {
        [self logErrorMessage:[NSString stringWithFormat:@"doneDownloadingEntityName error: %@", errorMessage]];
    }
    
    STMDownloadingQueue *queue = self.downloadingState.queue;
    
    [[queue operationForEntityName:entityName] finish];
        
    NSUInteger remainCount = queue.operationCount;
    
    NSLog(@"remain %@ entities to receive", @(remainCount));
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                userInfo:@{@"countdownValue": @(remainCount)}];
    
    if (remainCount) return;
    
    [self receivingDidFinishWithError:nil];
    
}


- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        [self logErrorMessage:[NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString]];
    } else {
        // Don't LogMethodName because don't want 'error' to appear in console upon success finish
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
