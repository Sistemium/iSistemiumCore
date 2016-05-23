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
#import "STMCoreAuthController.h"
#import "STMSoundController.h"
#import "STMCoreObjectsController.h"
#import "STMRemoteController.h"

#import "STMCoreRootTBC.h"
#import "STMStoryboard.h"

#import "STMFunctions.h"
#import "STMCoreUI.h"

#import "iSistemiumCore-Swift.h"


@interface STMCoreWKWebViewVC () <WKNavigationDelegate, WKScriptMessageHandler, STMBarCodeScannerDelegate>

@property (weak, nonatomic) IBOutlet UIView *localView;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic) BOOL isAuthorizing;
@property (nonatomic, strong) STMSpinnerView *spinnerView;

@property (nonatomic, strong) STMBarCodeScanner *iOSModeBarCodeScanner;

@property (nonatomic, strong) NSString *scannerScanJSFunction;
@property (nonatomic, strong) NSString *scannerPowerButtonJSFunction;
@property (nonatomic, strong) NSString *subscribeDataCallbackJSFunction;
@property (nonatomic, strong) NSString *iSistemiumIOSCallbackJSFunction;
@property (nonatomic, strong) NSString *iSistemiumIOSErrorCallbackJSFunction;
@property (nonatomic, strong) NSString *soundCallbackJSFunction;
@property (nonatomic, strong) NSString *remoteControlCallbackJSFunction;


@end


@implementation STMCoreWKWebViewVC

- (BOOL)isInActiveTab {
    return [self.tabBarController.selectedViewController isEqual:self.navigationController];
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

- (NSDictionary *)webViewSettings {
    
    NSDictionary *settings = [[STMCoreSessionManager sharedManager].currentSession.settingsController currentSettingsForGroup:@"webview"];
    return settings;
    
}

- (NSString *)webViewUrlString {
    
    if ([self.storyboard isKindOfClass:[STMStoryboard class]]) {
        
        STMStoryboard *storyboard = (STMStoryboard *)self.storyboard;
        NSString *url = storyboard.parameters[@"url"];
        return url;
        
    } else {
        
        return @"https://sistemium.com";
        
    }
    
}

- (NSString *)webViewAuthCheckJS {
    
    if ([self.storyboard isKindOfClass:[STMStoryboard class]]) {
        
        STMStoryboard *storyboard = (STMStoryboard *)self.storyboard;
        NSString *authCheck = storyboard.parameters[@"authCheck"];
        return authCheck;
        
    } else {
        return [[self webViewSettings] valueForKey:@"wv.session.check"];
    }
    
}

- (void)reloadWebView {
    
//    [self.webView reloadFromOrigin];
    
    NSString *wvUrl = [self webViewUrlString];
    
    __block NSString *jsString = [NSString stringWithFormat:@"'%@'.startsWith(location.origin) ? location.reload (true) : location.replace ('%@')", wvUrl, wvUrl];
    
    [self.webView evaluateJavaScript:jsString completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
        if (error) {
            
            NSLog(@"evaluate \"%@\" with error: %@", jsString, error.localizedDescription);
            NSLog(@"trying to reload webView with loadRequest method");
            
            [self loadWebView];
            
        }
        
    }];

}

- (void)loadWebView {
    
    [self.view addSubview:self.spinnerView];
    
    self.isAuthorizing = NO;
    
    NSString *urlString = [self webViewUrlString];
    [self loadURLString:urlString];
    
}

- (void)authLoadWebView {
    
    self.isAuthorizing = YES;
    
    NSString *accessToken = [STMCoreAuthController authController].accessToken;
    
    //    NSLog(@"accessToken %@", accessToken);
    
    NSString *urlString = [self webViewUrlString];
    urlString = [NSString stringWithFormat:@"%@?access-token=%@", urlString, accessToken];
    
    [self loadURLString:urlString];
    
}

- (void)loadURLString:(NSString *)urlString {
    
//    urlString = @"http://maxbook.local:3000/#/orders";
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
//    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
//    request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    request.cachePolicy = NSURLRequestUseProtocolCachePolicy;

//    NSLog(@"currentDiskUsage %d", [NSURLCache sharedURLCache].currentDiskUsage);
//    NSLog(@"currentMemoryUsage %d", [NSURLCache sharedURLCache].currentMemoryUsage);
//    
//    NSLog(@"cachedResponseForRequest %@", [[NSURLCache sharedURLCache] cachedResponseForRequest:request]);
//    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
    
    [self.webView loadRequest:request];
    
}


