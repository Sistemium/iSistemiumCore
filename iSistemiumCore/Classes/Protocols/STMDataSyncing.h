//
//  STMDataSyncing.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 13/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDataSyncing <NSObject>

- (NSString *)subscribeUnsyncedWithCompletionHandler:(void (^)(NSString *entity, NSDictionary *itemData, NSString *itemVersion));

- (BOOL)unSubscribe:(NSString *)subscriptionId;

- (BOOL)setSynced:(NSString *)entity
         itemData:(NSDictionary *)itemData
      itemVersion:(NSString *)itemVersion;


@end
