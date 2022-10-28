//
//  STMCoreAppDelegate.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//
@import Flutter;

#import <UIKit/UIKit.h>

#import <AdSupport/AdSupport.h>

#import "STMClientDataController.h"


@interface STMCoreAppDelegate: FlutterAppDelegate
@property (nonatomic,strong) FlutterEngine *flutterEngine;


@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) FlutterViewController *flutterViewController;
@property (strong, nonatomic) FlutterMethodChannel *flutterChannel;

@property (nonatomic, strong) NSData *deviceToken;
@property (nonatomic, strong) NSString *deviceTokenError;
@property (nonatomic) BOOL haveFetchCompletionHandlers;
@property (nonatomic) UIInterfaceOrientationMask orientation;


- (void)setupWindow;
- (void)goFlutter;

- (void)completeFetchCompletionHandlersWithResult:(UIBackgroundFetchResult)result;

- (NSString *)currentNotificationTypes;

- (void)testCrash;


@end
