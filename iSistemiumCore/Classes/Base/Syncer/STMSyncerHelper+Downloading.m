//
//  STMSyncerHelper+Downloading.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMConstants.h"

#import "STMSyncerHelper+Private.h"
#import "iSistemiumCore-Swift.h"
#import "STMSyncerHelper+Downloading.h"

#import "STMClientEntityController.h"
#import "STMEntityController.h"
#import "STMLogger.h"
#import "STMFunctions.h"

#import "STMOperationQueue.h"


#pragma mark Private Classes


@interface STMDownloadingOperation : STMOperation

@property (nonatomic, strong) NSString *entityName;
@property (nonatomic, strong) NSDate *lastAlive;
@property (nonatomic, strong) NSString *lastOffset;

- (void)updateAlive:(NSString *)offset;

@end


@interface STMDownloadingQueue : STMOperationQueue

@property (nonatomic, weak) STMSyncerHelper *owner;

@end


@interface STMDataDownloadingState ()

@property (nonatomic, strong) STMDownloadingQueue *queue;

@end


@implementation STMDownloadingOperation


- (STMDownloadingQueue *)dowlonadingQueue {
    return (STMDownloadingQueue *) self.queue;
}


- (instancetype)initWithEntityName:(NSString *)entityName {
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
    NSLog(@"cancel downloading entityName: %@", self.entityName);
}

- (void)updateAlive:(NSString *)offset {
    self.lastAlive = [NSDate date];
    self.lastOffset = offset;
}

- (BOOL)isNotAlive {
    NSDate *untilIsAlive = [NSDate dateWithTimeInterval:30 sinceDate:self.lastAlive];
    return [untilIsAlive compare:[NSDate date]] == kCFCompareLessThan;
}

@end


@implementation STMDownloadingQueue


- (void)downloadEntityName:(NSString *)entityName {
    
    STMDownloadingOperation *existing = [self operationForEntityName:entityName];
    
    if ([existing isNotAlive]) {
        [existing cancel];
    }
    
    if (!existing || existing.isCancelled) {
        [self addOperation:[[STMDownloadingOperation asynchronousOperation] initWithEntityName:entityName]];
    } else {
        NSLog(@"ignore existing %@", entityName);
    }
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

        if (self.downloadingState && !entitiesNames) {
            NSLog(@"Continue downloading");
//            return self.downloadingState;
        }
        
        STMDataDownloadingState *state;
        
        if (!self.downloadingState) {
            state = [[STMDataDownloadingState alloc] init];
            self.downloadingState = state;
            state.queue = [STMDownloadingQueue queueWithDispatchQueue:self.dispatchQueue];
            state.queue.owner = self;
        } else {
            state = self.downloadingState;
        }

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

    STMDownloadingQueue *queue = self.downloadingState.queue;
    
    self.downloadingState = nil;
    
    if (queue) {
        [self.downloadingState.queue cancelAllOperations];
    }

}


- (void)dataReceivedSuccessfully:(BOOL)success entityName:(NSString *)entityName dataRecieved:(NSArray *)dataRecieved offset:(NSString *)offset pageSize:(NSUInteger)pageSize error:(NSError *)error {

    if (!success) {
        return [self doneDownloadingEntityName:entityName errorMessage:error.localizedDescription];
    }

    if (!entityName) {
        return [self receivingDidFinishWithError:@"called parseFindAllAckResponseData with empty entityName"];
    }

    NSString *currentEtag = [STMClientEntityController clientEntityWithName:entityName][@"eTag"];

    if ([STMFunctions isNull:currentEtag]) {
        currentEtag = @"";
    }

    if (!dataRecieved.count && ![offset isEqualToString:currentEtag]) {

        [STMClientEntityController clientEntityWithName:entityName setETag:offset];
    }

    if (!dataRecieved.count) {
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

    NSLog(@"doneWith %@ in %@ remain %@ to receive", entityName, STMIsNull(operation.printableFinishedIn, @"(cancelled)"), @(remainCount));

    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
                                userInfo:@{@"countdownValue": @(remainCount)}];

    float totalEntityCount = (float)[STMEntityController stcEntities].allKeys.count;

    if (queue == nil){

        [LoadingDataObjc setErrorWithError:NSLocalizedString(@"NO CONNECTION", nil)];

        [ProfileDataObjc setErrorWithError:NSLocalizedString(@"NO CONNECTION", nil)];

    } else {
        [LoadingDataObjc setProgressWithValue:(totalEntityCount - remainCount) / totalEntityCount * 0.98];

        [ProfileDataObjc setProgressWithValue:(totalEntityCount - remainCount) / totalEntityCount];
    }

    if (remainCount) return;

    [self receivingDidFinishWithError:nil];

}


- (void)receivingDidFinishWithError:(NSString *)errorString {

    if (errorString) {
        [self logErrorMessage:[NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString]];
    }

    STMOperationQueue *queue = self.downloadingState.queue;

    if (!queue) {
        [self logErrorMessage:@"receivingDidFinish with nil queue"];
    } else {
        NSString *finishedIn = queue.printableFinishedIn;
        NSString *duration = queue.printableFinishedOperationsDuration;
        NSUInteger initialCount = queue.finishedOperationsCount;

        NSLog(@"receivingDidFinish in %@ (%@ total of %@ operations)", finishedIn, duration, @(initialCount));
    }

//    self.downloadingState.queue = nil;
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

    STMDownloadingOperation *op = [self.downloadingState.queue operationForEntityName:entityName];

    if (!op) {
        [self.logger warningMessage:@"no operation"];
        NSLog(@"no operation on entity: %@", entityName);
        return;
    }
    
    if (op.isCancelled) {
        [self.logger warningMessage:@"operation is cancelled"];
        NSLog(@"operation isCancelled on entity: %@", entityName);
        return;
    }
    
    if ([op.lastOffset compare:offset] == kCFCompareGreaterThan) {
        NSLog(@"operation lastOffset is greater on %@", entityName);
        return;
    }
    
    [op updateAlive:offset];

    [self.dataDownloadingOwner receiveData:entityName offset:offset];

}


@end
