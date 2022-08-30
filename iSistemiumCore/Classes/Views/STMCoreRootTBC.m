//
//  STMRootVC.m
//  TestRootVC
//
//  Created by Maxim Grigoriev on 20/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreRootTBC.h"

#import "STMCoreUI.h"

#import "STMCoreSessionManager.h"
#import "STMCoreSession.h"

#import "STMFunctions.h"
#import "STMConstants.h"

#import "STMCoreObjectsController.h"
#import "STMTabBarItemControllable.h"
#import "STMClientDataController.h"
#import "STMCoreAuthController.h"

#import "STMMessageController.h"

#import "STMCoreAppDelegate.h"

#import "STMUserDefaults.h"


@interface STMCoreRootTBC () <UITabBarControllerDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UIAlertController *authAlert;
@property (nonatomic, strong) UIAlertController *lowFreeSpaceAlert;
@property (nonatomic) BOOL lowFreeSpaceAlertWasShown;
@property (nonatomic, weak) STMCoreSession *session;

@property (nonatomic, strong) NSString *appDownloadUrl;
@property (nonatomic) BOOL updateAlertIsShowing;

@property (nonatomic) BOOL isInHideTabbarProcess;

@property (nonatomic, strong) UIViewController *currentTappedVC;

@property (nonatomic, strong) NSMutableDictionary *tabs;
@property (nonatomic, strong) NSMutableDictionary *allTabsVCs;
@property (nonatomic, strong) NSMutableArray *currentTabsVCs;
@property (nonatomic, strong) NSMutableArray *authVCs;

@property (nonatomic, strong) STMSpinnerView *spinnerView;

@property (nonatomic, strong) NSMutableDictionary *orderedStcTabs;
@property (nonatomic, strong) NSDictionary *lastSelectedTab;


@end


@implementation STMCoreRootTBC

@synthesize lastSelectedTab = _lastSelectedTab;


+ (STMCoreRootTBC *)sharedRootVC {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedRootVC = nil;
    
    dispatch_once(&pred, ^{
        _sharedRootVC = [[self alloc] init];
    });
    
    return _sharedRootVC;
    
}

- (NSString *)orderedStcTabsKey {
    return @"orderedStcTabs";
}

- (NSMutableDictionary *)orderedStcTabs {
    
    if (!_orderedStcTabs) {
        
        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        NSData *data = [defaults objectForKey:[self orderedStcTabsKey]];
        NSDictionary *orderedStcTabs = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        _orderedStcTabs = (orderedStcTabs) ? orderedStcTabs.mutableCopy : [NSMutableDictionary dictionary];
        
    }
    return _orderedStcTabs;
    
}

- (NSString *)lastSelectedTabKey {
    return @"lastSelectedTab";
}

- (NSDictionary *)lastSelectedTab {
    
    if (!_lastSelectedTab) {
        
        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        NSData *data = [defaults objectForKey:[self lastSelectedTabKey]];
        NSDictionary *lastSelectedTab = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        _lastSelectedTab = lastSelectedTab;

    }
    return _lastSelectedTab;

}

- (void)setLastSelectedTab:(NSDictionary *)lastSelectedTab {

    if (![lastSelectedTab isEqual:_lastSelectedTab]) {
        
        _lastSelectedTab = lastSelectedTab;
        
        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:lastSelectedTab];
        [defaults setObject:data forKey:[self lastSelectedTabKey]];
        [defaults synchronize];

    }
    
}

- (STMSpinnerView *)spinnerView {
    
    if (!_spinnerView) {
        _spinnerView = [STMSpinnerView spinnerViewWithFrame:self.view.bounds];
    }
    return _spinnerView;
    
}

- (UIViewController *)topmostVC {
    return [self topmostVCForVC:self];
}

- (UIViewController *)topmostVCForVC:(UIViewController *)vc {
    
    UIViewController *topVC = vc.presentedViewController;
    if (topVC) {
        return [self topmostVCForVC:topVC];
    } else {
        return vc;
    }
    
}

- (STMCoreSession *)session {
    return [STMCoreSessionManager sharedManager].currentSession;
}

