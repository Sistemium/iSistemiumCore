//
// Created by Alexander Levin on 11/06/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMCoreWKWebViewVC.h"

@interface STMCoreWKWebViewVC (Navigation) <WKNavigationDelegate>

- (void)webView:(WKWebView *)webView
           fail:(NSString *)failString
      withError:(NSString *)errorString;

@end