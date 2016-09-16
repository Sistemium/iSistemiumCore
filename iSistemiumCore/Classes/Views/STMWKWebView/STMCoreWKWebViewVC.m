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
#import "STMCorePicturesController.h"
#import "STMCorePhotosController.h"
#import "STMCoreAppManifestHandler.h"

#import "STMCoreRootTBC.h"
#import "STMStoryboard.h"
#import "STMImagePickerController.h"
#import "STMImagePickerOwnerProtocol.h"

#import "STMFunctions.h"
#import "STMCoreUI.h"


@interface STMCoreWKWebViewVC () <WKNavigationDelegate, WKScriptMessageHandler, STMBarCodeScannerDelegate, STMImagePickerOwnerProtocol>

@property (weak, nonatomic) IBOutlet UIView *localView;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic) BOOL isAuthorizing;
@property (nonatomic) BOOL wasLoadingOnce;
@property (nonatomic, strong) STMSpinnerView *spinnerView;

@property (nonatomic, strong) STMBarCodeScanner *iOSModeBarCodeScanner;

@property (nonatomic, strong) NSString *scannerScanJSFunction;
@property (nonatomic, strong) NSString *scannerPowerButtonJSFunction;
@property (nonatomic, strong) NSString *subscribeDataCallbackJSFunction;
@property (nonatomic, strong) NSString *iSistemiumIOSCallbackJSFunction;
@property (nonatomic, strong) NSString *iSistemiumIOSErrorCallbackJSFunction;
@property (nonatomic, strong) NSString *soundCallbackJSFunction;
@property (nonatomic, strong) NSString *remoteControlCallbackJSFunction;
@property (nonatomic, strong) NSString *checkinCallbackJSFunction;
@property (nonatomic, strong) NSString *takePhotoCallbackJSFunction;
@property (nonatomic, strong) NSMutableDictionary *getPictureCallbackJSFunctions;

@property (nonatomic, strong) NSMutableDictionary *checkinMessageParameters;
@property (nonatomic, strong) NSDictionary *takePhotoMessageParameters;
@property (nonatomic, strong) NSMutableDictionary *getPictureMessageParameters;

@property (nonatomic, strong) NSString *photoEntityName;
@property (nonatomic, strong) NSDictionary *photoData;

@property (nonatomic) BOOL waitingCheckinLocation;
@property (nonatomic) BOOL waitingPhoto;

@property (nonatomic, strong) STMCoreAppManifestHandler *appManifestHandler;


@end


@implementation STMCoreWKWebViewVC

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

- (NSMutableDictionary *)getPictureCallbackJSFunctions {
    
    if (!_getPictureCallbackJSFunctions) {
        _getPictureCallbackJSFunctions = @{}.mutableCopy;
    }
    return _getPictureCallbackJSFunctions;
    
}

- (NSMutableDictionary *)getPictureMessageParameters {
    
    if (!_getPictureMessageParameters) {
        _getPictureMessageParameters = @{}.mutableCopy;
    }
    return _getPictureMessageParameters;
    
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

//    return @"http://maxbook.local:3000";
    //return @"https://isissales.sistemium.com/";
    
    NSString *webViewUrlString = self.webViewStoryboardParameters[@"url"];
    
    return webViewUrlString ? webViewUrlString : @"https://sistemium.com";
    
}

- (NSString *)webViewAppManifestURI {
    
    return @"https://r50.sistemium.com/app.manifest";
    
//    return self.webViewParameters[@"appManifestURI"];
    
}

- (NSString *)webViewAuthCheckJS {
    
    NSString *webViewAuthCheckJS = self.webViewStoryboardParameters[@"authCheck"];
    
    return webViewAuthCheckJS ? webViewAuthCheckJS : [[self webViewSettings] valueForKey:@"wv.session.check"];
    
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
    
    NSURL *url = [NSURL URLWithString:urlString];
    [self loadURL:url];
    
}

- (void)loadURL:(NSURL *)url {
    [self webViewAppManifestURI] ? [self loadLocalHTML] : [self loadRemoteURL:url];
}

