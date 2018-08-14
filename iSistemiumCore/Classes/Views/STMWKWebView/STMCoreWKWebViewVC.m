//
//  STMCoreWKWebViewVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreWKWebViewVC+Private.h"
#import "STMCoreWKWebViewVC+ScriptMessaging.h"
#import "STMCoreWKWebViewVC+Navigation.h"
#import <WebKit/WebKit.h>


#import "STMCoreAuthController.h"
#import "STMRemoteController.h"

#import "STMCoreRootTBC.h"
#import "STMStoryboard.h"

#import "STMFunctions.h"
#import "STMCoreUI.h"





@implementation STMCoreWKWebViewVC

- (id <STMFiling>)filer {
    return STMCoreSessionManager.sharedManager.currentSession.filing;
}

- (NSObject <STMPersistingFullStack> *)persistenceDelegate {

    if (!_persistenceDelegate) {
        _persistenceDelegate = STMCoreSessionManager.sharedManager.currentSession.persistenceDelegate;
    }

    return _persistenceDelegate;

}

- (id <STMScriptMessaging>)scriptMessageHandler {
    if (!_scriptMessageHandler) {
        STMScriptMessageHandler *scriptMessageHandler = [[STMScriptMessageHandler alloc] initWithOwner:self];
        scriptMessageHandler.persistenceDelegate = self.persistenceDelegate;
        _scriptMessageHandler = scriptMessageHandler;
    }
    return _scriptMessageHandler;
}

- (BOOL)isInActiveTab {
    return [self.tabBarController.selectedViewController isEqual:self.navigationController];
}

- (STMCoreAppManifestHandler *)appManifestHandler {

    if (!_appManifestHandler) {

        _appManifestHandler = [[STMCoreAppManifestHandler alloc] init];
        _appManifestHandler.owner = self;

    }
    return _appManifestHandler;

}

- (id <STMLogger>)logger {

    if (!_logger) {
        _logger = [STMLogger sharedLogger];
    }
    return _logger;

}


- (STMSpinnerView *)spinnerView {

    if (!_spinnerView) {
        _spinnerView = [STMSpinnerView spinnerViewWithFrame:self.view.frame];
    }
    return _spinnerView;

}

- (NSMutableDictionary *)checkinMessageParameters {

    if (!_checkinMessageParameters) {
        _checkinMessageParameters = @{}.mutableCopy;
    }
    return _checkinMessageParameters;

}

- (NSDictionary *)webViewSettings {

    NSDictionary *settings = [[STMCoreSessionManager sharedManager].currentSession.settingsController currentSettingsForGroup:@"webview"];
    return settings;

}

- (NSDictionary *)webViewStoryboardParameters {

    if (!_webViewStoryboardParameters) {

        if ([self.storyboard isKindOfClass:[STMStoryboard class]]) {

            STMStoryboard *storyboard = (STMStoryboard *) self.storyboard;
            _webViewStoryboardParameters = storyboard.parameters;

        } else {

            _webViewStoryboardParameters = @{};

        }

    }
    return _webViewStoryboardParameters;

}

- (NSString *)webViewUrlString {

//    return @"http://lamac.local:8080";
//        return @"http://localhost:8080";
    //    return @"https://isissales.sistemium.com/";
    //    return @"https://sistemium.com";

    NSString *webViewUrlString = self.webViewStoryboardParameters[@"url"];
    return webViewUrlString ? webViewUrlString : @"https://sistemium.com";

}

- (NSString *)webViewAppManifestURI {

    NSString *manifestUri = self.webViewStoryboardParameters[@"appManifestURI"];
    
//    if (manifestUri) {
//        return @"http://lamac.local:8090/appcache.manifest";
//    }
//    return @"https://drv.sistemium.com/appcache.manifest";
//        return nil;
    //    return @"https://isd.sistemium.com/app.manifest";
    //    return @"https://r50.sistemium.com/app.manifest";
    //    return @"https://sistemium.com/r50/tp/cache.manifest.php";

    return manifestUri;

}

- (NSString *)webViewAuthCheckJS {

    NSString *webViewAuthCheckJS = self.webViewStoryboardParameters[@"authCheck"];
    return webViewAuthCheckJS ? webViewAuthCheckJS : [[self webViewSettings] valueForKey:@"wv.session.check"];

}

- (BOOL)disableScroll {
    return [self.webViewStoryboardParameters[@"disableScroll"] boolValue];
}

