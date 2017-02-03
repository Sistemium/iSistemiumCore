//
//  STMDataSyncing.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 13/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncingSubscriber.h"


@protocol STMDataSyncing <NSObject>

@property (nonatomic, weak) id <STMDataSyncingSubscriber> subscriberDelegate;

- (BOOL)setSynced:(BOOL)success
           entity:(NSString *)entity
         itemData:(NSDictionary *)itemData
      itemVersion:(NSString *)itemVersion;

- (NSUInteger)numberOfUnsyncedObjects;


@end
