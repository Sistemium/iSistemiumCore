//
//  STMScriptMessaging.h
//  iSisSales
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMScriptMessaging

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveFindMessage:(WKScriptMessage *)message;

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveUpdateMessage:(WKScriptMessage *)message;

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveSubscribeMessage:(WKScriptMessage *)message;

- (void)webViewVC:(STMCoreWKWebViewVC *)webViewVC receiveDestroyMessage:(WKScriptMessage *)message;

- (void)unsubscribeViewController:(UIViewController*)vc;

@end