- (void)reloadWebView {

    [self hideNavBar];
    [self.scriptMessageHandler cancelSubscriptions];
    self.unsyncedInfoJSFunction = nil;

    if ([self webViewAppManifestURI]) {

        return [self loadLocalHTML];

    }

    //    [self.webView reloadFromOrigin];

    NSString *wvUrl = [self webViewUrlString];

    NSString *format = @"('%@'.lastIndexOf(location.origin) >= 0) ? location.reload (true) : location.replace ('%@')";

    NSString *jsString = [NSString stringWithFormat:format, wvUrl, wvUrl];

    [self.webView evaluateJavaScript:jsString completionHandler:^(id result, NSError *error) {

        if (!error) {
            return;
        }

        NSLog(@"evaluate \"%@\" with error: %@", jsString, error.localizedDescription);
        NSLog(@"trying to reload webView with loadRequest method");

        [self loadWebView];

    }];

}

- (void)loadWebView {

    [self.view addSubview:self.spinnerView];

    self.isAuthorizing = NO;

    NSString *urlString = self.lastUrl ? self.lastUrl : [self webViewUrlString];

    if ([self webViewAppManifestURI]) {


        if (!self.lastUrl) {

            [self loadLocalHTML];

        } else {
        
            [self.webView loadFileURL:[NSURL URLWithString:self.lastUrl]
              allowingReadAccessToURL:[NSURL fileURLWithPath:[self.filer.directoring sharedDocuments]]];

        }

    } else {
        [self loadURLString:urlString];
    }

    self.lastUrl = nil;

}


#pragma mark - load from remote URL

- (void)authLoadWebView {

    self.isAuthorizing = YES;

    NSString *accessToken = [STMCoreAuthController authController].accessToken;

    NSString *urlString = [self webViewUrlString];
    urlString = [NSString stringWithFormat:@"%@?access-token=%@", urlString, accessToken];

    [self loadURLString:urlString];

}

- (void)loadURLString:(NSString *)urlString {

    NSURL *url = [NSURL URLWithString:urlString];
    [self loadURL:url];

}

- (void)loadURL:(NSURL *)url {

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];

    request.cachePolicy = NSURLRequestUseProtocolCachePolicy;

    [self performSelector:@selector(timeoutReached)
               withObject:nil
               afterDelay:60];

    [self.webView loadRequest:request];

}

- (void)timeoutReached {

    [self.webView stopLoading];

    [self webView:self.webView
             fail:@"loadURL"
        withError:@"timeout"];

}


#pragma mark - load localHTML

- (void)loadLocalHTML {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.appManifestHandler startLoadLocalHTML];
    });

}

- (void)loadUrl:(NSURL *)fileUrl atBaseDir:(NSString *)baseDir {

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.webView) {
            [self.logger errorMessage:@"empty webView in loadUrl:atBaseDir"];
        }
        [self.webView loadFileURL:fileUrl allowingReadAccessToURL:[NSURL fileURLWithPath:baseDir]];
    });

}

- (void)loadHTML:(NSString *)html atBaseDir:(NSString *)baseDir {

    dispatch_async(dispatch_get_main_queue(), ^{

        [self.webView loadHTMLString:html baseURL:[NSURL fileURLWithPath:baseDir]];

    });

}

- (void)localHTMLUpdateIsAvailable {

    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUpdateAvailableNavBar];
    });

}

- (void)appManifestLoadErrorText:(NSString *)errorText {

    errorText = [@"cache manifest load error: " stringByAppendingString:errorText];
    [self appManifestLoadLogMessage:errorText
                            numType:STMLogMessageTypeError];

}

- (void)appManifestLoadInfoText:(NSString *)infoText {

    infoText = [@"cache manifest load: " stringByAppendingString:infoText];
    [self appManifestLoadLogMessage:infoText numType:STMLogMessageTypeInfo];

}

- (void)appManifestLoadLogMessage:(NSString *)logMessage numType:(STMLogMessageType)numType {

    dispatch_async(dispatch_get_main_queue(), ^{

        [self.logger saveLogMessageWithText:logMessage
                                    numType:numType];

        if (numType == STMLogMessageTypeError && !self.haveLocalHTML) {

            [self webView:nil
                     fail:nil
                withError:nil];

        }

    });

}


#pragma mark - webViewInit

- (void)flushWebView {

    if (self.webView) {

        [self.webView removeFromSuperview];
        self.webView = nil;

        [self.scriptMessageHandler cancelSubscriptions];

    }

}

- (void)webViewInit {

    [self.logger infoMessage:@"webViewInit"];

    [self flushWebView];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];

    WKUserContentController *contentController = [[WKUserContentController alloc] init];

    for (NSString *messageName in WK_SCRIPT_MESSAGE_NAMES) {
        [contentController addScriptMessageHandler:self name:messageName];
    }

    NSString *js = [self errorCatcherScriptToAddToDocument];

    if (js) {

        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:js
                                                          injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                       forMainFrameOnly:NO];

        [contentController addUserScript:userScript];

    }

    configuration.userContentController = contentController;

    self.webView = [[WKWebView alloc] initWithFrame:self.localView.bounds configuration:configuration];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.localView addSubview:self.webView];

    self.webView.navigationDelegate = self;

    self.webView.scrollView.scrollEnabled = ![self disableScroll];

    [self loadWebView];

}

