//
//  STMDataSyncing.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 13/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncingSubscriber.h"
#import "STMPersistingFullStack.h"


@protocol STMDataSyncingState <NSObject>

@property (nonatomic) BOOL isInSyncingProcess;


@end


@protocol STMDataSyncing <NSObject>

@property (nonatomic, strong) id <STMDataSyncingState> syncingState;
@property (nonatomic, weak) id <STMPersistingFullStack> persistenceDelegate;
@property (nonatomic, weak) id <STMDataSyncingSubscriber> subscriberDelegate;

+ (instancetype)initWithPersistenceDelegate:(id <STMPersistingFullStack>)persistenceDelegate
                         subscriberDelegate:(id <STMDataSyncingSubscriber>)subscriberDelegate;

- (void)startSyncing;
- (void)pauseSyncing;

- (BOOL)setSynced:(BOOL)success
           entity:(NSString *)entity
         itemData:(NSDictionary *)itemData
      itemVersion:(NSString *)itemVersion;

- (NSUInteger)numberOfUnsyncedObjects;


@end