- (BOOL)newAppVersionAvailable {
    
    if (self.session.status == STMSessionRunning) {

        [STMClientDataController checkAppVersion];
    
        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        return [[defaults objectForKey:@"newAppVersionAvailable"] boolValue];

    } else {
        
        return NO;
        
    }
    
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {

    [self addObservers];

    self.delegate = self;

    self.tabBar.hidden = NO;
    
    [self initAuthTab];
    
    if (@available(iOS 15.0, *)) {
        UIColor *barBackground = [UIColor whiteColor];
        UIBarAppearance *barAppearance = [[UIBarAppearance alloc] init];
        [barAppearance configureWithOpaqueBackground];
        barAppearance.backgroundColor = barBackground;

        self.tabBar.standardAppearance = [[UITabBarAppearance alloc] initWithBarAppearance:barAppearance];
        self.tabBar.scrollEdgeAppearance = [[UITabBarAppearance alloc] initWithBarAppearance:barAppearance];
        self.tabBar.translucent = YES;
    }
    
    [self hideTabBar];
    
}

- (void)prepareTabs {

    [self nullifyTabs];
    
    if (IPAD) {
        [self setupIPadTabs];
    } else if (IPHONE) {
        [self setupIPhoneTabs];
    }

}

- (void)nullifyTabs {
    
    self.storyboardTitles = nil;
    self.currentTabsVCs = nil;
    self.allTabsVCs = nil;
    self.tabs = nil;
    self.authVCs = nil;

}

- (NSMutableDictionary *)allTabsVCs {
    
    if (!_allTabsVCs) {
        _allTabsVCs = [NSMutableDictionary dictionary];
    }
    return _allTabsVCs;
    
}

- (NSMutableArray *)currentTabsVCs {
    
    if (!_currentTabsVCs) {
        _currentTabsVCs = [NSMutableArray array];
    }
    return _currentTabsVCs;
    
}

- (NSMutableArray *)authVCs {
    
    if (!_authVCs) {
        _authVCs = [NSMutableArray array];
    }
    return _authVCs;
    
}

- (NSMutableDictionary *)tabs {
    
    if (!_tabs) {
        _tabs = [NSMutableDictionary dictionary];
    }
    
    return _tabs;
    
}

- (NSMutableArray *)storyboardTitles {
    
    if (!_storyboardTitles) {
        _storyboardTitles = [NSMutableArray array];
    }
    return _storyboardTitles;
    
}

- (NSArray *)siblingsForViewController:(UIViewController *)vc {
    
    NSArray *siblings = nil;
    
    for (NSArray *tabs in self.allTabsVCs.allValues) {
        
        if ([tabs containsObject:vc]/* && tabs.count > 1*/) {
            siblings = [tabs mutableCopy];
        }
        
    }
    
    return siblings;
    
}

- (void)replaceVC:(UIViewController *)currentVC withVC:(UIViewController *)vc {
    
    NSUInteger index = [self.currentTabsVCs indexOfObject:currentVC];
    
    NSArray *siblings = [self siblingsForViewController:currentVC];
    NSUInteger siblingIndex = [siblings indexOfObject:vc];
    self.orderedStcTabs[@(index)] = @(siblingIndex);
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.orderedStcTabs.copy];
    [defaults setObject:data forKey:[self orderedStcTabsKey]];
    [defaults synchronize];
    
    self.currentTabsVCs[index] = vc;
    
    [self lastSelectedVC:vc];
    
    [self showTabs];
    
}

- (void)registerTabWithStoryboardParameters:(NSDictionary *)parameters atIndex:(NSUInteger)index{
    
    NSString *name = parameters[@"name"];
    NSString *title = parameters[@"title"];
    NSString *imageName = parameters[@"imageName"];
        
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"storyboardc"];
    
    UIViewController *vc;
    
    title = (title) ? title : name;
    
    if ([name hasPrefix:@"STMProfile"] || [name hasPrefix:@"STMAuth"]) {
        [self showTabBar];
        vc = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterViewController];
    } else {
        [self.storyboardTitles addObject:title];
        
        STMStoryboard *storyboard = [STMStoryboard storyboardWithName:name bundle:nil];
        storyboard.parameters = parameters;
        
        vc = [storyboard instantiateInitialViewController];
    }
    
    vc.title = title;
    
    UIImage *image = [UIImage imageNamed:imageName];
    
    image = (image) ? image : [UIImage imageNamed:@"full_moon-128.png"];
    
    if (image) vc.tabBarItem.image = [STMFunctions resizeImage:image toSize:CGSizeMake(30, 30)];

    if (!self.allTabsVCs[@(index)]) {
    
        self.allTabsVCs[@(index)] = @[vc];
        [self.currentTabsVCs addObject:vc];

    } else {
        
        NSMutableArray *tabs = [self.allTabsVCs[@(index)] mutableCopy];
        [tabs addObject:vc];
        self.allTabsVCs[@(index)] = tabs;
        
        if (self.orderedStcTabs[@(index)]) {
            
            NSUInteger showIndex = [self.orderedStcTabs[@(index)] integerValue];
            
            if ([tabs indexOfObject:vc] == showIndex) {
                
                self.currentTabsVCs[index] = vc;
                
            }
            
        }
        
    }
    
    self.tabs[name] = vc;
    
    if ([name hasPrefix:@"STMAuth"]) {
        [self.authVCs addObject:vc];
    }
}