- (void)loadLocalHTML {
    [self.appManifestHandler startLoadLocalHTML];
}

- (void)loadHTML:(NSString *)html atBaseDir:(NSString *)baseDir {
    [self.webView loadHTMLString:html baseURL:[NSURL fileURLWithPath:baseDir]];
}

- (void)localHTMLUpdateIsAvailable {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPDATE", nil)
                                                            message:@"UPDATE AVAILABLE!"
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        
    }];

}

- (void)appManifestLoadFailWithErrorText:(NSString *)errorText {
    
    [[STMLogger sharedLogger] saveLogMessageWithText:errorText
                                             numType:STMLogMessageTypeError];
    
    if (!self.haveLocalHTML) {
     
        [self.spinnerView removeFromSuperview];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ERROR", nil)
                                                                message:errorText
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            [alertView show];
            
        }];

    }

}

- (void)loadRemoteURL:(NSURL *)url {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];

    request.cachePolicy = NSURLRequestUseProtocolCachePolicy;

    //    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    //    request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    
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
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

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
    
    NSString *logMessage = [NSString stringWithFormat:@"webView %@ didFailNavigation withError: %@", webView.URL, error.localizedDescription];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
    
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
//    NSLogMethodName;
    
    /*NSString *logMessage = [NSString stringWithFormat:@"webView %@ didFailProvisionalNavigation withError: %@", webView.URL, error.localizedDescription];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];*/

}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    
    NSString *logMessage = [NSString stringWithFormat:@"webViewWebContentProcessDidTerminate %@", webView.URL];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
    
    [self loadURL:webView.URL];
    
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
    
    self.wasLoadingOnce = YES;
    
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
            
            NSNumber *requestId = message.body[@"options"][@"requestId"];
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
        
        [self handleRemoteControlMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_ROLES]) {
        
        [self handleRolesMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_CHECKIN]) {
        
        [self handleCheckinMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_TAKE_PHOTO]) {
        
        [self handleTakePhotoMessage:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_GET_PICTURE]) {
        
        [self handleGetPictureMessage:message];
        
    }
    
}

- (void)handleGetPictureMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;
    [self handleGetPictureParameters:parameters];
    
}

- (void)handleGetPictureParameters:(NSDictionary *)parameters {
    
    NSString *getPictureXid = parameters[@"id"];
    NSData *getPictureXidData = [STMFunctions xidDataFromXidString:getPictureXid];
    if (getPictureXidData) self.getPictureMessageParameters[getPictureXidData] = parameters;
    
    NSString *callbackFunction = parameters[@"callback"];
    if (getPictureXidData) self.getPictureCallbackJSFunctions[getPictureXidData] = callbackFunction;
    
    NSString *getPictureSize = parameters[@"size"];
    
    STMDatum *object = [STMCoreObjectsController objectForXid:getPictureXidData];
    
    if (!object) {
        
        [self getPictureWithXid:getPictureXidData
                          error:[NSString stringWithFormat:@"no object with xid %@", getPictureXid]];
        return;
        
    }
    
    if (![object isKindOfClass:[STMCorePicture class]]) {
        
        [self getPictureWithXid:getPictureXidData
                          error:[NSString stringWithFormat:@"object with xid %@ is not a Picture kind of class", getPictureXid]];
        return;
        
    }
    
    STMCorePicture *picture = (STMCorePicture *)object;
    
    if ([getPictureSize isEqualToString:@"thumbnail"]) {
        
        if (picture.imageThumbnail) {
            
            [self getPictureSendData:picture.imageThumbnail
                          parameters:parameters
                  jsCallbackFunction:callbackFunction];

        } else {
            [self downloadPicture:picture];
        }
        
    } else if ([getPictureSize isEqualToString:@"resized"]) {
        
        if (picture.resizedImagePath) {
            
            [self getPicture:picture
               withImagePath:picture.resizedImagePath
                  parameters:parameters
          jsCallbackFunction:callbackFunction];
            
        } else {
            [self downloadPicture:picture];
        }
        
    } else if ([getPictureSize isEqualToString:@"full"]) {
        
        if (picture.imagePath) {
            
            [self getPicture:picture
               withImagePath:picture.imagePath
                  parameters:parameters
          jsCallbackFunction:callbackFunction];
            
        } else {
            [self downloadPicture:picture];
        }
        
    } else {
        
        [self getPictureWithXid:getPictureXidData
                          error:@"size parameter is not correct"];
        
    }

}

