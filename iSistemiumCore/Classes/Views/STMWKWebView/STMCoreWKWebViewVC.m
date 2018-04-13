//
//  STMCoreWKWebViewVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreWKWebViewVC.h"
#import <WebKit/WebKit.h>

#import "STMCoreSessionManager.h"
#import "STMCoreSession.h"
#import "STMCoreAuthController.h"
#import "STMSoundController.h"
#import "STMCoreObjectsController.h"
#import "STMRemoteController.h"
#import "STMCoreAppManifestHandler.h"

#import "STMCoreRootTBC.h"
#import "STMStoryboard.h"

#import "STMFunctions.h"
#import "STMCoreUI.h"

#import "STMScriptMessageHandler.h"


@interface STMCoreWKWebViewVC () <WKNavigationDelegate,
WKScriptMessageHandler,
UIAlertViewDelegate,
STMBarCodeScannerDelegate>

@property (weak, nonatomic) IBOutlet UIView *localView;
@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic) BOOL isAuthorizing;
@property (nonatomic) BOOL wasLoadingOnce;

@property (nonatomic, strong) STMSpinnerView *spinnerView;
@property (nonatomic, strong) STMBarCodeScanner *iOSModeBarCodeScanner;
@property (nonatomic, strong) STMCoreAppManifestHandler *appManifestHandler;
@property (nonatomic, strong) STMLogger *logger;

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

@property (nonatomic, strong) NSObject <STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMModelling, STMPersistingObserving> * persistenceDelegate;

@end


@implementation STMCoreWKWebViewVC

- (NSObject <STMPersistingPromised,STMPersistingAsync,STMPersistingSync> *)persistenceDelegate {
    
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

- (STMLogger *)logger {
    
    if (!_logger) {
        _logger = [STMLogger sharedLogger];
    }
    return _logger;
    
}

- (NSString *)iSistemiumIOSCallbackJSFunction {
    return @"iSistemiumIOSCallback";
}

- (NSString *)iSistemiumIOSErrorCallbackJSFunction {
    return @"iSistemiumIOSErrorCallback";
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
            
            STMStoryboard *storyboard = (STMStoryboard *)self.storyboard;
            _webViewStoryboardParameters = storyboard.parameters;
            
        } else {
            
            _webViewStoryboardParameters = @{};
            
        }
        
    }
    return _webViewStoryboardParameters;
    
}

- (NSString *)webViewUrlString {
    
//        return @"http://maxbook.local:3000";
    //    return @"https://isissales.sistemium.com/";
    //    return @"https://sistemium.com";
    
    NSString *webViewUrlString = self.webViewStoryboardParameters[@"url"];
    return webViewUrlString ? webViewUrlString : @"https://sistemium.com";
    
}

- (NSString *)webViewAppManifestURI {
    
//        return nil;
    //    return @"https://isd.sistemium.com/app.manifest";
    //    return @"https://r50.sistemium.com/app.manifest";
    //    return @"https://sistemium.com/r50/tp/cache.manifest.php";
    
    return self.webViewStoryboardParameters[@"appManifestURI"];
    
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
        
        [self loadLocalHTML];
        
    } else {
        
        //    [self.webView reloadFromOrigin];
        
        NSString *wvUrl = [self webViewUrlString];
        
        __block NSString *jsString = [NSString stringWithFormat:@"('%@'.lastIndexOf(location.origin) >= 0) ? location.reload (true) : location.replace ('%@')", wvUrl, wvUrl];
        
        [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            
            if (error) {
                
                NSLog(@"evaluate \"%@\" with error: %@", jsString, error.localizedDescription);
                NSLog(@"trying to reload webView with loadRequest method");
                
                [self loadWebView];
                
            }
            
        }];
        
    }
    
}

- (void)loadWebView {
    
    [self.view addSubview:self.spinnerView];
    
    if ([self webViewAppManifestURI]) {
        
        [self loadLocalHTML];
        
    } else {
        
        self.isAuthorizing = NO;
        
        NSString *urlString = [self webViewUrlString];
        [self loadURLString:urlString];
        
    }
    
}