- (void)setupIPadTabs {
    
    NSLog(@"device is iPad type");
    
    NSArray *stcTabs = [STMCoreAuthController sharedAuthController].stcTabs;

    [self setupTabs:stcTabs];
    
}

- (void)setupIPhoneTabs {
    
    NSLog(@"device is iPhone type");

    NSArray *iPhoneStcTabs = [self iPhoneStcTabsForStcTabs:[STMCoreAuthController sharedAuthController].stcTabs];
    
    [self setupTabs:iPhoneStcTabs];
    
}

- (NSArray *)iPhoneStcTabsForStcTabs:(NSArray *)stcTabs {

    NSString *iPhoneStoryboards = [[NSBundle mainBundle] pathForResource:@"iphoneTabs" ofType:@"json"];
    NSData *iPhoneTabsData = [NSData dataWithContentsOfFile:iPhoneStoryboards];
    
    if (iPhoneTabsData) {
        
        NSMutableDictionary *iPhoneTabsJSON = [NSJSONSerialization JSONObjectWithData:iPhoneTabsData
                                                                              options:NSJSONReadingMutableContainers
                                                                                error:nil];
        NSArray *nullKeys = [iPhoneTabsJSON allKeysForObject:[NSNull null]];
        [iPhoneTabsJSON removeObjectsForKeys:nullKeys];
        
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSObject *object, NSDictionary *bindings) {
            
            if ([object isKindOfClass:[NSDictionary class]]) {
                
                NSString *name = ((NSDictionary *)object)[@"name"];
                return [iPhoneTabsJSON objectForKey:name] ? YES : NO;
                
            } else {
                
                NSArray *objArray = (NSArray *)object;
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", iPhoneTabsJSON.allKeys];
                return [objArray filteredArrayUsingPredicate:predicate].count == objArray.count;
                
            }
            
        }];
        stcTabs = [stcTabs filteredArrayUsingPredicate:predicate];
        
        NSMutableArray *iPhoneStcTabs = [NSMutableArray array];
        
        for (NSObject *element in stcTabs) {
            
            if ([element isKindOfClass:[NSArray class]]){
                NSMutableArray *tab = [NSMutableArray array];
                for (NSDictionary *stcTab in (NSArray*) element){
                    NSMutableDictionary *tabElement = [stcTab mutableCopy];
                    tabElement[@"name"] = iPhoneTabsJSON[(id _Nonnull)stcTab[@"name"]];
                    [tab addObject:tabElement];
                }
                [iPhoneStcTabs addObject:tab];
            }else{
                NSDictionary* stcTab = (NSDictionary*) element;
                if (((NSDictionary*) stcTab)[@"name"]) {
                    NSMutableDictionary *tab = [stcTab mutableCopy];
                    tab[@"name"] = iPhoneTabsJSON[(id _Nonnull)stcTab[@"name"]];
                    [iPhoneStcTabs addObject:tab];
                    
                }
            }
            
        }
        
        return iPhoneStcTabs;
        
    } else {
        
        NSLog(@"no iPhone tabs");
        return @[];
        
    }

}

