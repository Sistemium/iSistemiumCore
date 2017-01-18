//
//  STMDataSyncing.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 13/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDataSyncing <NSObject>

- (NSString *)subscribeUnsyncedWithCompletionHandler:(void (^)(NSString *entity, NSDictionary *itemData, NSString *itemVersion))completionHandler;

- (BOOL)unSubscribe:(NSString *)subscriptionId;

- (BOOL)setSynced:(BOOL)success
           entity:(NSString *)entity
         itemData:(NSDictionary *)itemData
      itemVersion:(NSString *)itemVersion;


@end