- (void)getPictureWithXid:(NSData *)xid error:(NSString *)errorString {
    
    NSDictionary *parameters = (xid) ? self.getPictureMessageParameters[xid] : @{};
//    NSString *callbackJSFunction = (xid) ? self.getPictureCallbackJSFunctions[xid] : @"";
    
//    [self callbackWithData:errorString
//                parameters:parameters
//        jsCallbackFunction:callbackJSFunction];
    
    [self callbackWithError:errorString
                 parameters:parameters];

    if (xid) {
        
        [self.getPictureCallbackJSFunctions removeObjectForKey:xid];
        [self.getPictureMessageParameters removeObjectForKey:xid];

    }

}

- (void)downloadPicture:(STMCorePicture *)picture {
    
    if (picture.href) {

        [self addObserversForPicture:picture];

        picture.imageThumbnail = nil;
        
        NSManagedObjectID *pictureID = picture.objectID;
        
        [STMCorePicturesController downloadConnectionForObjectID:pictureID];
        
    } else {

        [self getPictureWithXid:picture.xid
                          error:@"picture have not imagePath and href"];
        
    }
    
}

- (void)pictureWasDownloaded:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[STMCorePicture class]]) {
        
        STMCorePicture *picture = notification.object;
        
        [self removeObserversForPicture:picture];
        
        [self handleGetPictureParameters:self.getPictureMessageParameters[(NSData *)picture.xid]];
        
    }
    
}

- (void)pictureDownloadError:(NSNotification *)notification {
    
    STMCorePicture *picture = notification.object;
    
    [self removeObserversForPicture:picture];

    NSString *errorString = notification.userInfo[@"error"];
    
    [self getPictureWithXid:picture.xid
                      error:errorString];

}

- (void)addObserversForPicture:(STMCorePicture *)picture {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pictureWasDownloaded:)
                                                 name:@"downloadPicture"
                                               object:picture];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pictureDownloadError:)
                                                 name:@"pictureDownloadError"
                                               object:picture];

}

- (void)removeObserversForPicture:(STMCorePicture *)picture {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"downloadPicture"
                                                  object:picture];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"pictureDownloadError"
                                                  object:picture];

}

- (void)getPicture:(STMCorePicture *)picture withImagePath:(NSString *)imagePath parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
    NSError *error = nil;
    NSData *imageData = [NSData dataWithContentsOfFile:[STMFunctions absolutePathForPath:imagePath]
                                               options:0
                                                 error:&error];
    
    if (error) {
        
        [self getPictureWithXid:picture.xid
                          error:[NSString stringWithFormat:@"read file error: %@", error.localizedDescription]];

    } else {
        
        [self getPictureSendData:imageData
                      parameters:parameters
              jsCallbackFunction:jsCallbackFunction];
        
    }

}

- (void)getPictureSendData:(NSData *)imageData parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {

    if (imageData) {
    
        NSString *imageDataBase64String = [imageData base64EncodedStringWithOptions:0];
        [self callbackWithData:@[imageDataBase64String]
                    parameters:parameters
            jsCallbackFunction:jsCallbackFunction];

    } else {
        
        [self callbackWithData:@"no image data"
                    parameters:parameters
            jsCallbackFunction:jsCallbackFunction];

    }
    
}

