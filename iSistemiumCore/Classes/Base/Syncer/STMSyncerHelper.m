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
        
        _unsyncedDataHelper = [[STMUnsyncedDataHelper alloc] init];
        _unsyncedDataHelper.persistenceDelegate = self.persistenceDelegate;
        
    }
    return _unsyncedDataHelper;
    
}


#pragma mark - STMDataSyncing

- (void)setSyncingState:(STMDataSyncingState *)syncingState {
    
    _syncingState = syncingState;
    
    self.unsyncedDataHelper.syncingState = syncingState;
    
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
