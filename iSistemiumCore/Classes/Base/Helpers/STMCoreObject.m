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

- (void)postNotificationName:(NSNotificationName)aName userInfo:(NSDictionary *)aUserInfo {
    [self postNotificationName:aName object:self userInfo:aUserInfo];
}

- (void)postNotificationName:(NSNotificationName)aName {
    [self postNotificationName:aName userInfo:nil];
}

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName userInfo:(NSDictionary *)aUserInfo {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotificationName:aName object:self userInfo:aUserInfo];
    });
    
}

- (void)postAsyncMainQueueNotification:(NSNotificationName)aName {
    [self postAsyncMainQueueNotification:aName userInfo:nil];
}


- (void)addObserver:(id)anObserver selector:(SEL)aSelector name:(NSNotificationName)aName {
    // TODO: remember observers to remove them in dealloc
    return [self.notificationCenter addObserver:anObserver selector:aSelector name:aName object:self];
}

- (void)observeNotification:(NSNotificationName)notificationName selector:(SEL)aSelector object:(id)anObject {
    return [self.notificationCenter addObserver:self selector:aSelector name:notificationName object:anObject];
}

- (void)observeNotification:(NSNotificationName)notificationName selector:(SEL)aSelector {
    return [self observeNotification:notificationName selector:aSelector object:nil];
}

- (void)removeObservers {
    [self.notificationCenter removeObserver:self];
}

- (void)dealloc {
    [self removeObservers];
}

@end