- (void)setupTabs:(NSArray *)stcTabs {
    
    if ([STMCoreAuthController sharedAuthController].controllerState != STMAuthSuccess) {
        
    #if defined (CONFIGURATION_DebugVfs) || defined (CONFIGURATION_ReleaseVfs)

        [self registerTabWithStoryboardParameters:@{@"name": @"STMAuthOld",
                                                    @"title": NSLocalizedString(@"AUTHORIZATION", nil),
                                                    @"imageName": @"password2-128.png"} atIndex:0];
                                        
    #else

        [self registerTabWithStoryboardParameters:@{@"name": @"STMAuth",
                                                    @"title": NSLocalizedString(@"AUTHORIZATION", nil),
                                                    @"imageName": @"password2-128.png"} atIndex:0];

    #endif
        
    } else {
        
        [self processTabsArray:stcTabs];
        
// temporary tab for coding
        
//        [self registerTabWithStoryboardParameters:@{@"name"     : @"STMWKWebView",
//                                                      @"title"  : @"VISITs"}
//                                          atIndex:4/*stcTabs.count*/];
//        
//        [self registerTabWithStoryboardParameters:@{@"name"     : @"STMWKWebView",
//                                                    @"title"    : @"VISITs111"}
//                                          atIndex:4/*stcTabs.count*/];
        
// end of temporary tab

    }

}

- (void)processTabsArray:(NSArray *)stcTabs {
    
//    stcTabs = [self testStcTabs];
//    NSLog(@"stcTabs %@", stcTabs);
    
    for (id tabItem in stcTabs) {
        
        NSUInteger index = [stcTabs indexOfObject:tabItem];
        [self processTabItem:tabItem atIndex:index];
        
    }

}

- (void)processTabItem:(id)tabItem atIndex:(NSUInteger)index {
    
    if ([tabItem isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary *parameters = (NSDictionary *)tabItem;
        
        [self processTabItemWithParameters:parameters atIndex:index];
        
    } else if ([tabItem isKindOfClass:[NSArray class]]) {
        
        for (id subItem in tabItem) {

            [self processTabItem:subItem atIndex:index];
            
        }
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"stcTabs wrong format at index %lu", (unsigned long)index];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
        
    }

}

- (void)processTabItemWithParameters:(NSDictionary *)parameters atIndex:(NSUInteger)index {
    
    NSString *minBuild = parameters[@"minBuild"];
    NSString *maxBuild = parameters[@"maxBuild"];
    NSString *minOS = parameters[@"minOs"];
    NSString *modelVersion = self.session.persistenceDelegate.modelVersion;
    
    if (minBuild && ([modelVersion integerValue] < [minBuild integerValue])) return;
    if (maxBuild && ([modelVersion integerValue] > [maxBuild integerValue])) return;
    if (minOS && (SYSTEM_VERSION < [minOS integerValue])) return;

    BOOL isDebug = [parameters[@"ifdef"] isEqualToString:@"DEBUG"];

    if (isDebug) {
#ifdef DEBUG
        [self registerTabWithStoryboardParameters:parameters atIndex:index];
#endif
    } else {
        
        [self registerTabWithStoryboardParameters:parameters atIndex:index];
        
    }

}

- (NSArray *)testStcTabs {
    
// stcTabs should be array with dictionaries and arrays (with dictionaries)
    
    return @[
                @[
                    @{
                        @"imageName": @"checked_user-128.png",
                        @"name": @"STMProfile",
                        @"title": @"Profile"
                    }
                ],
//                @{
//                    @"imageName": @"christmas_gift-128.png",
//                    @"name": @"STMCampaigns",
//                    @"title": @"Campaign"
//                },
                @{
                    @"authCheck": @"localStorage.getItem('r50.accessToken')",
                    @"imageName": @"purchase_order-128.png",
                    @"name": @"STMWebView",
                    @"title": @"WebView",
                    @"url": @"https://sis.bis100.ru/r50/beta/tp/"
                },
                @[
                    @{
                        @"imageName": @"cash_receiving-128.png",
                        @"name": @"STMDebts",
                        @"title": @"Debts"
                        },
                    @{
                        @"imageName": @"banknotes-128.png",
                        @"name": @"STMUncashing",
                        @"title": @"Uncashing"
                        }
                ],
                @[
                    @{
                        @"imageName": @"message-128.png",
                        @"name": @"STMMessages",
                        @"title": @"Messages"
                        },
                    @{
                        @"imageName": @"Dossier Folder-100.png",
                        @"minBuild": @"70",
                        @"name": @"STMCatalog",
                        @"title": @"Catalog"
                        },
                    @{
                        @"imageName": @"bill-128.png",
                        @"minBuild": @"70",
                        @"name": @"STMOrders",
                        @"title": @"Orders"
                        }
                ],
                @[
                    @{
                        @"ifdef": @"DEBUG",
                        @"imageName": @"settings3-128.png",
                        @"name": @"STMSettings",
                        @"title": @"Settings"
//                        },
//                    @{
//                        @"ifdef": @"DEBUG",
//                        @"imageName": @"archive-128.png",
//                        @"name": @"STMLogs",
//                        @"title": @"Logs"
                        }
                ]
            ];
    
}