#pragma mark - load from remote URL

- (void)authLoadWebView {
    
    self.isAuthorizing = YES;
    
    NSString *accessToken = [STMCoreAuthController authController].accessToken;
    
    //    NSLog(@"accessToken %@", accessToken);
    
    NSString *urlString = [self webViewUrlString];
    urlString = [NSString stringWithFormat:@"%@?access-token=%@", urlString, accessToken];
    
    [self loadURLString:urlString];
    
}

- (void)loadURLString:(NSString *)urlString {
    
//    [self.logger saveLogMessageWithText:[NSString stringWithFormat:@"loadURL: %@", urlString]
//                                numType:STMLogMessageTypeImportant];
    
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
    
//    [self.logger saveLogMessageWithText:@"startLoadLocalHTML"
//                                numType:STMLogMessageTypeImportant];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.appManifestHandler startLoadLocalHTML];
    });
    
}

- (void)loadUrl:(NSURL *)fileUrl atBaseDir:(NSString *)baseDir {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
//        NSString *logMessage = [NSString stringWithFormat:@"load fileurl: %@", fileUrl];
//        [self.logger saveLogMessageWithText:logMessage
//                                    numType:STMLogMessageTypeImportant];
        
        if ([self.webView respondsToSelector:@selector(loadFileURL:allowingReadAccessToURL:)]) {
            
            [self.webView loadFileURL:fileUrl allowingReadAccessToURL:[NSURL fileURLWithPath:baseDir]];
            
        } else {
            
            NSString *logMessage = @"u should not use loadFileURL:allowingReadAccessToURL: before iOS 9.0";
            [self.logger  errorMessage:logMessage];
            
        }
        
    });
    
}

- (void)loadHTML:(NSString *)html atBaseDir:(NSString *)baseDir {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
//        NSString *logMessage = [NSString stringWithFormat:@"loadHTMLString, length: %@", @(html.length)];
//        [self.logger saveLogMessageWithText:logMessage
//                                    numType:STMLogMessageTypeImportant];
        
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
    
    //    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor redColor]}];
    
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


#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    
//    NSString *logMessage = [NSString stringWithFormat:@"webView didCommitNavigation %@", webView.URL];
//    [self.logger saveLogMessageWithText:logMessage
//                                numType:STMLogMessageTypeImportant];
    
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
    [self webView:webView
             fail:@"didFailNavigation"
        withError:error.localizedDescription];
    
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
    [self webView:webView
             fail:@"didFailProvisionalNavigation"
        withError:error.localizedDescription];
    
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    
    NSString *logMessage = [NSString stringWithFormat:@"webViewWebContentProcessDidTerminate %@", webView.URL];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeError];
    
    if ([STMFunctions isAppInBackground]) {
        [self flushWebView];
    } else {
        [self webViewAppManifestURI] ? [self loadLocalHTML] : [self loadURL:webView.URL];
    }
    
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    //    NSLogMethodName;
    completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
    
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    //    NSLogMethodName;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    //    NSLogMethodName;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    
    //    NSLogMethodName;
    decisionHandler(WKNavigationResponsePolicyAllow);
    
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    //    NSLog(@"---- webView decidePolicyForNavigationAction");
    //
    //    NSLog(@"scheme %@", navigationAction.request.URL.scheme);
    //    NSLog(@"request %@", navigationAction.request)
    //    NSLog(@"HTTPMethod %@", navigationAction.request.HTTPMethod)
    //    NSLog(@"HTTPBody %@", navigationAction.request.HTTPBody)
    
    UIApplication *app = [UIApplication sharedApplication];
    NSURL *url = navigationAction.request.URL;
    
    if ([url.scheme isEqualToString:@"tel"]) {
        
        if ([app canOpenURL:url]) {
            
            [app openURL:url];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
            
        }
        
    }

    decisionHandler(WKNavigationActionPolicyAllow);
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
//    NSString *logMessage = [NSString stringWithFormat:@"webView didFinishNavigation %@", webView.URL];
//    [self.logger saveLogMessageWithText:logMessage
//                                numType:STMLogMessageTypeImportant];
    
    self.wasLoadingOnce = YES;
    [self cancelWatingTimeout];
    
    NSString *authCheck = [self webViewAuthCheckJS];
    
    (authCheck) ? [self authCheckWithJS:authCheck] : [self.spinnerView removeFromSuperview];
    
}

