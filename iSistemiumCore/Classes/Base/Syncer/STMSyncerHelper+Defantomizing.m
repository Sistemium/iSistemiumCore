//
//  STMSyncerHelper+Defantomizing.m
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper+Defantomizing.h"
#import "STMSyncerHelper+Private.h"

#import "STMConstants.h"
#import "STMEntityController.h"
#import "STMLazyDictionary.h"


#define STM_DEFANTOMIZING_QUEUE_MAX_CONCURRENT 25

@interface STMDefantomizingOperation : NSOperation

@property (nonatomic,weak) id <STMDefantomizingOwner> owner;
@property (nonatomic,strong) NSString *entityName;
@property (nonatomic,strong) NSString *identifier;

- (instancetype)initWithEntityName:(NSString *)entityName identifier:(NSString *)identifier owner:(id <STMDefantomizingOwner>)owner;

@end


@interface STMDefantomizingQueue : NSOperationQueue

@property (nonatomic,weak) id <STMDefantomizingOwner> owner;

- (STMDefantomizingOperation *)operationForEntityName:(NSString *)entityName identifier:(NSString *)identifier;
- (void)addDefantomizationOfEntityName:(NSString *)entityName identifier:(NSString *)identifier;

@end


@interface STMSyncerHelperDefantomizing ()

@property (nonatomic,strong) NSMutableSet *failToResolveIds;
@property (nonatomic,strong) STMDefantomizingQueue *operationQueue;
@property (nonatomic,strong) dispatch_queue_t dispatchQueue;

@end



@implementation STMDefantomizingQueue

- (void)addDefantomizationOfEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    [self addOperation:[[STMDefantomizingOperation alloc] initWithEntityName:entityName identifier:identifier owner:self.owner]];
}

- (STMDefantomizingOperation *)operationForEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entityName == %@ AND identifier == %@", entityName, identifier];
    
    return [self.operations filteredArrayUsingPredicate:predicate].firstObject;
}

@end

@implementation STMDefantomizingOperation {
    BOOL _executing;
    BOOL _finished;
}

+ (instancetype)defantomizationEntityName:(NSString *)entityName identifier:(NSString *)identifier owner:(id <STMDefantomizingOwner>)owner {
    return [[self alloc] initWithEntityName:entityName identifier:identifier owner:owner];
}

- (instancetype)initWithEntityName:(NSString *)entityName identifier:(NSString *)identifier owner:(id <STMDefantomizingOwner>)owner {
    self = [self init];
    self.identifier = identifier;
    self.entityName = entityName;
    self.owner = owner;
    return self;
}

- (BOOL)asynchronous {
    return YES;
}

- (void)start {
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    [self.owner defantomizeEntityName:self.entityName identifier:self.identifier];
    
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

- (void)finish {
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = NO;
    [self didChangeValueForKey:@"isExecuting"];
    
    [self willChangeValueForKey:@"isFinished"];
    _finished = YES;
    [self didChangeValueForKey:@"isFinished"];
    
}

@end


@implementation STMSyncerHelperDefantomizing

- (instancetype)init {

    self = [super init];
    
    if (self) {
        self.failToResolveIds = [NSMutableSet set];
        
        self.dispatchQueue = dispatch_queue_create("STMSyncerHelperDefantomizing", DISPATCH_QUEUE_CONCURRENT);
        STMDefantomizingQueue *operationQueue = [[STMDefantomizingQueue alloc] init];
        
        operationQueue.maxConcurrentOperationCount = STM_DEFANTOMIZING_QUEUE_MAX_CONCURRENT;
        operationQueue.underlyingQueue = self.dispatchQueue;
        
        self.operationQueue = operationQueue;
    }
    
    return self;
    
}

@end


@implementation STMSyncerHelper (Defantomizing)

@dynamic defantomizingOwner;
@dynamic persistenceFantomsDelegate;

#pragma mark - defantomizing

- (void)startDefantomization {

    STMSyncerHelperDefantomizing *defantomizing;
    
    @synchronized (self) {
        
        defantomizing = self.defantomizing ? self.defantomizing : [[STMSyncerHelperDefantomizing alloc] init];
        
        if (defantomizing.operationQueue.operationCount) return;
        
        defantomizing.operationQueue.owner = self.defantomizingOwner;
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
        return [self defantomizedEntityName:entityName identifier:identifier errorString:@"SyncerHelper defantimize got empty entityName"];
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
    
    NSLog(@"DEFANTOMIZING_FINISHED");
    
    [self postAsyncMainQueueNotification:NOTIFICATION_DEFANTOMIZING_FINISH userInfo:nil];
    
    self.defantomizing = nil;
    
    [self.defantomizingOwner defantomizingFinished];
    
}


@end
