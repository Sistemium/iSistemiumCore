//
//  STMDataSyncingSubscriber.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDataSyncingSubscriber <NSObject>

- (void)haveUnsynced:(NSString *)entityName
            itemData:(NSDictionary *)itemData
         itemVersion:(NSString *)itemVersion;

@end