- (void)authCheckWithJS:(NSString *)authCheck {
    
    [self.webView evaluateJavaScript:authCheck completionHandler:^(id result, NSError *error) {
        
        NSString *resultString = nil;
        
        if (!error) {
            
            if (result) {
                
                resultString = [NSString stringWithFormat:@"%@", result];
                
                NSString *bsAccessToken = resultString;
                NSLog(@"bsAccessToken %@", bsAccessToken);
                
                if ([bsAccessToken isEqualToString:@""] || [result isKindOfClass:[NSNull class]]) {
                    
                    if (!self.isAuthorizing) {
                        
                        NSLog(@"no bsAccessToken, go to authorization");
                        
                        [self authLoadWebView];
                        
                    }
                    
                } else {
                    
                    self.isAuthorizing = NO;
                    [self.spinnerView removeFromSuperview];
                    
                }
                
            }
            
        } else {
            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
        }
        
    }];
    
}

- (void)webView:(WKWebView *)webView fail:(NSString *)failString withError:(NSString *)errorString {

    [self cancelWaitingTimeout];

    if (webView && failString && errorString) {
        
        NSString *logMessage = [NSString stringWithFormat:@"webView %@ %@ withError: %@", webView.URL, failString, errorString];
        [self.logger saveLogMessageWithText:logMessage
                                    numType:STMLogMessageTypeError];
        
    }
    
    [self.spinnerView removeFromSuperview];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"ERROR", nil)
                                 message:NSLocalizedString(@"WEBVIEW FAIL TO LOAD", nil)
                          preferredStyle:UIAlertControllerStyleAlert];
        

        UIAlertAction *yesButton = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"OK", nil)
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction * action) {
                            [self reloadWebView];
                        }];

        UIAlertAction* noButton = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"CANCEL", nil)
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction * action) {
                            //Handle no, thanks button
                        }];

        [alert addAction:yesButton];
        [alert addAction:noButton];

        [self presentViewController:alert animated:YES completion:nil];

    }];
    
}

- (void)cancelWaitingTimeout {

    [STMCoreWKWebViewVC cancelPreviousPerformRequestsWithTarget:self
                                                       selector:@selector(timeoutReached)
                                                         object:nil];

}


