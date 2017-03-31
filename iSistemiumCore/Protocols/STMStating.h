//
//  STMStating.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 29/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

@protocol STMStating

//@property(nonatomic, readonly, getter=isIgnoringInteractionEvents) BOOL ignoringInteractionEvents;
//@property(nonatomic,getter=isIdleTimerDisabled) BOOL idleTimerDisabled;
//
//@property(nullable, nonatomic,readonly) UIWindow *keyWindow;
//@property(nonatomic,readonly) NSArray<__kindof UIWindow *>  * _Nonnull windows;

@property(nonatomic,getter=isNetworkActivityIndicatorVisible) BOOL networkActivityIndicatorVisible __TVOS_PROHIBITED;

//@property(readonly, nonatomic) UIStatusBarStyle statusBarStyle;
//
//@property(readonly, nonatomic,getter=isStatusBarHidden) BOOL statusBarHidden;
//
//@property(readonly, nonatomic) UIInterfaceOrientation statusBarOrientation;
//
//@property(nonatomic,readonly) NSTimeInterval statusBarOrientationAnimationDuration;
//@property(nonatomic,readonly) CGRect statusBarFrame;
//
//@property(nonatomic) NSInteger applicationIconBadgeNumber;
//
//@property(nonatomic) BOOL applicationSupportsShakeToEdit;
//
//@property(nonatomic,readonly) UIApplicationState applicationState;
//@property(nonatomic,readonly) NSTimeInterval backgroundTimeRemaining;
//@property (nonatomic, readonly) UIBackgroundRefreshStatus backgroundRefreshStatus;
//
//@property(nonatomic,readonly,getter=isProtectedDataAvailable) BOOL protectedDataAvailable;
//
//@property(nonatomic,readonly) UIUserInterfaceLayoutDirection userInterfaceLayoutDirection;
//
//@property(nonatomic,readonly) UIContentSizeCategory _Nonnull preferredContentSizeCategory;

@end
