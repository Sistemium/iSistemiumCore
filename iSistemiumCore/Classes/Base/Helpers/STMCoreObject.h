//
//  STMCoreObject.h
//  iSisSales
//
//  Created by Alexander Levin on 15/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMNotifications.h"

@interface STMCoreObject : NSObject <STMNotifications>

@property (nonatomic, readonly) NSNotificationCenter *notificationCenter;

@end
