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


#pragma mark Private Classes


@interface STMDownloadingOperation : STMOperation

@property (nonatomic,strong) NSString *entityName;

@end



@interface STMDownloadingQueue : STMOperationQueue

@property (nonatomic,weak) STMSyncerHelper *owner;

@end



@interface STMDataDownloadingState ()

@property (nonatomic,strong) STMDownloadingQueue *queue;

@end



@implementation STMDownloadingOperation


- (STMDownloadingQueue *)dowlonadingQueue {
    return (STMDownloadingQueue *)self.queue;
}


- (instancetype)initWithEntityName:(NSString *)entityName {
    self = [self init];
    self.entityName = entityName;
    return self;
}


- (void)main {
    
    NSLog(@"start downloadEntityName: %@", self.entityName);
    
    NSString *lastKnownEtag = [STMClientEntityController clientEntityWithName:self.entityName][@"eTag"];
    
    if (![STMFunctions isNotNull:lastKnownEtag]) lastKnownEtag = @"*";
    
    [self.dowlonadingQueue.owner.dataDownloadingOwner receiveData:self.entityName offset:lastKnownEtag];
    
}

- (void)cancel {
    [super cancel];
    NSLog(@"entityName: %@", self.entityName);
}

@end



@implementation STMDownloadingQueue


- (void)downloadEntityName:(NSString *)entityName {
    [self addOperation:[[STMDownloadingOperation asynchronousOperation] initWithEntityName:entityName]];
}


- (STMDownloadingOperation *)operationForEntityName:(NSString *)entityName {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entityName == %@", entityName];
    
    return [self.operations filteredArrayUsingPredicate:predicate].firstObject;
    
}


@end


@implementation STMDataDownloadingState
@end


#pragma mark - Category implementation


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
        
        state.queue = [STMDownloadingQueue queueWithDispatchQueue:self.dispatchQueue];
        state.queue.owner = self;
        state.queue.suspended = YES;
        
        if (!entitiesNames) {
            
            NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSetWithObject:STM_ENTITY_NAME];
            
            [names addObjectsFromArray:[STMEntityController downloadableEntityNames]];
            
            if ([STMEntityController entityWithName:@"STMSetting"]) [names addObject:@"STMSetting"];
            
            entitiesNames = names.array.copy;
            
        }

        for (NSString *entityName in entitiesNames) [state.queue downloadEntityName:entityName];
        
        [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_STARTED];

        NSLog(@"will download %@ entities with %@ concurrent", @(state.queue.operationCount), @(state.queue.maxConcurrentOperationCount));
        
        state.queue.suspended = NO;
        
        return state;
        
    }
    
}


- (void)stopDownloading {
    
    NSLogMethodName;
    
    [self.downloadingState.queue cancelAllOperations];
    [self receivingDidFinishWithError:nil];
    
}


- (void)dataReceivedSuccessfully:(BOOL)success entityName:(NSString *)entityName dataRecieved:(NSArray *)dataRecieved offset:(NSString *)offset pageSize:(NSUInteger)pageSize error:(NSError *)error {
    
    if (!success) {
        return [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
    }
    
    if (!entityName) {
        return [self receivingDidFinishWithError:@"called parseFindAllAckResponseData with empty entityName"];
    }
    
    if (!dataRecieved.count) {
//        NSLog(@"    %@: have no new data", entityName);
        return [self doneDownloadingEntityName:entityName];
    }
    
    if (!offset) {
//        NSLog(@"    %@: receive data w/o offset", entityName);
        return [self doneDownloadingEntityName:entityName];
    }
    
    [self.persistenceDelegate mergeManyAsync:entityName attributeArray:dataRecieved options:@{STMPersistingOptionLtsNow} completionHandler:^(STMP_ASYNC_ARRAY_RESULT_CALLBACK_ARGS) {
        
        if (!success) {
            return [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
        }
        
        [self findAllResultMergedWithSuccess:dataRecieved entityName:entityName offset:offset pageSize:pageSize];
        
    }];

}


#pragma mark - Category private methods


- (void)logErrorMessage:(NSString *)errorMessage {
    [self.logger errorMessage:errorMessage];
}


- (void)doneDownloadingEntityName:(NSString *)entityName {
    [self doneDownloadingEntityName:entityName errorMessage:nil];
}


- (void)doneDownloadingEntityName:(NSString *)entityName errorMessage:(NSString *)errorMessage {
    
    if (errorMessage) {
        [self logErrorMessage:[NSString stringWithFormat:@"doneDownloadingEntityName error: %@", errorMessage]];
    }
    
    STMDownloadingQueue *queue = self.downloadingState.queue;
    STMDownloadingOperation *operation = [queue operationForEntityName:entityName];
    
    [operation finish];
    
    NSUInteger remainCount = queue.operationCount;
    
    NSLog(@"doneWith %@ in %@ remain %@ to receive", entityName, STMIsNull(operation.printableFinishedIn,@"(cancelled)"), @(remainCount));
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                userInfo:@{@"countdownValue": @(remainCount)}];
    
    if (remainCount) return;
    
    [self receivingDidFinishWithError:nil];
    
}


- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        [self logErrorMessage:[NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString]];
    }
    
    STMOperationQueue *queue = self.downloadingState.queue;
    
    if (!queue) {
        return [self logErrorMessage:@"receivingDidFinish with nil queue"];
    }
    
    NSString *finishedIn = queue.printableFinishedIn;
    NSString *duration = queue.printableFinishedOperationsDuration;
    NSUInteger initialCount = queue.finishedOperationsCount;
    
    NSLog(@"receivingDidFinish in %@ (%@ total of %@ operations)", finishedIn, duration, @(initialCount));
    
    self.downloadingState = nil;
    [self.dataDownloadingOwner dataDownloadingFinished];
    
}


- (void)findAllResultMergedWithSuccess:(NSArray *)result entityName:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    NSLog(@"    %@: got %@ objects", entityName, @(result.count));
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                userInfo:@{@"count": @(result.count),
                                           @"entityName": entityName
                                           }];
    
    if (result.count < pageSize) {
        
        [STMClientEntityController clientEntityWithName:entityName setETag:offset];
        
        return [self doneDownloadingEntityName:entityName];
        
    }
    
    STMOperation *op = [self.downloadingState.queue operationForEntityName:entityName];
    
    if (!op) return [self.logger warningMessage:@"no operation"];

    if (op.isCancelled) return [self.logger warningMessage:@"operation is cancelled"];
    
    [self.dataDownloadingOwner receiveData:entityName offset:offset];
    
}


@end