- (void)initAuthTab {

    NSString *logMessage = @"init auth tab";
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeDebug];

    [self prepareTabs];
    
    self.viewControllers = self.authVCs;
    
}

- (void)initAllTabs {
    
    NSString *logMessage = @"init all tabs";
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeDebug];

    [self prepareTabs];
    [self showUnreadMessageCount];
    [self showTabs];
    [self selectLastSelectedVC];

}

- (void)showTabs {
    
    self.viewControllers = self.currentTabsVCs;

    NSArray *tabBarControlsArray = [self tabBarControlsArray];

    for (UIViewController *vc in self.viewControllers) {

        if ([vc conformsToProtocol:@protocol(STMTabBarItemControllable)]) {

            NSUInteger siblingsCount = [self siblingsForViewController:vc].count;

            if (siblingsCount > 1 || [(id <STMTabBarItemControllable>)vc shouldShowOwnActions]) {

                NSUInteger index = [self.viewControllers indexOfObject:vc];

                if (tabBarControlsArray.count > index) {

                    UIControl *tabBarControl = tabBarControlsArray[index];
                    [self addMoreMarkLabelToControl:tabBarControl];

                }

            }

        } else {
            NSLog(@"%@ is not conforms to protocol <STMTabBarItemControllable>", vc);
        }

    }
    
}

- (void)lastSelectedVC:(UIViewController *)vc {
    
    NSString *logMessage = [NSString stringWithFormat:@"didSelectViewController: %@ %@", vc.title, vc];
    
    [self.session.syncer sendEventViaSocket:STMSocketEventStatusChange
                                  withValue:logMessage];

    NSString *className = NSStringFromClass([vc class]);
    self.lastSelectedTab = @{@(self.selectedIndex) : @{className : vc.title}};

}

- (void)selectLastSelectedVC {
    
    if (!self.lastSelectedTab)
        return;

    NSUInteger lastSelectedIndex = [self.lastSelectedTab.allKeys.firstObject integerValue];
    
    if (lastSelectedIndex >= self.viewControllers.count)
        return;

    NSDictionary *classNameAndTitle = self.lastSelectedTab.allValues.firstObject;
    NSString *className = classNameAndTitle.allKeys.firstObject;
    NSString *title = classNameAndTitle.allValues.firstObject;
    
    UIViewController *selectingVC = self.viewControllers[lastSelectedIndex];
    
    if (![NSStringFromClass([selectingVC class]) isEqualToString:className])
        return;

    if (![selectingVC.title isEqualToString:title])
        return;

    self.selectedIndex = lastSelectedIndex;

}

- (NSArray *)tabBarControlsArray {
    
    NSMutableArray *tabBarControlsArray = [NSMutableArray array];
    
    for (UIView *view in self.tabBar.subviews) {
        
        if ([view isKindOfClass:[UIControl class]]) {
            
            UIControl *controlView = (UIControl *)view;
            [tabBarControlsArray addObject:controlView];
            
        }
        
    }
    
    NSComparator frameComparator = ^NSComparisonResult(id obj1, id obj2) {
        
        CGRect frame1 = [(UIView *)obj1 frame];
        CGRect frame2 = [(UIView *)obj2 frame];
        
        if (frame1.origin.x > frame2.origin.x) return (NSComparisonResult)NSOrderedDescending;
        
        if (frame1.origin.x < frame2.origin.x) return (NSComparisonResult)NSOrderedAscending;
        
        return (NSComparisonResult)NSOrderedSame;
        
    };
    
    [tabBarControlsArray sortUsingComparator:frameComparator];

    return tabBarControlsArray;
    
}