#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if ([message.name isEqualToString:WK_MESSAGE_SCANNER_ON]) {
        
        NSLog(@"%@ %@", message.name, message.body);
        
    } else {
        
        if ([message.body isKindOfClass:[NSDictionary class]]) {
            
            NSNumber *requestId = message.body[@"options"][@"requestId"];
            NSLog(@"%@ requestId: %@", message.name, requestId);
            
        } else {
            
            NSLog(@"%@ %@", message.name, message.body);
            
            [self callbackWithError:@"message.body is not a NSDictionary class"
                         parameters:@{@"messageBody": [message.body description]}];
            return;
            
        }
        
    }
    
    if ([message.name isEqualToString:WK_MESSAGE_ERROR_CATCHER]) {
        
        [self handleErrorCatcherMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_POST]) {
        
        NSLog(@"POST");
        
    } else if ([message.name isEqualToString:WK_MESSAGE_GET]) {
        
        NSLog(@"GET");
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SOUND]) {
        
        [self handleSoundMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SCANNER_ON]) {
        
        [self handleScannerMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_TABBAR]) {
        
        [self handleTabbarMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_REMOTE_CONTROL]) {
        
        [self handleRemoteControlMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_ROLES]) {
        
        [self handleRolesMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_CHECKIN]) {
        
        [self handleCheckinMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_TAKE_PHOTO]) {
        
        [self.scriptMessageHandler handleTakePhotoMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_CMERA_ROLL]) {
        
        [self.scriptMessageHandler handleSendToCameraRollMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_LOAD_IMAGE]) {
        
        [self.scriptMessageHandler handleLoadImageMessage:message];
        
        // persistence messages
        
    } else if ([message.name isEqualToString:WK_MESSAGE_GET_PICTURE]) {
        
        [self.scriptMessageHandler handleGetPictureMessage:message];
        
    } else if ([@[WK_MESSAGE_FIND, WK_MESSAGE_FIND_ALL] containsObject:message.name]) {
        
        [self.scriptMessageHandler receiveFindMessage:message];
        
    } else if ([@[WK_MESSAGE_UPDATE, WK_MESSAGE_UPDATE_ALL] containsObject:message.name]) {
        
        [self.scriptMessageHandler receiveUpdateMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SUBSCRIBE]) {
        
        [self.scriptMessageHandler receiveSubscribeMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_DESTROY]) {
        
        [self.scriptMessageHandler receiveDestroyMessage:message];
        
    }else if ([message.name isEqualToString:WK_MESSAGE_UNSYNCED_INFO]) {

        [self handleUnsyncedInfoMessage:message];

    }else if ([message.name isEqualToString:WK_MESSAGE_SAVE_IMAGE]) {
        
        [self.scriptMessageHandler handleSaveImageMessage:message];
        
    }else if ([message.name isEqualToString:WK_MESSAGE_COPY_CLIPBOARD]) {
        
        [self.scriptMessageHandler handleCopyToClipboardMessage:message];
        
    }
    
}

- (void)handleErrorCatcherMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSString *logMessage = [NSString stringWithFormat:@"JSErrorCatcher: %@", parameters.description];
    
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeError];
    
}

- (void)handleCheckinMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSNumber *requestId = [parameters[@"options"][@"requestId"] isKindOfClass:[NSNumber class]] ? parameters[@"options"][@"requestId"] : nil;
    
    if (requestId) {
        
        self.checkinCallbackJSFunction = parameters[@"callback"];
        
        NSDictionary *checkinData = [parameters[@"data"] isKindOfClass:[NSDictionary class]] ? parameters[@"data"] : @{};
        
        self.checkinMessageParameters[requestId] = parameters;
        
        NSNumber *accuracy = parameters[@"accuracy"];
        NSTimeInterval timeout = [parameters[@"timeout"] doubleValue] / 1000;
        
        STMCoreLocationTracker *locationTracker = [(STMCoreSession *)[STMCoreSessionManager sharedManager].currentSession locationTracker];
        
        [locationTracker checkinWithAccuracy:accuracy
                                 checkinData:checkinData
                                   requestId:requestId
                                     timeout:timeout
                                    delegate:self];
        
    }
    
}

- (void)handleRolesMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSString *rolesCallbackJSFunction = parameters[@"callback"];
    
    NSDictionary *roles = [STMCoreAuthController authController].rolesResponse;
    
    if (roles) {
        [self callbackWithData:@[roles] parameters:parameters jsCallbackFunction:rolesCallbackJSFunction];
    } else {
        [self callbackWithError:@"have no roles" parameters:parameters];
    }
    
}

- (void)handleRemoteControlMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    self.remoteControlCallbackJSFunction = parameters[@"callback"];
    
    NSError *error = nil;
    [STMRemoteController receiveRemoteCommands:parameters[@"remoteCommands"] error:&error];
    
    if (!error) {
        [self callbackWithData:@[@"remoteCommands ok"] parameters:parameters jsCallbackFunction:self.remoteControlCallbackJSFunction];
    } else {
        [self callbackWithError:error.localizedDescription parameters:parameters];
    }
    
}

