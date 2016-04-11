//
//  STMAppDelegate.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface STMAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) NSData *deviceToken;
@property (nonatomic, strong) NSString *deviceTokenError;

- (NSString *)currentNotificationTypes;

- (void)testCrash;

@end
