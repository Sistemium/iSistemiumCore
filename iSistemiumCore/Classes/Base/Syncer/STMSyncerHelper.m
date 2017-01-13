//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"


@interface STMSyncerHelper()

@end


@implementation STMSyncerHelper

#pragma mark - STMDataSyncing

- (NSString *)subscribeUnsyncedWithCompletionHandler:(void (^)(NSString *entity, NSDictionary *itemData, NSString *itemVersion))completionHandler {
    return nil;
}

- (BOOL)unSubscribe:(NSString *)subscriptionId {
    return YES;
}

- (BOOL)setSynced:(NSString *)entity itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    return YES;
}


@end
