//
// Created by Alexander Levin on 11/06/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMCoreWKWebViewVC+Navigation.h"
#import "STMCoreWKWebViewVC+Private.h"


@implementation STMCoreWKWebViewVC (Navigation)

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

    self.lastUrl = webView.URL.absoluteString;

    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeError];

    if ([STMFunctions isAppInBackground]) {
        [self flushWebView];
    } else {
//        [self webViewAppManifestURI] ? [self loadLocalHTML] : [self loadURL:webView.URL];
        [self loadWebView];
    }

}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {

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

    self.wasLoadingOnce = YES;
    [self cancelWaitingTimeout];

    NSString *authCheck = [self webViewAuthCheckJS];

    (authCheck) ? [self authCheckWithJS:authCheck] : [self.spinnerView removeFromSuperview];

}

- (void)authCheckWithJS:(NSString *)authCheck {

    [self.webView evaluateJavaScript:authCheck completionHandler:^(id result, NSError *error) {

        if (error) {
            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
            return;
        }

        if (!result) {
            return;
        }

        NSString *resultString = [NSString stringWithFormat:@"%@", result];

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


    }];

}

- (void)webView:(WKWebView *)webView fail:(NSString *)failString withError:(NSString *)errorString {

    [self cancelWaitingTimeout];

    if (webView && failString && errorString) {

        NSString *logMessage = [NSString stringWithFormat:@"webView %@ %@ withError: %@",
                                                          webView.URL, failString, errorString];

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
                        handler:^(UIAlertAction *action) {
                            [self reloadWebView];
                        }];

        UIAlertAction *noButton = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"CANCEL", nil)
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
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


@end