//
//  STMCoreAppDelegate.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AdSupport/AdSupport.h>
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

#import "STMClientDataController.h"


@interface STMCoreAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) NSData *deviceToken;
@property (nonatomic, strong) NSString *deviceTokenError;
@property (nonatomic) BOOL haveFetchCompletionHandlers;

- (void)setupWindow;

- (void)completeFetchCompletionHandlersWithResult:(UIBackgroundFetchResult)result;

- (NSString *)currentNotificationTypes;

- (void)testCrash;


@end