- (void)handleScannerMessage:(WKScriptMessage *)message {
    
    self.scannerScanJSFunction = message.body[@"scanCallback"];
    self.scannerPowerButtonJSFunction = message.body[@"powerButtonCallback"];
    
    [self startBarcodeScanning];
    
}

- (void)handleUnsyncedInfoMessage:(WKScriptMessage *)message {
    self.unsyncedInfoJSFunction = message.body[@"unsyncedInfoCallback"];
}

- (void)handleTabbarMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSString *action = parameters[@"action"];
    
    if ([action isEqualToString:@"show"]) {
        
        [[STMCoreRootTBC sharedRootVC] showTabBar];
        
        CGFloat tabbarHeight = CGRectGetHeight(self.tabBarController.tabBar.frame);
        UIEdgeInsets insets = self.webView.scrollView.contentInset;
        self.webView.scrollView.contentInset = UIEdgeInsetsMake(insets.top, insets.left, tabbarHeight, insets.right);
        
        UIEdgeInsets scrollIndicatorInsets = self.webView.scrollView.scrollIndicatorInsets;
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(scrollIndicatorInsets.top, scrollIndicatorInsets.left, tabbarHeight, scrollIndicatorInsets.right);
        
        [self callbackWithData:@[@"tabbar show success"] parameters:parameters];
        
    } else if ([action isEqualToString:@"hide"]) {
        
        if (self.isInActiveTab) {
            
            [[STMCoreRootTBC sharedRootVC] hideTabBar];
            
            UIEdgeInsets insets = self.webView.scrollView.contentInset;
            self.webView.scrollView.contentInset = UIEdgeInsetsMake(insets.top, insets.left, 0, insets.right);
            
            UIEdgeInsets scrollIndicatorInsets = self.webView.scrollView.scrollIndicatorInsets;
            self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(scrollIndicatorInsets.top, scrollIndicatorInsets.left, 0, scrollIndicatorInsets.right);
            
            [self callbackWithData:@[@"tabbar hide success"] parameters:parameters];
            
        } else {
            [self callbackWithError:@"webview is not in active tab" parameters:parameters];
        }
        
    } else {
        [self callbackWithError:@"unknown action for tabbar message" parameters:parameters];
    }
    
}

- (void)handleSoundMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSString *messageSound = parameters[@"sound"];
    NSString *messageText = parameters[@"text"];
    self.soundCallbackJSFunction = parameters[@"callBack"];
    
    float rate = (parameters[@"rate"]) ? [parameters[@"rate"] floatValue] : 0.5;
    float pitch = (parameters[@"pitch"]) ? [parameters[@"pitch"] floatValue] : 1;
    
    [STMSoundController sharedController].sender = self;
    
    if (messageSound) {
        
        if ([messageSound isEqualToString:@"alert"]) {
            
            (messageText) ? [STMSoundController alertSay:messageText withRate:rate pitch:pitch] : [STMSoundController playAlert];
            
        } else if ([messageSound isEqualToString:@"ok"]) {
            
            (messageText) ? [STMSoundController okSay:messageText withRate:rate pitch:pitch] : [STMSoundController playOk];
            
        } else {
            
            [self callbackWithError:@"unknown sound parameter"
                         parameters:parameters];
            
            (messageText) ? [STMSoundController sayText:messageText withRate:rate pitch:pitch] : nil;
            
        }
        
    } else if (messageText) {
        
        [STMSoundController sayText:messageText withRate:rate pitch:pitch];
        
    } else {
        
        [STMSoundController sharedController].sender = nil;
        
        [self callbackWithError:@"message.body have no text ot sound to play"
                     parameters:parameters];
        
    }
    
}


#pragma mark - callbacks