- (void)handleTakePhotoMessage:(WKScriptMessage *)message {
    
    if (!self.waitingPhoto) {
        
        NSDictionary *parameters = message.body;
        
        NSString *entityName = parameters[@"entityName"];
        self.photoEntityName = [entityName hasPrefix:ISISTEMIUM_PREFIX] ? entityName : [ISISTEMIUM_PREFIX stringByAppendingString:entityName];
        
        if ([[STMCoreObjectsController localDataModelEntityNames] containsObject:self.photoEntityName]) {
        
            self.waitingPhoto = YES;

            self.takePhotoMessageParameters = parameters;
            self.takePhotoCallbackJSFunction = parameters[@"callback"];
            self.photoData = [parameters[@"data"] isKindOfClass:[NSDictionary class]] ? parameters[@"data"] : @{};
            
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                
                [self performSelector:@selector(checkImagePickerWithSourceTypeNumber:)
                           withObject:@(UIImagePickerControllerSourceTypeCamera)
                           afterDelay:0];
                
            } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
                
                [self performSelector:@selector(checkImagePickerWithSourceTypeNumber:)
                           withObject:@(UIImagePickerControllerSourceTypePhotoLibrary)
                           afterDelay:0];
                
            } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum]) {
                
                [self performSelector:@selector(checkImagePickerWithSourceTypeNumber:)
                           withObject:@(UIImagePickerControllerSourceTypeSavedPhotosAlbum)
                           afterDelay:0];
                
            } else {
                
                self.waitingPhoto = NO;
                
                NSString *message = @"have no one available source types";
                [self callbackWithError:message
                             parameters:self.takePhotoMessageParameters];
//                [self callbackWithData:message
//                            parameters:self.takePhotoMessageParameters
//                    jsCallbackFunction:self.takePhotoCallbackJSFunction];
                
            }

        } else {
            
            NSString *error = [NSString stringWithFormat:@"local data model have not entity with name %@", self.photoEntityName];
            [self callbackWithError:error
                         parameters:parameters];
            
        }
        
    }

}

