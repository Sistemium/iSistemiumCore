//
//  STMWKWebViewNC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMWKWebViewNC.h"

#import "STMWKWebViewVC.h"


@interface STMWKWebViewNC ()

@end

@implementation STMWKWebViewNC

#pragma mark - STMTabBarItemControllable protocol

- (BOOL)shouldShowOwnActions {
    return YES;
}

- (void)selectActionAtIndex:(NSUInteger)index {
    
    [super selectActionAtIndex:index];
    
    NSString *action = self.actions[index];
    
    if ([action isEqualToString:NSLocalizedString(@"RELOAD", nil)]) {
        
        if ([self.topViewController isKindOfClass:[STMWKWebViewVC class]]) {
            [(STMWKWebViewVC *)self.topViewController reloadWebView];
        }
        
    }
    
}


#pragma mark - view lifecycle

- (void)customInit {
    
    self.actions = @[NSLocalizedString(@"RELOAD", nil)];
    
    self.navigationBarHidden = YES;

}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
