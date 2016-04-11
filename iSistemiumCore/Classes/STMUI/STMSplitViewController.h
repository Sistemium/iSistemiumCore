//
//  STMUISplitViewController.h
//  iSistemium
//
//  Created by Alexander Levin on 11/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMTabBarItemControllable.h"

#import "STMDataModel.h"


@interface STMSplitViewController : UISplitViewController <STMTabBarItemControllable>

@property (nonatomic, strong) NSArray <NSString *> *actions;


@end
