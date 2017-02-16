//
//  STMCoreObject.m
//  iSisSales
//
//  Created by Alexander Levin on 15/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreObject.h"

@implementation STMCoreObject

- (NSNotificationCenter *)notificationCenter {
    return [NSNotificationCenter defaultCenter];
}

- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    
    [self.notificationCenter postNotificationName:aName object:anObject userInfo:aUserInfo];
    
}

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName userInfo:(NSDictionary *)aUserInfo {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotificationName:aName object:self userInfo:aUserInfo];
    });
    
}

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName {
    [self postAsyncMainQueueNotification:aName userInfo:nil];
}

@end
