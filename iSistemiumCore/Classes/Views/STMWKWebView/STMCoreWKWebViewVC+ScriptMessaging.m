//
// Created by Alexander Levin on 11/06/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMCoreWKWebViewVC+ScriptMessaging.h"
#import "STMCoreWKWebViewVC+Private.h"
#import "STMCoreAuthController.h"
#import "STMRemoteController.h"
#import "STMCoreRootTBC.h"

@implementation STMCoreWKWebViewVC (ScriptMessaging)

- (NSString *)iSistemiumIOSCallbackJSFunction {
    return @"iSistemiumIOSCallback";
}

- (NSString *)iSistemiumIOSErrorCallbackJSFunction {
    return @"iSistemiumIOSErrorCallback";
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {

    BOOL scannerMessage = [@[WK_MESSAGE_SCANNER_ON, WK_MESSAGE_SCANNER_OFF] containsObject:message.name];

    if (scannerMessage) {

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

    } else if ([message.name isEqualToString:WK_MESSAGE_SCANNER_OFF]) {

        [self stopBarcodeScanning];

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

    } else if ([message.name isEqualToString:WK_MESSAGE_UNSYNCED_INFO]) {

        [self handleUnsyncedInfoMessage:message];

    } else if ([message.name isEqualToString:WK_MESSAGE_SAVE_IMAGE]) {

        [self.scriptMessageHandler handleSaveImageMessage:message];

    } else if ([message.name isEqualToString:WK_MESSAGE_COPY_CLIPBOARD]) {

        [self.scriptMessageHandler handleCopyToClipboardMessage:message];

    } else if ([message.name isEqualToString:WK_MESSAGE_GET_CONTACTS]) {

        [self.scriptMessageHandler loadContactsMessage:message];

    } else if ([message.name isEqualToString:WK_MESSAGE_NAVIGATE]) {

        [self.scriptMessageHandler navigate:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_OPEN_URL]) {

        [self.scriptMessageHandler openUrl:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SHARE]) {
        
        [self.scriptMessageHandler share:message];
        
    } else if ([message.name isEqualToString:WK_MESSAGE_SWITCH_TAB]) {

           [self.scriptMessageHandler switchTab:message];
           
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

    NSNumber *requestId = [parameters[@"options"][@"requestId"] isKindOfClass:[NSNumber class]] ?
            parameters[@"options"][@"requestId"] : nil;

    if (requestId) {

        self.checkinCallbackJSFunction = parameters[@"callback"];

        NSDictionary *checkinData = [parameters[@"data"] isKindOfClass:[NSDictionary class]] ? parameters[@"data"] : @{};

        self.checkinMessageParameters[requestId] = parameters;

        NSNumber *accuracy = parameters[@"accuracy"];
        NSTimeInterval timeout = [parameters[@"timeout"] doubleValue] / 1000;

        STMCoreLocationTracker *locationTracker =
                [(STMCoreSession *) [STMCoreSessionManager sharedManager].currentSession locationTracker];

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

    NSDictionary *roles = [STMCoreAuthController sharedAuthController].rolesResponse;

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
        [self callbackWithData:@[@"remoteCommands ok"]
                    parameters:parameters jsCallbackFunction:self.remoteControlCallbackJSFunction];
    } else {
        [self callbackWithError:error.localizedDescription parameters:parameters];
    }

}

+ (NSString *)scannerType {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *scannerType = [defaults objectForKey:@"ScannerType"];
    return STMIsNull(scannerType, @"camera");

}

- (void)handleScannerMessage:(WKScriptMessage *)message {

    self.scannerScanJSFunction = message.body[@"scanCallback"];
    self.scannerPowerButtonJSFunction = message.body[@"powerButtonCallback"];
    self.scannerStatusJSFunction = message.body[@"statusCallback"];

    if ([[self.class scannerType] isEqualToString:@"camera"]) {
        [self startIOSModeScanner:STMBarCodeScannerCameraMode];
    } else {
        [self startIOSModeScanner:STMBarCodeScannerIOSMode];
    }

}

- (void)handleUnsyncedInfoMessage:(WKScriptMessage *)message {
    self.unsyncedInfoJSFunction = message.body[@"unsyncedInfoCallback"];
}

- (void)handleTabbarMessage:(WKScriptMessage *)message {
    
    if (self.directLoadUrl != nil) {
        
        return;
        
    }

    NSDictionary *parameters = message.body;

    NSString *action = parameters[@"action"];

    if ([action isEqualToString:@"show"]) {

        CGFloat tabbarHeight = CGRectGetHeight(self.tabBarController.tabBar.frame);
        
        self.bottomConstraint.constant = tabbarHeight;
        
        [[STMCoreRootTBC sharedRootVC] showTabBar];
        

    } else if ([action isEqualToString:@"hide"]) {

        if (self.isInActiveTab) {
            
            self.bottomConstraint.constant = 0;

            [[STMCoreRootTBC sharedRootVC] hideTabBar];

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

        NSString *entityName = parameters[@"entity"];

        if (!entityName) {
            entityName = parameters[@"entityName"];
        }

        if (!entityName) {
            entityName = @"unknown entity";
        }

        if ([entityName isEqualToString:@"unknown entity"]) {
            NSLog(@"parameters %@", parameters);
        }

        NSLog(@"requestId %@ (%@) callbackWithData: %@ objects", requestId, entityName, @([(NSArray *) data count]));

    } else {

        if ([parameters[@"reason"] isEqualToString:@"subscription"]) {

            NSString *entityName = [[(NSArray *) data firstObject] valueForKey:@"entity"];

            NSLog(@"subscription %@ callbackWithData: %@ objects", entityName, @([(NSArray *) data count]));

        } else {

            NSLog(@"callbackWithData: %@ for message parameters: %@", data, parameters);

        }

    }

#endif

    if (!jsCallbackFunction) {
        NSLog(@"have no jsCallbackFunction");
        return;
    }


    NSMutableArray *arguments = @[].mutableCopy;

    if (data) [arguments addObject:data];
    if (parameters) [arguments addObject:parameters];

    NSDate *startedAt = [NSDate date];

    NSString *jsFunction = [NSString stringWithFormat:@"window.%1$@ && %1$@.apply(null,%2$@)",
                                                      jsCallbackFunction, [STMFunctions jsonStringFromArray:arguments]];

    NSLog(@"jsonStringFromArray requestId: %@ ms: %@", requestId, @(ceil(-1000 * [startedAt timeIntervalSinceNow])));

    startedAt = [NSDate date];

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        if (!self.webView.window) {
//            NSLog(@"Not Visible, but handled");
            return;
        }

        [self.webView evaluateJavaScript:jsFunction completionHandler:^(id result, NSError *error) {

            NSLog(@"evaluateJS requestId: %@ ms: %@", requestId, @(ceil(-1000 * [startedAt timeIntervalSinceNow])));

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

    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)",
                                                      self.iSistemiumIOSErrorCallbackJSFunction,
                                                      [STMFunctions jsonStringFromArray:arguments]];

    [self.webView evaluateJavaScript:jsFunction completionHandler:^(id _Nullable result, NSError *_Nullable error) {

    }];

}


#pragma mark - evaluateJavaScriptAndWait

int counter = 0;

- (void)evaluateJavaScriptAndWait:(NSString *)javascript {

    counter++;

    [self.webView evaluateJavaScript:javascript completionHandler:^(NSString *result, NSError *error) {

        if (error || SYSTEM_VERSION < 10.0 || [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            return;
        }

        int counterWas = counter;
        int count = 0;

        while (count++ < 150 && counter == counterWas) {
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
    [self startIOSModeScanner:STMBarCodeScannerIOSMode];
}

- (void)startIOSModeScanner:(STMBarCodeScannerMode)mode {

    self.iOSModeBarCodeScanner = [[STMBarCodeScanner alloc] initWithMode:mode];
    self.iOSModeBarCodeScanner.delegate = self;
    [self.iOSModeBarCodeScanner startScan];

    if ([self.iOSModeBarCodeScanner isDeviceConnected]) {
        [self scannerIsConnected];
    }

}

- (void)stopBarcodeScanning {
    [self stopIOSModeScanner];
    self.scannerStatusJSFunction = nil;
}

- (void)stopIOSModeScanner {

    [self.iOSModeBarCodeScanner stopScan];
    [self deviceRemovalForBarCodeScanner:self.iOSModeBarCodeScanner];

    self.iOSModeBarCodeScanner = nil;

}

- (void)scannerIsConnected {
    if (self.scannerStatusJSFunction) {
        [self callbackWithData:@"connected" parameters:@{} jsCallbackFunction:self.scannerStatusJSFunction];
    }
}

- (void)scannerIsDisconnected {
    if (self.scannerStatusJSFunction) {
        [self callbackWithData:@"disconnected" parameters:@{} jsCallbackFunction:self.scannerStatusJSFunction];
    }
}


#pragma mark - STMBarCodeScannerDelegate

- (UIView *)viewForScanner:(id <STMBarCodeScanningDevice>)scanner {
    return self.view;
}

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner
    receiveBarCodeScan:(STMBarCodeScan *)barCodeScan
              withType:(STMBarCodeScannedType)type {

    if (!self.isInActiveTab) {
        return;
    }

//    NSMutableArray *arguments = @[].mutableCopy;
//
//    NSString *barcode = barCodeScan.code;
//    if (!barcode) barcode = @"";
//    [arguments addObject:barcode];
//
//    NSString *typeString = [STMBarCodeController barCodeTypeStringForType:type];
//    if (!typeString) typeString = @"";
//    [arguments addObject:typeString];
//
//    NSDictionary *barcodeDic = [STMObjectsController dictionaryForJSWithObject:barCodeScan];
//    [arguments addObject:barcodeDic];
//
//    NSLog(@"send received barcode %@ with type %@ to WKWebView", barcode, typeString);
//
//    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)",
//          self.receiveBarCodeJSFunction, [STMFunctions jsonStringFromArray:arguments]];
//
//    [self.webView evaluateJavaScript:jsFunction completionHandler:^(id _Nullable result, NSError *_Nullable error) {
//
//    }];


}

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner
        receiveBarCode:(NSString *)barcode
             symbology:(NSString *)symbology
              withType:(STMBarCodeScannedType)type {

    if (!self.isInActiveTab || !barcode) {
        return;
    }

    NSMutableArray *arguments = [@[barcode] mutableCopy];

    [self checkBarCode:barcode withType:type arguments:arguments];

    if (symbology) {
        [arguments addObject:symbology];
    }

    [self evaluateReceiveBarCodeJSFunctionWithArguments:arguments.copy];


}

- (void)checkBarCode:(NSString *)barcode withType:(STMBarCodeScannedType)type arguments:(NSMutableArray *)arguments {

    NSString *typeString = [STMCoreBarCodeController barCodeTypeStringForType:type];

    if (!typeString) {

        NSLog(@"send received barcode %@ to WKWebView", barcode);
        [arguments addObject:[NSNull null]];
        return;

    }

    if (type != STMBarCodeTypeStockBatch) {

        NSLog(@"send received barcode %@ with type %@ to WKWebView", barcode, typeString);\
        [arguments addObject:[NSNull null]];
        return;

    }

    [arguments addObject:typeString];

    NSDictionary *stockBatch = [STMCoreBarCodeController stockBatchForBarcode:barcode].firstObject;

    if (!stockBatch) {

        NSLog(@"send received barcode %@ with type %@ to WKWebView", barcode, typeString);
        [arguments addObject:[NSNull null]];
        return;

    }

    [arguments addObject:stockBatch];

    NSLog(@"send received barcode %@ with type %@ and stockBatch %@ to WKWebView", barcode, typeString, stockBatch);

}

- (void)evaluateReceiveBarCodeJSFunctionWithArguments:(NSArray *)arguments {

    NSString *jsFunction = [NSString stringWithFormat:@"%@.apply(null,%@)",
                                                      self.scannerScanJSFunction, [STMFunctions jsonStringFromArray:arguments]];

    [self evaluateJavaScriptAndWait:jsFunction];

}

- (void)powerButtonPressedOnBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner {

    if (self.isInActiveTab) {

        [self callbackWithData:@[@"powerButtonPressed"]
                    parameters:nil
            jsCallbackFunction:self.scannerPowerButtonJSFunction];

    }

}

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner receiveError:(NSError *)error {

}

- (void)deviceArrivalForBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner {

    if (scanner == self.iOSModeBarCodeScanner) {

        [STMSoundController say:NSLocalizedString(@"SCANNER DEVICE ARRIVAL", nil)];

        [self scannerIsConnected];

    }

}

- (void)deviceRemovalForBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner {

    if (scanner == self.iOSModeBarCodeScanner) {

        [STMSoundController say:NSLocalizedString(@"SCANNER DEVICE REMOVAL", nil)];

        [self scannerIsDisconnected];

    }

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


@end
