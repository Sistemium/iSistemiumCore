//
//  STMRootVC.h
//  TestRootVC
//
//  Created by Maxim Grigoriev on 20/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface STMCoreRootTBC : UITabBarController

+ (STMCoreRootTBC *)sharedRootVC;

- (UIViewController *)topmostVC;

- (void)initAllTabs;
- (void)setDocumentReady;
- (void)addObservers;
- (void)initAuthTab;

- (NSArray *)siblingsForViewController:(UIViewController *)vc;
- (void)replaceVC:(UIViewController *)currentVC withVC:(UIViewController *)vc;

- (void)showTabBar;
- (void)hideTabBar;

- (void)newAppVersionAvailable:(NSNotification *)notification;

@property (nonatomic, strong) NSMutableArray *storyboardTitles;
@property (nonatomic) BOOL newAppVersionAvailable;


@end