- (void)handleCheckinMessage:(WKScriptMessage *)message {
    
    NSDictionary *parameters = message.body;

    NSNumber *requestId = [parameters[@"options"][@"requestId"] isKindOfClass:[NSNumber class]] ? parameters[@"options"][@"requestId"] : nil;

    if (requestId) {
        
        self.checkinCallbackJSFunction = parameters[@"callback"];
        
        NSDictionary *checkinData = [parameters[@"data"] isKindOfClass:[NSDictionary class]] ? parameters[@"data"] : @{};
    
        self.checkinMessageParameters[requestId] = parameters;
        
        NSNumber *accuracy = parameters[@"accuracy"];
        
        STMCoreLocationTracker *locationTracker = [(STMCoreSession *)[STMCoreSessionManager sharedManager].currentSession locationTracker];

        [locationTracker checkinWithAccuracy:accuracy
                                 checkinData:checkinData
                                   requestId:requestId
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

- (void)callbackWithData:(id)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
#ifdef DEBUG
    
    NSNumber *requestId = parameters[@"options"][@"requestId"];

    if (requestId && [data isKindOfClass:[NSArray class]]) {
        NSLog(@"requestId %@ callbackWithData: %@ objects", requestId, @([(NSArray *)data count]));
    } else {
        NSLog(@"callbackWithData: %@ for message parameters: %@", data, parameters);
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


#pragma mark - STMImagePickerOwnerProtocol

- (void)checkImagePickerWithSourceTypeNumber:(NSNumber *)sourceTypeNumber {
 
    NSUInteger imageSourceType = sourceTypeNumber.integerValue;
    
    if ([UIImagePickerController isSourceTypeAvailable:imageSourceType]) {
        
        [self showImagePickerForSourceType:imageSourceType];
        
    } else {
        
        NSString *imageSourceTypeString = [self stringValueForImageSourceType:imageSourceType];
        
        self.waitingPhoto = NO;
        
        NSString *message = [NSString stringWithFormat:@"%@ source type is not available", imageSourceTypeString];
//        [self callbackWithData:message
//                    parameters:self.takePhotoMessageParameters
//            jsCallbackFunction:self.takePhotoCallbackJSFunction];
        [self callbackWithError:message
                     parameters:self.takePhotoMessageParameters];
        
    }

}

- (NSString *)stringValueForImageSourceType:(UIImagePickerControllerSourceType)imageSourceType {
    
    switch (imageSourceType) {
        case UIImagePickerControllerSourceTypePhotoLibrary: {
            return @"PhotoLibrary";
            break;
        }
        case UIImagePickerControllerSourceTypeCamera: {
            return @"Camera";
            break;
        }
        case UIImagePickerControllerSourceTypeSavedPhotosAlbum: {
            return @"PhotosAlbum";
            break;
        }
    }

}

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)imageSourceType {
    
    STMImagePickerController *imagePickerController = [[STMImagePickerController alloc] initWithSourceType:imageSourceType];
    imagePickerController.ownerVC = self;
    
    [self.tabBarController presentViewController:imagePickerController animated:YES completion:^{
        [self.view addSubview:self.spinnerView];
    }];

}

- (BOOL)shouldWaitForLocation {
    return NO;
}

- (void)saveImage:(UIImage *)image withLocation:(CLLocation *)location {
    [self saveImage:image];
}

- (void)saveImage:(UIImage *)image andWaitForLocation:(BOOL)waitForLocation {
    [self saveImage:image];
}

- (void)imagePickerWasDissmised:(UIImagePickerController *)picker {
	
    [self.spinnerView removeFromSuperview];
    self.spinnerView = nil;
    
    self.waitingPhoto = NO;

}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
    [self imagePickerWasDissmised:picker];

//    [self callbackWithData:@[@"imagePickerControllerDidCancel"]
//                parameters:self.takePhotoMessageParameters
//        jsCallbackFunction:self.takePhotoCallbackJSFunction];

    [self callbackWithError:@"imagePickerControllerDidCancel"
                 parameters:self.takePhotoMessageParameters];
    
}

- (void)saveImage:(UIImage *)image {
    
    CGFloat jpgQuality = [STMCorePicturesController jpgQuality];
    
    STMCorePhoto *photoObject = [STMCorePhotosController newPhotoObjectWithEntityName:self.photoEntityName
                                                                            photoData:UIImageJPEGRepresentation(image, jpgQuality)];
    
    if (photoObject) {
    
        [STMCoreObjectsController setObjectData:self.photoData toObject:photoObject];
        
        NSDictionary *photoObjectDic = [STMCoreObjectsController dictionaryForJSWithObject:photoObject
                                                                                 withNulls:YES
                                                                            withBinaryData:NO];
        
        [self callbackWithData:@[photoObjectDic]
                    parameters:self.takePhotoMessageParameters
            jsCallbackFunction:self.takePhotoCallbackJSFunction];

    } else {
        
        
        
    }
    
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
        
//        [self callbackWithData:errorString
//                    parameters:parameters
//            jsCallbackFunction:self.checkinCallbackJSFunction];
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
    [self checkWebViewIsAlive];
}

- (void)checkWebViewIsAlive {
    
    if (!self.wasLoadingOnce) return;
    
    NSString *checkJS = @"window.document.body.childNodes.length";
    
    [self.webView evaluateJavaScript:checkJS completionHandler:^(id result, NSError *error) {
        
        if (error) {
            
            NSString *errorString = [NSString stringWithFormat:@"checkWebViewIsAlive error : %@\n", error.localizedDescription];
            errorString = [errorString stringByAppendingString:@"reload webView"];
            [[STMLogger sharedLogger] saveLogMessageWithText:errorString type:@"error"];
            
            [self reloadWebView];
            
        } else {

            NSLog(@"checkWebViewIsAlive OK");

        }
        
    }];

}

#pragma mark - view lifecycle

- (void)addObservers {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForegroundNotification:)
                                                 name:UIApplicationWillEnterForegroundNotification
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
    
    /*if ([STMFunctions shouldHandleMemoryWarningFromVC:self]) {
        [STMFunctions nilifyViewForVC:self];
    }*/
    
    [super didReceiveMemoryWarning];
    
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [self checkWebViewIsAlive];
    
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
