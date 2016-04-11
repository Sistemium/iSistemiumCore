//
//  STMActionPopoverNC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 19/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMTabBarItemControllable.h"


@interface STMActionPopoverNC : UINavigationController <STMTabBarItemControllable>

@property (nonatomic, strong) NSArray <NSString *> *actions;

@end
