//
// Created by Alexander Levin on 11/06/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMCoreWKWebViewVC.h"

#import "STMPersistingFullStack.h"
#import "STMCoreAppManifestHandler.h"
#import "STMScriptMessaging.h"
#import "STMLogging.h"
#import "STMSpinnerView.h"
#import "STMCoreSessionManager.h"
#import "STMCoreSession.h"


@interface STMCoreWKWebViewVC () <UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UIView *localView;
@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic) BOOL isAuthorizing;
@property (nonatomic) BOOL wasLoadingOnce;

@property (nonatomic, strong) STMSpinnerView *spinnerView;
@property (nonatomic, strong) STMBarCodeScanner *iOSModeBarCodeScanner;
@property (nonatomic, strong) STMCoreAppManifestHandler *appManifestHandler;
@property (nonatomic, weak) id <STMLogger> logger;

@property (nonatomic, strong) NSString *scannerScanJSFunction;
@property (nonatomic, strong) NSString *scannerPowerButtonJSFunction;
@property (nonatomic, strong) NSString *unsyncedInfoJSFunction;
@property (nonatomic, strong) NSString *iSistemiumIOSCallbackJSFunction;
@property (nonatomic, strong) NSString *iSistemiumIOSErrorCallbackJSFunction;
@property (nonatomic, strong) NSString *soundCallbackJSFunction;
@property (nonatomic, strong) NSString *remoteControlCallbackJSFunction;
@property (nonatomic, strong) NSString *checkinCallbackJSFunction;
@property (nonatomic, strong) NSMutableDictionary *checkinMessageParameters;

@property (nonatomic) BOOL waitingCheckinLocation;
@property (nonatomic, strong) id <STMScriptMessaging> scriptMessageHandler;

@property (nonatomic, strong) NSString *lastUrl;
@property (readonly) id <STMFiling> filer;

@property (nonatomic, strong) NSObject <STMPersistingFullStack> *persistenceDelegate;

- (void)flushWebView;
- (void)reloadWebView;
- (void)loadWebView;

- (NSString *)webViewAuthCheckJS;
- (void)authLoadWebView;
- (BOOL)isInActiveTab;

@end
