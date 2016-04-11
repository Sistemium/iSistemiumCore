//
//  STMWebViewVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 18/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMWebViewVC.h"

#import "STMUI.h"

#import "STMSessionManager.h"
#import "STMAuthController.h"

#import "STMFunctions.h"

@interface STMWebViewVC () <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) BOOL isAuthorizing;
@property (nonatomic, strong) UIView *spinnerView;

@end

@implementation STMWebViewVC

- (UIView *)spinnerView {
    
    if (!_spinnerView) {
        
        UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        view.backgroundColor = [UIColor grayColor];
        view.alpha = 0.75;
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.center = view.center;
        spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [spinner startAnimating];
        [view addSubview:spinner];
        
        _spinnerView = view;
        
    }
    
    return _spinnerView;
    
}


#pragma mark - settings

- (NSDictionary *)webViewSettings {
    
    NSDictionary *settings = [[STMSessionManager sharedManager].currentSession.settingsController currentSettingsForGroup:@"webview"];
    return settings;
    
}

- (NSString *)webViewUrlString {
    
    if ([self.storyboard isKindOfClass:[STMStoryboard class]]) {

        STMStoryboard *storyboard = (STMStoryboard *)self.storyboard;
        NSString *url = storyboard.parameters[@"url"];
        return url;
        
    } else {
        return [[self webViewSettings] valueForKey:@"wv.url"];
    }
    
}

- (NSString *)webViewSessionCheckJS {
    
    if ([self.storyboard isKindOfClass:[STMStoryboard class]]) {
        
        STMStoryboard *storyboard = (STMStoryboard *)self.storyboard;
        NSString *authCheck = storyboard.parameters[@"authCheck"];
        return authCheck;
        
    } else {
        return [[self webViewSettings] valueForKey:@"wv.session.check"];
    }
    
}

- (NSString *)webViewSessionCookie {
    
    return [[self webViewSettings] valueForKey:@"wv.session.cookie"];
    
}

- (NSString *)webViewTitle {
    
    return [[self webViewSettings] valueForKey:@"wv.title"];
    
}


- (void)loadWebView {

    [self.view addSubview:self.spinnerView];
    
    self.isAuthorizing = NO;

    NSString *urlString = [self webViewUrlString];
    [self loadURLString:urlString];
    
}

- (void)authLoadWebView {

    self.isAuthorizing = YES;

    NSString *accessToken = [STMAuthController authController].accessToken;
    
//    NSLog(@"accessToken %@", accessToken);

    NSString *urlString = [self webViewUrlString];
    urlString = [NSString stringWithFormat:@"%@?access-token=%@", urlString, accessToken];

    [self loadURLString:urlString];
    
}

- (void)loadURLString:(NSString *)urlString {

    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
//    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

//    NSLog(@"currentDiskUsage %d", [NSURLCache sharedURLCache].currentDiskUsage);
//    NSLog(@"currentMemoryUsage %d", [NSURLCache sharedURLCache].currentMemoryUsage);
    
    [self.webView loadRequest:request];

}

- (void)flushCookie {
    
    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];

    for (NSHTTPCookie *cookie in [cookieJar cookies]) {
        
        NSLog(@"cookie %@", cookie);
        [cookieJar deleteCookie:cookie];
        
    }

    NSLog(@"cookies %@", [cookieJar cookies]);

}


#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
//    NSLog(@"webViewDidFinishLoad %@", webView.request);
    
//    NSLog(@"cachedResponseForRequest %@", [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request]);
//    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:webView.request];
    
    NSString *bsAccessToken = [self.webView stringByEvaluatingJavaScriptFromString:[self webViewSessionCheckJS]];

    NSLog(@"bsAccessToken %@", bsAccessToken);
    
    if ([bsAccessToken isEqualToString:@""]) {
    
        if (!self.isAuthorizing) {

            NSLog(@"no bsAccessToken, go to authorization");
            
            [self authLoadWebView];

        }
        
    } else {
        
        self.isAuthorizing = NO;
        [self.spinnerView removeFromSuperview];
        
    }

}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"webView didFailLoadWithError: %@", error.localizedDescription);
}


#pragma mark - view lifecycle

- (void)customInit {

    self.webView.delegate = self;
    [self loadWebView];
    
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

@end
