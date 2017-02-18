//
//  STMNotifications.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 18/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMNotifications <NSObject>

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName;

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName
                              userInfo:(NSDictionary *)aUserInfo;

- (void)postNotificationName:(NSNotificationName)aName;

- (void)postNotificationName:(NSNotificationName)aName
                    userInfo:(NSDictionary *)aUserInfo;

- (void)addObserver:(id)anObserver
           selector:(SEL)aSelector
               name:(NSNotificationName)aName;

- (void)observeNotification:(NSNotificationName)notificationName
                   selector:(SEL)aSelector;

- (void)observeNotification:(NSNotificationName)notificationName
                   selector:(SEL)aSelector
                     object:(id)anObject;

- (void)removeObservers;

@end
