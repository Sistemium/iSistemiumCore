//
//  STMCoreObject.h
//  iSisSales
//
//  Created by Alexander Levin on 15/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMCoreObject : NSObject

@property (nonatomic, readonly) NSNotificationCenter *notificationCenter;

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName;

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName
                              userInfo:(NSDictionary *)aUserInfo;

- (void)postNotificationName:(NSNotificationName)aName
                      object:(id)anObject
                    userInfo:(NSDictionary *)aUserInfo;

- (void)addObserver:(id)anObserver
           selector:(SEL)aSelector
               name:(NSNotificationName)aName;

- (void)observeNotification:(NSNotificationName)notificationName
                   selector:(SEL)aSelector;

- (void)removeObservers;

@end