- (void)callbackWithData:(id)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
#ifdef DEBUG
    
    NSNumber *requestId = parameters[@"options"][@"requestId"];
    
    if (requestId && [data isKindOfClass:[NSArray class]]) {
        
        NSString *entityName = parameters[@"entity"] ? parameters[@"entity"] : parameters[@"entityName"] ? parameters[@"entityName"] : @"unknown entity";
        
        if ([entityName isEqualToString:@"unknown entity"]) {
            NSLog(@"parameters %@", parameters);
        }
        
        NSLog(@"requestId %@ (%@) callbackWithData: %@ objects", requestId, entityName, @([(NSArray *)data count]));
        
    } else {
        
        if ([parameters[@"reason"] isEqualToString:@"subscription"]) {
            
            NSString *entityName = [[(NSArray *)data firstObject] valueForKey:@"entity"];
            
            NSLog(@"subscription %@ callbackWithData: %@ objects", entityName, @([(NSArray *)data count]));
            
        } else {
            
            NSLog(@"callbackWithData: %@ for message parameters: %@", data, parameters);
            
        }
        
    }
    
#endif
    
    if (!jsCallbackFunction) {
        NSLog(@"have no jsCallbackFunction");
        return;
    }
    
    //    NSLog(@"callbackWithData %@", @([NSDate timeIntervalSinceReferenceDate]));
    
    NSMutableArray *arguments = @[].mutableCopy;
    
    if (data) [arguments addObject:data];
    if (parameters) [arguments addObject:parameters];
    
    NSString *jsFunction = [NSString stringWithFormat:@"window.%1$@ && %1$@.apply(null,%2$@)", jsCallbackFunction, [STMFunctions jsonStringFromArray:arguments]];
    
    //    NSLog(@"data complete %@", @([NSDate timeIntervalSinceReferenceDate]));
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        if (!self.webView.window){
//            NSLog(@"Not Visible, but handled");
            return;
        }
        
        [self.webView evaluateJavaScript:jsFunction completionHandler:^(id result, NSError *error) {
            
            //        NSLog(@"evaluateJavaScript completionHandler %@", @([NSDate timeIntervalSinceReferenceDate]));
            if (error) {
                NSLog(@"Error evaluating function '%@': '%@'", jsCallbackFunction, error.localizedDescription);
            }
            
        }];
    }];

}
- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters {
    [self callbackWithData:data parameters:parameters jsCallbackFunction:self.iSistemiumIOSCallbackJSFunction];
}

- (void)callbackWithError:(NSString *)errorDescription parameters:(NSDictionary *)parameters {
    
#ifdef DEBUG
    
    NSNumber *requestId = parameters[@"options"][@"requestId"];
    
    if (requestId) {
        NSLog(@"requestId %@ callbackWithError: %@", requestId, errorDescription);
    } else {
        NSLog(@"callbackWithError: %@ for message parameters: %@", errorDescription, parameters);
    }
    
#endif
    
    NSMutableArray *arguments = @[].mutableCopy;
    
    [arguments addObject:errorDescription];
    [arguments addObject:parameters];
    
    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)", self.iSistemiumIOSErrorCallbackJSFunction, [STMFunctions jsonStringFromArray:arguments]];
    
    [self.webView evaluateJavaScript:jsFunction completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
    }];
    
}


#pragma mark - evaluateJavaScriptAndWait

int counter = 0;

