//
//  STMWebViewNC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 19/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMWebViewNC.h"
#import "STMWebViewVC.h"


@interface STMWebViewNC ()

@end

@implementation STMWebViewNC

#pragma mark - STMTabBarItemControllable protocol

- (BOOL)shouldShowOwnActions {
    return YES;
}

- (void)selectActionAtIndex:(NSUInteger)index {
    
    [super selectActionAtIndex:index];
    
    NSString *action = self.actions[index];
    
    if ([action isEqualToString:NSLocalizedString(@"RELOAD", nil)]) {
        
        if ([self.topViewController isKindOfClass:[STMWebViewVC class]]) {
            [(STMWebViewVC *)self.topViewController loadWebView];
        }
        
    }
    
}


#pragma mark - view lifecycle

- (void)customInit {
    self.actions = @[NSLocalizedString(@"RELOAD", nil)];
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
