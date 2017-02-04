//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"

#import "STMConstants.h"
#import "STMEntityController.h"
#import "STMUnsyncedDataHelper.h"


@interface STMSyncerHelper()

@property (nonatomic, strong) STMUnsyncedDataHelper *unsyncedDataHelper;


@end


@implementation STMSyncerHelper

@synthesize persistenceDelegate = _persistenceDelegate;
@synthesize subscriberDelegate = _subscriberDelegate;
@synthesize syncingState = _syncingState;


- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {
    _failToResolveFantomsArray = @[].mutableCopy;
}

- (STMUnsyncedDataHelper *)unsyncedDataHelper {
    
    if (!_unsyncedDataHelper) {
        
        _unsyncedDataHelper = [STMUnsyncedDataHelper initWithPersistenceDelegate:self.persistenceDelegate
                                                              subscriberDelegate:self.subscriberDelegate];
        
    }
    return _unsyncedDataHelper;
    
}


#pragma mark - STMDataSyncing

+ (instancetype)initWithPersistenceDelegate:(id<STMPersistingFullStack>)persistenceDelegate subscriberDelegate:(id<STMDataSyncingSubscriber>)subscriberDelegate {
    
    STMSyncerHelper *syncerHelper = [[STMSyncerHelper alloc] init];
    syncerHelper.persistenceDelegate = persistenceDelegate;
    syncerHelper.subscriberDelegate = subscriberDelegate;
    
    return syncerHelper;
    
}

- (void)startSyncing {
    [self.unsyncedDataHelper startSyncing];
}

- (void)pauseSyncing {
    [self.unsyncedDataHelper pauseSyncing];
}

- (void)setSubscriberDelegate:(id <STMDataSyncingSubscriber>)subscriberDelegate {
    
    _subscriberDelegate = subscriberDelegate;

    self.unsyncedDataHelper.subscriberDelegate = subscriberDelegate;
    
}

- (BOOL)setSynced:(BOOL)success entity:(NSString *)entity itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {

    return [self.unsyncedDataHelper setSynced:success
                                       entity:entity
                                     itemData:itemData
                                  itemVersion:itemVersion];

}

- (NSUInteger)numberOfUnsyncedObjects {
    return [self.unsyncedDataHelper numberOfUnsyncedObjects];
}


@end
