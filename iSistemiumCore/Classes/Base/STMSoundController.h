//
//  STMSoundController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSoundCallbackable.h"


@interface STMSoundController : NSObject

@property (nonatomic, strong) id <STMSoundCallbackable> sender;

+ (STMSoundController *)sharedController;

+ (void)playAlert;
+ (void)playOk;

+ (void)say:(NSString *)string;
+ (void)sayText:(NSString *)string
       withRate:(float)rate
          pitch:(float)pitch;

+ (void)alertSay:(NSString *)string;
+ (void)alertSay:(NSString *)string
        withRate:(float)rate
           pitch:(float)pitch;

+ (void)okSay:(NSString *)string;
+ (void)okSay:(NSString *)string
     withRate:(float)rate
        pitch:(float)pitch;

+ (void)ringWithProperties:(NSDictionary *)ringProperties;
+ (void)stopRinging;


@end
