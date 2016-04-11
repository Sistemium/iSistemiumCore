//
//  STMTabBarItemControllable.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 25/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMTabBarItemControllable <NSObject>

- (BOOL)shouldShowOwnActions;
- (void)showActionPopoverFromTabBarItem;

- (void)selectSiblingAtIndex:(NSUInteger)index;
- (void)selectActionAtIndex:(NSUInteger)index;


@end