- (void)evaluateJavaScriptAndWait:(NSString *)javascript {
    
    counter++;
    
    [self.webView evaluateJavaScript:javascript completionHandler:^(NSString *result, NSError *error){
        
        if (error || SYSTEM_VERSION < 10.0 || [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            return;
        }
        
        int counterWas = counter;
        int count = 0;
        
        while(count++ < 50 && counter == counterWas) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        
        //NSLog(@"evaluateJavaScriptAndWait finish %d", counter);
        
    }];
    
}

#pragma mark - STMCheckinDelegate

- (void)getCheckinLocation:(NSDictionary *)checkinLocation forRequestId:(NSNumber *)requestId {
    
    if (requestId) {
        
        NSDictionary *parameters = self.checkinMessageParameters[requestId];
        
        [self callbackWithData:@[checkinLocation]
                    parameters:parameters
            jsCallbackFunction:self.checkinCallbackJSFunction];
        
        [self.checkinMessageParameters removeObjectForKey:requestId];
        
    }
    
}

- (void)checkinLocationError:(NSString *)errorString forRequestId:(NSNumber *)requestId {
    
    if (requestId) {
        
        NSDictionary *parameters = self.checkinMessageParameters[requestId];
        
        [self callbackWithError:errorString
                     parameters:parameters];
        
        [self.checkinMessageParameters removeObjectForKey:requestId];
        
    }
    
}


#pragma mark - STMSoundCallbackable

- (void)didFinishSpeaking {
    
    [self callbackWithData:@[@"didFinishSpeaking"]
                parameters:nil
        jsCallbackFunction:self.soundCallbackJSFunction];
    
}

#pragma mark - barcode scanning

- (void)startBarcodeScanning {
    [self startIOSModeScanner];
}

- (void)startIOSModeScanner {
    
    self.iOSModeBarCodeScanner = [[STMBarCodeScanner alloc] initWithMode:STMBarCodeScannerIOSMode];
    self.iOSModeBarCodeScanner.delegate = self;
    [self.iOSModeBarCodeScanner startScan];
    
    if ([self.iOSModeBarCodeScanner isDeviceConnected]) {
        [self scannerIsConnected];
    }
    
}

- (void)stopBarcodeScanning {
    [self stopIOSModeScanner];
}

- (void)stopIOSModeScanner {
    
    [self.iOSModeBarCodeScanner stopScan];
    self.iOSModeBarCodeScanner = nil;
    
    [self scannerIsDisconnected];
    
}

- (void)scannerIsConnected {
    
}

- (void)scannerIsDisconnected {
    
}


#pragma mark - STMBarCodeScannerDelegate

- (UIView *)viewForScanner:(STMBarCodeScanner *)scanner {
    return self.view;
}

- (void)barCodeScanner:(STMBarCodeScanner *)scanner receiveBarCodeScan:(STMBarCodeScan *)barCodeScan withType:(STMBarCodeScannedType)type {
    
    if (self.isInActiveTab) {
        
        //        NSMutableArray *arguments = @[].mutableCopy;
        //
        //        NSString *barcode = barCodeScan.code;
        //        if (!barcode) barcode = @"";
        //        [arguments addObject:barcode];
        //
        //        NSString *typeString = [STMBarCodeController barCodeTypeStringForType:type];
        //        if (!typeString) typeString = @"";
        //        [arguments addObject:typeString];
        //
        //        NSDictionary *barcodeDic = [STMObjectsController dictionaryForJSWithObject:barCodeScan];
        //        [arguments addObject:barcodeDic];
        //
        //        NSLog(@"send received barcode %@ with type %@ to WKWebView", barcode, typeString);
        //
        //        NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)", self.receiveBarCodeJSFunction, [STMFunctions jsonStringFromArray:arguments]];
        //
        //        [self.webView evaluateJavaScript:jsFunction completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        //
        //        }];
        
    }
    
}

- (void)barCodeScanner:(STMBarCodeScanner *)scanner receiveBarCode:(NSString *)barcode withType:(STMBarCodeScannedType)type {

    if (!self.isInActiveTab || !barcode) {
        return;
    }

    NSMutableArray *arguments = [@[barcode] mutableCopy];

    [self checkBarCode:barcode withType:type arguments:arguments];

    [self evaluateReceiveBarCodeJSFunctionWithArguments:arguments.copy];


}

- (void)checkBarCode:(NSString *)barcode withType:(STMBarCodeScannedType)type arguments:(NSMutableArray *)arguments {
    
    NSString *typeString = [STMCoreBarCodeController barCodeTypeStringForType:type];
    
    if (!typeString) {
        
        NSLog(@"send received barcode %@ to WKWebView", barcode);
        return;
        
    }

    if (type != STMBarCodeTypeStockBatch) {
        
        NSLog(@"send received barcode %@ with type %@ to WKWebView", barcode, typeString);
        return;
        
    }

    [arguments addObject:typeString];
    
    NSDictionary *stockBatch = [STMCoreBarCodeController stockBatchForBarcode:barcode].firstObject;
    
    if (!stockBatch) {

        NSLog(@"send received barcode %@ with type %@ to WKWebView", barcode, typeString);
        return;

    }
    
    [arguments addObject:stockBatch];
    
    NSLog(@"send received barcode %@ with type %@ and stockBatch %@ to WKWebView", barcode, typeString, stockBatch);

}

- (void)evaluateReceiveBarCodeJSFunctionWithArguments:(NSArray *)arguments {
    
    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)", self.scannerScanJSFunction, [STMFunctions jsonStringFromArray:arguments]];
    
    [self evaluateJavaScriptAndWait:jsFunction];
    
}