#pragma mark - webViewInit

- (void)webViewInit {
    
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    
    WKUserContentController *contentController = [[WKUserContentController alloc] init];
    
    for (NSString *messageName in WK_SCRIPT_MESSAGE_NAMES) {
        [contentController addScriptMessageHandler:self name:messageName];
    }
    
    configuration.userContentController = contentController;
    
    self.webView = [[WKWebView alloc] initWithFrame:self.localView.bounds configuration:configuration];
    
    [self.localView addSubview:self.webView];
    
    self.webView.navigationDelegate = self;
    [self loadWebView];
    
}


#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
//    NSLogMethodName;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
//    NSLogMethodName;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
//    NSLogMethodName;
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
    
    decisionHandler(WKNavigationActionPolicyAllow);
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    NSLog(@"------ didFinishNavigation %@", webView.URL);
    
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


#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if ([message.name isEqualToString:WK_MESSAGE_SCANNER_ON]) {
        
        NSLog(@"%@ %@", message.name, message.body);
        
    } else {
    
        if ([message.body isKindOfClass:[NSDictionary class]]) {
            
            NSString *requestId = message.body[@"options"][@"requestId"];
            NSLog(@"%@ requestId: %@", message.name, requestId);
            
        } else {
            
            NSLog(@"%@ %@", message.name, message.body);
            
            [self callbackWithError:@"message.body is not a NSDictionary class"
                         parameters:@{@"messageBody": [message.body description]}];
            return;
            
        }

    }
    
    if ([message.name isEqualToString:WK_MESSAGE_POST]) {
        
        NSLog(@"POST");
        
    } else if ([message.name isEqualToString:WK_MESSAGE_GET]) {

        NSLog(@"GET");

    } else if ([@[WK_MESSAGE_UPDATE, WK_MESSAGE_UPDATE_ALL] containsObject:message.name]) {
        
        [self handleKindOfUpdateMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SOUND]) {
        
        [self handleSoundMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SCANNER_ON]) {

        [self handleScannerMessage:message];
        
    } else if ([@[WK_MESSAGE_FIND, WK_MESSAGE_FIND_ALL] containsObject:message.name]) {
        
        [self handleKindOfFindMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_DESTROY]) {
        
        [self handleDestroyMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_TABBAR]) {
        
        [self handleTabbarMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SUBSCRIBE]) {
        
        [self handleSubscribeMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_REMOTE_CONTROL]) {
        
        [self handleRemoteControllMessage:message];
        
    }
    
}

- (void)handleRemoteControllMessage:(WKScriptMessage *)message {
    
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

- (void)handleSubscribeMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;

    NSLog(@"%@", parameters);

    if ([parameters[@"entities"] isKindOfClass:[NSArray class]]) {
        
        self.subscribeDataCallbackJSFunction = parameters[@"dataCallback"];
        
        NSArray *entities = parameters[@"entities"];
        
        NSError *error = nil;

        if ([STMCoreObjectsController subscribeViewController:self toEntities:entities error:&error]) {
        
            [self callbackWithData:@[@"subscribe to entities success"] parameters:parameters jsCallbackFunction:parameters[@"callback"]];

        } else {
            
            [self callbackWithError:error.localizedDescription
                         parameters:parameters];
            
        }
        
    } else {
        
        [self callbackWithError:@"message.parameters.entities is not a NSArray class"
                     parameters:parameters];

    }
    
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
        
        [[STMCoreRootTBC sharedRootVC] hideTabBar];
        
        UIEdgeInsets insets = self.webView.scrollView.contentInset;
        self.webView.scrollView.contentInset = UIEdgeInsetsMake(insets.top, insets.left, 0, insets.right);

        UIEdgeInsets scrollIndicatorInsets = self.webView.scrollView.scrollIndicatorInsets;
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(scrollIndicatorInsets.top, scrollIndicatorInsets.left, 0, scrollIndicatorInsets.right);
        
        [self callbackWithData:@[@"tabbar hide success"] parameters:parameters];

    } else {
        [self callbackWithError:@"unknown action for tabbar message" parameters:parameters];
    }

}