- (void)addMoreMarkLabelToControl:(UIControl *)controlView {
    
    UILabel *moreMarkLabel=[[UILabel alloc]init];
    moreMarkLabel.font = [UIFont systemFontOfSize:14];
    moreMarkLabel.text = @"▲";
    moreMarkLabel.textAlignment=NSTextAlignmentCenter;
    moreMarkLabel.frame=CGRectMake(4, 2, 16, 16);
    moreMarkLabel.textColor=[UIColor lightGrayColor];
    [controlView addSubview:moreMarkLabel];

}

- (void)showTabWithName:(NSString *)tabName {
    
    UIViewController *vc = self.tabs[tabName];
    if (vc) {
        [self setSelectedViewController:vc];
    }
    
}

- (void)showTabAtIndex:(NSUInteger)index {
    
    UIViewController *vc = self.viewControllers[index];
    if (vc) {
        [self setSelectedViewController:vc];
    }

}

- (void)currentTabBarItemDidTapped {
    
    if ([self.currentTappedVC conformsToProtocol:@protocol(STMTabBarItemControllable)]) {
        
        [(id <STMTabBarItemControllable>)self.currentTappedVC showActionPopoverFromTabBarItem];
        
    }
    
}


#pragma mark - show/hide tabbar

- (void)hideTabBar {
        
    NSTimeInterval animationDuration = 0.5;

    self.isInHideTabbarProcess = YES;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];

    CGFloat viewHeight = CGRectGetHeight(self.view.frame);

    for (UIView *view in self.view.subviews) {

        if([view isKindOfClass:[UITabBar class]]) {
            [view setFrame:CGRectMake(view.frame.origin.x, viewHeight, view.frame.size.width, view.frame.size.height)];
        } else {
            [view setFrame:CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, viewHeight)];
        }

    }

    [UIView commitAnimations];

    [self performSelector:@selector(releaseTabbarLock)
               withObject:nil
               afterDelay:animationDuration];
    
}

- (void)releaseTabbarLock {
    self.isInHideTabbarProcess = NO;
    [self.tabBar setHidden:YES];
}

- (void)showTabBar {
    
    if (!self.tabBar.hidden) return;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    
    CGFloat viewHeight = CGRectGetHeight(self.view.frame);
    CGFloat tabbarHeight = CGRectGetHeight(self.tabBar.frame);

    for (UIView *view in self.view.subviews) {

        if([view isKindOfClass:[UITabBar class]]) {
            [view setFrame:CGRectMake(view.frame.origin.x, viewHeight - tabbarHeight, view.frame.size.width, view.frame.size.height)];
            [view setHidden:NO];
        } else {
            [view setFrame:CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, viewHeight - tabbarHeight)];
        }
        
    }
    
    [UIView commitAnimations];
    
}


#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {

    if ([viewController isEqual:self.selectedViewController]) {
        
        self.currentTappedVC = viewController;
        [self currentTabBarItemDidTapped];
        self.currentTappedVC = nil;

        return NO;
        
    } else {
    
        return !self.isInHideTabbarProcess;

    }
    
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {

    [self lastSelectedVC:viewController];
    
//    [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate testCrash];
    
}


#pragma mark - alertView & delegate

- (UIAlertController *)authAlert {
    
    if (!_authAlert) {
        
        _authAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ERROR", nil) message:NSLocalizedString(@"U R NOT AUTH", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:nil];
        
        [_authAlert addAction:okButton];
        
    }
    return _authAlert;
    
}

- (void)showAuthAlert {
    
    if (!self.presentedViewController && [STMCoreAuthController sharedAuthController].controllerState != STMAuthEnterPhoneNumber) {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self presentViewController:self.authAlert animated:YES completion:nil];
        }];
        [self showTabWithName:@"STMAuthTVC"];
        
    }
    
}

- (UIAlertController *)lowFreeSpaceAlert {
    
    if (!_lowFreeSpaceAlert) {
        
        _lowFreeSpaceAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"WARNING", nil) message:NSLocalizedString(@"LOW FREE SPACE ALERT", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:nil];
        
        [_lowFreeSpaceAlert addAction: okButton];

    }
    return _lowFreeSpaceAlert;
    
}

- (void)showLowFreeSpaceAlert {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    
        if (!self.lowFreeSpaceAlertWasShown) {
            
                self.lowFreeSpaceAlertWasShown = YES;
                [self presentViewController:self.lowFreeSpaceAlert animated:YES completion:nil];
            
        }
        
    }];
    
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (alertView.tag == 1) {

        if (buttonIndex == 1) {
            
            NSLog(@"self.appDownloadUrl %@", self.appDownloadUrl);
            NSURL *updateURL = [NSURL URLWithString:self.appDownloadUrl];
            [[UIApplication sharedApplication] openURL:updateURL];

        } else {
            

        }
        
        self.updateAlertIsShowing = NO;
        
    }
    
}

