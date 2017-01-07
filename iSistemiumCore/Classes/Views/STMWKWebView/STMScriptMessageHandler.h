//
//  STMScriptMessageHandler.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "STMCoreWKWebViewVC.h"


@interface STMScriptMessageHandler : NSObject

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveFindMessage:(WKScriptMessage *)message;

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveUpdateMessage:(WKScriptMessage *)message;

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveSubscribeMessage:(WKScriptMessage *)message;

+ (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveDestroyMessage:(WKScriptMessage *)message;


@end