- (void)powerButtonPressedOnBarCodeScanner:(STMBarCodeScanner *)scanner {
    
    if (self.isInActiveTab) {
        
        [self callbackWithData:@[@"powerButtonPressed"]
                    parameters:nil
            jsCallbackFunction:self.scannerPowerButtonJSFunction];
        
    }
    
}

- (void)barCodeScanner:(STMBarCodeScanner *)scanner receiveError:(NSError *)error {
    
}

- (void)deviceArrivalForBarCodeScanner:(STMBarCodeScanner *)scanner {
    
    if (scanner == self.iOSModeBarCodeScanner) {
        
        [STMSoundController say:NSLocalizedString(@"SCANNER DEVICE ARRIVAL", nil)];
        
        [self scannerIsConnected];
        
    }
    
}

- (void)deviceRemovalForBarCodeScanner:(STMBarCodeScanner *)scanner {
    
    if (scanner == self.iOSModeBarCodeScanner) {
        
        [STMSoundController say:NSLocalizedString(@"SCANNER DEVICE REMOVAL", nil)];
        
        [self scannerIsDisconnected];
        
    }
    
}


#pragma mark - white screen of death

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


#pragma mark - unsynced observers

- (void)haveUnsyncedObjects {
    
    if (!self.unsyncedInfoJSFunction) return;
    
    [self callbackWithData:@[@"haveUnsyncedObjects"]
                parameters:nil
        jsCallbackFunction:self.unsyncedInfoJSFunction];

}

- (void)haveNoUnsyncedObjects {

    if (!self.unsyncedInfoJSFunction) return;

    [self callbackWithData:@[@"haveNoUnsyncedObjects"]
                parameters:nil
        jsCallbackFunction:self.unsyncedInfoJSFunction];

}

- (void)syncerIsSendingData {
    
    if (!self.unsyncedInfoJSFunction) return;
    
    [self callbackWithData:@[@"syncerIsSendingData"]
                parameters:nil
        jsCallbackFunction:self.unsyncedInfoJSFunction];
    
}


#pragma mark - view lifecycle

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    //    [nc addObserver:self
    //           selector:@selector(applicationWillEnterForegroundNotification:)
    //               name:UIApplicationWillEnterForegroundNotification
    //             object:nil];
    
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
            
        } else if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            
            [self handleMemoryWarning];
            
        }
        
    }
    
    [super didReceiveMemoryWarning];
    
}

- (void)handleMemoryWarning {
    
    NSString *logMessage = [NSString stringWithFormat:@"%@ receive memory warning.", NSStringFromClass([self class])];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeImportant];
    
    if ([STMFunctions isAppInBackground]) {
        logMessage = [NSString stringWithFormat:@"%@ set it's webView to nil. %@", NSStringFromClass([self class]), [STMFunctions memoryStatistic]];
        [self.logger saveLogMessageWithText:logMessage
                                    numType:STMLogMessageTypeImportant];
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
