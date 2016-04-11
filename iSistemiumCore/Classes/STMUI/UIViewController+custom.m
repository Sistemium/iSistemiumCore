//
//  UIViewController+custom.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 17/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "UIViewController+custom.h"

#import "STMConstants.h"


@implementation UIViewController (custom)

- (BOOL)isInActiveTab {
    
    if (IPHONE) {
        return [self.tabBarController.selectedViewController isEqual:self.navigationController];
    }
    
    if (IPAD) {
        return [self.tabBarController.selectedViewController isEqual:self.splitViewController];
    }
    
    return NO;
    
}


@end