- (void)authStateChanged {

//    if ([STMCoreAuthController sharedAuthController].controllerState == STMAuthEnterPhoneNumber) {
//        
//        [self initAuthTab];
//        
//    } else if ([STMCoreAuthController sharedAuthController].controllerState == STMAuthRequestRoles) {
//
//        [self.view addSubview:self.spinnerView];
//        
//    }
    
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    if (self.session.status == STMSessionRunning) {
        [self initAllTabs];
        [self removeSpinner];
    }
    
    if (!self.session) {
        [self removeSpinner];
    }
    
}

- (void)showUnreadMessageCount {
    
    UIViewController *vc = self.tabs[@"STMMessages"];
    
    if (vc) {
        
        NSInteger unreadCount = [STMMessageController unreadMessagesCount];
        NSString *badgeValue = (unreadCount > 0) ? [NSString stringWithFormat:@"%@", @(unreadCount)] : nil;
        vc.tabBarItem.badgeValue = badgeValue;
        [UIApplication sharedApplication].applicationIconBadgeNumber = badgeValue.integerValue;
        
    }
    
}

- (void)newAppVersionAvailable:(NSNotification *)notification {

    if (!self.updateAlertIsShowing) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        
        NSNumber *appVersion = [defaults objectForKey:@"availableVersion"];
        self.appDownloadUrl = [defaults objectForKey:@"appDownloadUrl"];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UPDATE AVAILABLE", nil)
                                                                message:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"VERSION", nil), appVersion]
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"CANCEL", nil)
                                                      otherButtonTitles:NSLocalizedString(@"UPDATE", nil), nil];
            
            alertView.tag = 1;
            
            UIViewController *vc = self.authVCs.lastObject;
            vc.tabBarItem.badgeValue = @"!";
            
            self.updateAlertIsShowing = YES;
            
            [alertView show];
            
        }];

    }

}

- (void)haveUnsyncedObjects {
    [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
}

-(void)haveNoUnsyncedObjects {
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}

- (void)setDocumentReady {
    
    [STMClientDataController checkAppVersion];
    [STMMessageController showMessageVCsIfNeeded];

}

- (void)documentNotReady {

    [self removeSpinner];

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ERROR", nil)
                                                            message:NSLocalizedString(@"DOCUMENT_ERROR", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
        
    }];
    
}

- (void)removeSpinner {
    
    [self.spinnerView removeFromSuperview];
    self.spinnerView = nil;

}


#pragma mark - notifications

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(showAuthAlert)
               name:@"notAuthorized"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(authStateChanged)
               name:@"authControllerStateChanged"
             object:[STMCoreAuthController sharedAuthController]];
    
//    [nc addObserver:self
//           selector:@selector(showUnreadMessageCount)
//               name:@"messageIsRead"
//             object:nil];

    [nc addObserver:self
           selector:@selector(newAppVersionAvailable:)
               name:NOTIFICATION_NEW_VERSION_AVAILABLE
             object:nil];
    
    [nc addObserver:self
           selector:@selector(newAppVersionAvailable:)
               name:@"updateButtonPressed"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(haveUnsyncedObjects)
               name:NOTIFICATION_SYNCER_HAVE_UNSYNCED_OBJECTS
             object:nil];
    
    [nc addObserver:self
           selector:@selector(haveNoUnsyncedObjects)
               name:NOTIFICATION_SYNCER_HAVE_NO_UNSYNCED_OBJECTS
             object:nil];
        
    [nc addObserver:self
           selector:@selector(setDocumentReady)
               name:NOTIFICATION_DOCUMENT_READY
             object:nil];
    
    [nc addObserver:self
           selector:@selector(documentNotReady)
               name:NOTIFICATION_DOCUMENT_NOT_READY
             object:nil];
    
    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:self.session];

    [nc addObserver:self
           selector:@selector(showLowFreeSpaceAlert)
               name:@"lowFreeDiskSpace"
             object:nil];
    
}

- (void)dealloc {
    [self removeObservers];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - view lifecycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
