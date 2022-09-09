//
//  STMSyncerHelper+Defantomizing.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <iSistemiumCore-Swift.h>
#import "STMSyncerHelper+Defantomizing.h"
#import "STMSyncerHelper+Private.h"

#import "STMConstants.h"
#import "STMEntityController.h"
#import "STMLazyDictionary.h"
#import "STMOperationQueue.h"

#define STM_DEFANTOMIZING_MAX_CONCURRENT 25


@interface STMDefantomizingOperation : STMOperation

@property (nonatomic, strong) NSString *entityName;
@property (nonatomic, strong) NSString *identifier;

@end


@interface STMDefantomizingQueue : STMOperationQueue

@property (nonatomic, weak) STMSyncerHelper *owner;

@end


@implementation STMDefantomizingOperation


- (STMDefantomizingQueue *)defantomizingQueue {
    return (STMDefantomizingQueue *) self.queue;
}


- (instancetype)initWithEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    self.identifier = identifier;
    self.entityName = entityName;
    return self;
}


- (void)main {
    [self.defantomizingQueue.owner.defantomizingOwner defantomizeEntityName:self.entityName identifier:self.identifier];
}


@end


@implementation STMDefantomizingQueue


- (void)addDefantomizationOfEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    [self addOperation:[[STMDefantomizingOperation asynchronousOperation] initWithEntityName:entityName identifier:identifier]];
}


- (STMDefantomizingOperation *)operationForEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entityName == %@ AND identifier == %@", entityName, identifier];

    return [self.operations filteredArrayUsingPredicate:predicate].firstObject;
}


@end


@interface STMSyncerHelperDefantomizing ()

@property (nonatomic, strong) NSMutableSet *failToResolveIds;
@property (nonatomic, strong) STMDefantomizingQueue *operationQueue;

@end


@implementation STMSyncerHelperDefantomizing


+ (instancetype)defantomizingWithDispatchQueue:(dispatch_queue_t)dispatchQueue {

    STMSyncerHelperDefantomizing *instance = [[self alloc] init];

    if (instance) {
        instance.failToResolveIds = [NSMutableSet set];
        instance.operationQueue = [STMDefantomizingQueue queueWithDispatchQueue:dispatchQueue];
    }

    return instance;

}


@end


@implementation STMSyncerHelper (Defantomizing)

@dynamic defantomizingOwner;
@dynamic persistenceFantomsDelegate;


#pragma mark - defantomizing

NSUInteger fantomsCount = 100;

- (void)startDefantomization {

    STMSyncerHelperDefantomizing *defantomizing;

    @synchronized (self) {

        defantomizing = self.defantomizing;

        if (!defantomizing) {
            defantomizing = [STMSyncerHelperDefantomizing defantomizingWithDispatchQueue:self.dispatchQueue];
            defantomizing.operationQueue.owner = self;
        }

        if (defantomizing.operationQueue.operationCount) return;

        defantomizing.operationQueue.suspended = YES;

        self.defantomizing = defantomizing;

    }

    for (NSString *entityName in [STMEntityController entityNamesWithResolveFantoms]) {

        NSDictionary *entity = [STMEntityController stcEntities][entityName];

        if (![STMFunctions isNotNull:entity[@"url"]]) {
            NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
            continue;
        }

        NSArray *results = [self.persistenceFantomsDelegate findAllFantomsIdsSync:entityName excludingIds:defantomizing.failToResolveIds.allObjects];

        if (!results.count) continue;

        NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);

        for (NSString *identifier in results)
            [defantomizing.operationQueue addDefantomizationOfEntityName:entityName identifier:identifier];

    }

    NSUInteger count = defantomizing.operationQueue.operationCount;

    if (!count) return [self defantomizingFinished];

    NSLog(@"DEFANTOMIZING_START with queue of %@", @(count));

    fantomsCount = count;

    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_START
                                userInfo:@{@"fantomsCount": @(count)}];

    defantomizing.operationQueue.suspended = NO;

}


- (void)stopDefantomization {
    // TODO: implement cancellation in STMDefantomizingOperation
    [self.defantomizing.operationQueue cancelAllOperations];
    [self defantomizingFinished];
}


- (void)defantomizedEntityName:(NSString *)entityName identifier:(NSString *)identifier success:(BOOL)success attributes:(NSDictionary *)attributes error:(NSError *)error {

    if (!success) {
        return [self defantomizedEntityName:entityName identifier:identifier errorString:error.localizedDescription];
    }

    if (!entityName) {
        return [self defantomizedEntityName:entityName identifier:identifier errorString:@"SyncerHelper defantomize got empty entityName"];
    }

    [self.persistenceFantomsDelegate mergeFantomAsync:entityName attributes:attributes callback:^
    (STMP_ASYNC_DICTIONARY_RESULT_CALLBACK_ARGS) {

        if (error) {
            return [self defantomizedEntityName:entityName identifier:identifier errorString:error.localizedDescription];
        }

        [self doneWithEntityName:entityName identifier:identifier];

    }];


}


#pragma mark - Private helpers


- (void)defantomizedEntityName:(NSString *)entityName identifier:(NSString *)identifier errorString:(NSString *)errorString {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"flutter invokeMethod setupError");
        FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
        [channel invokeMethod:@"setupError" arguments:NSLocalizedString(@"NO CONNECTION", nil)];
    });

    NSLog(@"defantomize %@ %@ error: %@", entityName, identifier, errorString.length ? errorString : @"no description");

    BOOL deleteObject = [errorString hasSuffix:@"404"] || [errorString hasSuffix:@"403"];

    if (deleteObject) {

        NSLog(@"delete fantom %@ %@", entityName, identifier);

        [self.persistenceFantomsDelegate destroyFantomSync:entityName identifier:identifier];

    } else {

        @synchronized (self) {
            [self.defantomizing.failToResolveIds addObject:identifier];
        }

    }

    [self doneWithEntityName:entityName identifier:identifier];

}


- (void)doneWithEntityName:(NSString *)entityName identifier:(NSString *)identifier {

    [[self.defantomizing.operationQueue operationForEntityName:entityName identifier:identifier] finish];

    NSUInteger count = self.defantomizing.operationQueue.operations.count;

    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_UPDATE
                                userInfo:@{@"fantomsCount": @(count)}];

    NSLog(@"doneWith %@ %@ (%@)", entityName, identifier, @(count));

    if (!count) [self startDefantomization];

}


- (void)defantomizingFinished {

    STMOperationQueue *queue = self.defantomizing.operationQueue;

    NSLog(@"DEFANTOMIZING_FINISHED in %@ with %@ iterations", queue.printableFinishedIn, @(queue.iterationsCount));

    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_FINISH userInfo:nil];

    self.defantomizing = nil;

    [self.defantomizingOwner defantomizingFinished];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate setupWindow];
    });
    
}


@end
