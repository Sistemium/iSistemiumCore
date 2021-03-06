//
//  STMMessageController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMMessagePicture.h"


@interface STMMessageController : STMCoreController

+ (NSArray *)sortedPicturesArrayForMessage:(STMMessage *)message;

+ (void)showMessageVCsIfNeeded;
+ (void)showMessageVCsForMessages:(NSArray *)messages;
+ (void)showMessageVCsForMessage:(STMMessage *)message;

+ (void)pictureDidShown:(STMMessagePicture *)picture;

+ (void)markMessageAsRead:(STMMessage *)message;
+ (void)markAllMessageAsRead;

+ (NSUInteger)unreadMessagesCount;


@end