- (NSString *)errorCatcherScriptToAddToDocument {

    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"errorCatcherScript" ofType:@"js"];

    if (scriptPath) {

        NSError *error = nil;

        NSString *script = [NSString stringWithContentsOfFile:scriptPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];

        if (!error) return script;

    }

    return nil;

}


#pragma mark - navigation bar

- (void)showUpdateAvailableNavBar {

    self.navigationItem.title = NSLocalizedString(@"UPDATE AVAILABLE", nil);

    UIBarButtonItem *updateButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"UPDATE", nil)
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(reloadWebView)];
    updateButton.tintColor = [UIColor redColor];

    self.navigationItem.rightBarButtonItem = updateButton;

    [self.navigationController setNavigationBarHidden:NO
                                             animated:YES];

}

- (void)hideNavBar {

    if (!self.navigationController.navigationBarHidden) {

        [self.navigationController setNavigationBarHidden:YES
                                                 animated:YES];

    }

}







#pragma mark - white screen of death

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    self.lastUrl = self.webView.URL.absoluteString;
//    [self flushWebView];
}

- (void)applicationWillEnterForegroundNotification:(NSNotification *)notification {

    if (self.isViewLoaded && self.view.window != nil) {
        [self checkWebViewIsAlive];
    }

}

- (void)applicationDidBecomeActiveNotification:(NSNotification *)notification {

    if (self.isViewLoaded && self.view.window != nil) {

        [self.scriptMessageHandler syncSubscriptions];
        [self checkWebViewIsAlive];

    }

}

- (void)checkWebViewIsAlive {

    if (!self.wasLoadingOnce) return;

    if (!self.webView) {

        [self webviewIsDeadWithError:@"webview is nil"];
        return;

    }

    NSString *checkJS = @"window.document.body.childNodes.length";

    if (!self.webView.window) {
        NSLog(@"Webview is not visible");
        return;
    }

    [self.webView evaluateJavaScript:checkJS completionHandler:^(id result, NSError *error) {

        if (error) {

            [self webviewIsDeadWithError:error.localizedDescription];

        } else {

            if ([result isKindOfClass:[NSNumber class]] && [result isEqualToNumber:@(0)]) {

                [self webviewIsDeadWithError:@"result is 0"];

            } else {

                NSLog(@"checkWebViewIsAlive OK");

            }

        }

    }];

}

- (void)webviewIsDeadWithError:(NSString *)errorString {

    errorString = [NSString stringWithFormat:@"checkWebViewIsAlive error: %@, reload webView", errorString];
    [self.logger saveLogMessageWithText:errorString
                                numType:STMLogMessageTypeError];

    [self webViewInit];

}


#pragma mark - view lifecycle

- (void)addObservers {

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    //    [nc addObserver:self
    //           selector:@selector(applicationWillEnterForegroundNotification:)
    //               name:UIApplicationWillEnterForegroundNotification
    //             object:nil];

    [nc addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];

    [nc addObserver:self
           selector:@selector(applicationDidBecomeActiveNotification:)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

    [nc addObserver:self
           selector:@selector(haveUnsyncedObjects)
               name:NOTIFICATION_SYNCER_HAVE_UNSYNCED_OBJECTS
             object:nil];

    [nc addObserver:self
           selector:@selector(haveNoUnsyncedObjects)
               name:NOTIFICATION_SYNCER_HAVE_NO_UNSYNCED_OBJECTS
             object:nil];

    [nc addObserver:self
           selector:@selector(syncerIsSendingData)
               name:NOTIFICATION_SYNCER_SEND_STARTED
             object:nil];

}

- (void)customInit {

    [self addObservers];
    [self webViewInit];

}

- (void)viewDidLoad {

    [super viewDidLoad];
    [self customInit];

}

- (void)didReceiveMemoryWarning {

    if (self.isViewLoaded) {

        if (self.view.window == nil) {

            [self handleMemoryWarning];

        } else if ([STMFunctions isAppInBackground]) {

            [self handleMemoryWarning];

        }

    }

    [super didReceiveMemoryWarning];

}

- (void)handleMemoryWarning {

    NSString *logMessage = [NSString stringWithFormat:@"%@ receive memory warning.", NSStringFromClass([self class])];

    [self.logger importantMessage:logMessage];

    if ([STMFunctions isAppInBackground]) {
        self.lastUrl = self.webView.URL.absoluteString;
        logMessage = [NSString stringWithFormat:@"%@ set it's webView to nil. %@", NSStringFromClass([self class]), [STMFunctions memoryStatistic]];
        [self.logger importantMessage:logMessage];
        [self flushWebView];
    }

}


- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];

    [self checkWebViewIsAlive];

    if (self.iOSModeBarCodeScanner) {
        self.iOSModeBarCodeScanner.delegate = self;
    }

}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}


@end
