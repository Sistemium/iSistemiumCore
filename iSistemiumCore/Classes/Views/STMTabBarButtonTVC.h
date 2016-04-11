//
//  STMTabBarButtonTVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 19/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMTabBarItemControllable.h"


@interface STMTabBarButtonTVC : UITableViewController

@property (nonatomic, strong) NSArray *siblings;
@property (nonatomic, strong) NSArray *actions;

@property (nonatomic, weak) UIViewController <STMTabBarItemControllable> *parentVC;

@end