- (void)handleDestroyMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;

    NSError *error = nil;
    NSArray *result = [STMCoreObjectsController destroyObjectFromScriptMessage:message error:&error];
    
    if (error) {
        [self callbackWithError:error.localizedDescription parameters:parameters];
    } else {
        [self callbackWithData:result parameters:parameters];
    }
    
}

- (void)handleKindOfUpdateMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;

    NSError *error = nil;
    NSArray *result = [STMCoreObjectsController updateObjectsFromScriptMessage:message error:&error];

    if (result.count > 0) [self callbackWithData:result parameters:parameters];
    if (error) [self callbackWithError:error.localizedDescription parameters:parameters];
        
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

- (void)handleKindOfFindMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    
    NSError *error = nil;

    NSArray *result = [STMCoreObjectsController arrayOfObjectsRequestedByScriptMessage:message error:&error];

    if (!error) {
        
        [self callbackWithData:result
                    parameters:parameters];
        
    } else {
        
        [self callbackWithError:error.localizedDescription
                     parameters:parameters];
        
    }
        
}

- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
#ifdef DEBUG
    
    NSString *requestId = parameters[@"options"][@"requestId"];

    if (requestId) {
        NSLog(@"requestId %@ callbackWithData: %@ objects", requestId, @(data.count));
    } else {
        NSLog(@"callbackWithData: %@ objects for message parameters: %@", @(data.count), parameters);
    }
    
#endif

    NSMutableArray *arguments = @[].mutableCopy;
    
    if (data) [arguments addObject:data];
    if (parameters) [arguments addObject:parameters];
    
    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)", jsCallbackFunction, [STMFunctions jsonStringFromArray:arguments]];
    
    [self.webView evaluateJavaScript:jsFunction completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
    }];
    
}
- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters {
    [self callbackWithData:data parameters:parameters jsCallbackFunction:self.iSistemiumIOSCallbackJSFunction];
}

- (void)callbackWithError:(NSString *)errorDescription parameters:(NSDictionary *)parameters {
    
#ifdef DEBUG

    NSString *requestId = parameters[@"options"][@"requestId"];
    
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


#pragma mark - STMSoundCallbackable

- (void)didFinishSpeaking {
    [self callbackWithData:@[@"didFinishSpeaking"] parameters:nil jsCallbackFunction:self.soundCallbackJSFunction];
}


#pragma mark - STMEntitiesSubscribable

- (void)subscribedEntitiesObjectWasReceived:(NSDictionary *)objectDic {

    NSArray *result = @[objectDic];
    NSDictionary *parameters = @{@"reason": @"subscription"};
    
    [self callbackWithData:result
                parameters:parameters
        jsCallbackFunction:self.subscribeDataCallbackJSFunction];

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
    
    if (self.isInActiveTab) {
        
        if (barcode) {
        
            NSMutableArray *arguments = @[].mutableCopy;

            [arguments addObject:barcode];

            [self checkBarCode:barcode withType:type arguments:arguments];

            [self evaluateReceiveBarCodeJSFunctionWithArguments:arguments];

        }
        
    }
    
}

- (void)checkBarCode:(NSString *)barcode withType:(STMBarCodeScannedType)type arguments:(NSMutableArray *)arguments {
    
}

- (void)evaluateReceiveBarCodeJSFunctionWithArguments:(NSArray *)arguments {
        
    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)", self.scannerScanJSFunction, [STMFunctions jsonStringFromArray:arguments]];
        
        [self.webView evaluateJavaScript:jsFunction completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            
        }];

    }
    
- (void)powerButtonPressedOnBarCodeScanner:(STMBarCodeScanner *)scanner {
    
    if (self.isInActiveTab) {
        [self callbackWithData:@[@"powerButtonPressed"] parameters:nil jsCallbackFunction:self.scannerPowerButtonJSFunction];
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


#pragma mark - view lifecycle

- (void)customInit {
    [self webViewInit];
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
}

- (void)didReceiveMemoryWarning {
    
    if ([STMFunctions shouldHandleMemoryWarningFromVC:self]) {
        [STMFunctions nilifyViewForVC:self];
    }
    
    [super didReceiveMemoryWarning];
    
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    if (self.iOSModeBarCodeScanner) {
        self.iOSModeBarCodeScanner.delegate = self;
    }
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}


@end
