//
//  STMAuthNC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMAuthNC.h"
#import "STMAuthPhoneVC.h"
#import "STMAuthSMSVC.h"
#import "STMCoreWKWebViewVC.h"

#define VFS_AUTH_URL @"https://vfsm.sistemium.com/"

@interface STMAuthNC () <UINavigationControllerDelegate, UIAlertViewDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) STMAuthPhoneVC *phoneVC;
@property (nonatomic, strong) STMAuthSMSVC *smsVC;
@property (nonatomic, strong) STMAuthVC *requestRolesVC;
@property (nonatomic, strong) STMCoreWKWebViewVC *webVC;

@end

@implementation STMAuthNC

+ (STMAuthNC *)sharedAuthNC {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedAuthNC = nil;
    
    dispatch_once(&pred, ^{
        _sharedAuthNC = [[self alloc] init];
    });
    
    return _sharedAuthNC;

}

- (STMAuthPhoneVC *)phoneVC {
    
    if (!_phoneVC) {
        _phoneVC = [self.storyboard instantiateViewControllerWithIdentifier:@"authPhoneVC"];
    }
    return _phoneVC;
    
}

- (STMCoreWKWebViewVC *)webVC {
    
    if (!_webVC) {
        _webVC = [self.storyboard instantiateViewControllerWithIdentifier:@"coreWKWebViewVC"];
        _webVC.directLoadUrl = VFS_AUTH_URL;
    }
    return _webVC;
    
}

- (STMAuthSMSVC *)smsVC {
    
    if (!_smsVC) {
        _smsVC = [self.storyboard instantiateViewControllerWithIdentifier:@"authSMSVC"];
    }
    return _smsVC;
    
}

- (STMAuthVC *)requestRolesVC {
    
    if (!_requestRolesVC) {
        _requestRolesVC = [self.storyboard instantiateViewControllerWithIdentifier:@"requestRoles"];
        _requestRolesVC.title = NSLocalizedString(@"CHECK ROLES", nil);
    }
    return _requestRolesVC;
    
}

- (void)authControllerStateChanged {
    
    switch ([STMCoreAuthController sharedAuthController].controllerState) {
            
        case STMAuthStarted:
            
            break;

        case STMAuthEnterPhoneNumber:
            
            #if defined (CONFIGURATION_DebugVfs) || defined (CONFIGURATION_ReleaseVfs)
            
                [self setNavigationBarHidden:YES animated:NO];
            
                [self setViewControllers:@[self.webVC] animated:YES];
                                                
            #else
            
                [self setViewControllers:@[self.phoneVC] animated:YES];
            
            #endif
            
            break;
            
        case STMAuthEnterSMSCode:
            [self setViewControllers:@[self.smsVC] animated:YES];
            
            break;
            
        case STMAuthRequestRoles:
            [self setViewControllers:@[self.requestRolesVC] animated:YES];
            
            break;
            
        case STMAuthSuccess:
            
            [self setViewControllers:@[self.requestRolesVC] animated:YES];
            
            break;
            
        default:
            break;
            
    }
    
}

- (void)authControllerError:(NSNotification *)notification {
    
//#warning have to refactor STMRootTBC to prevent multiple instance of VCs creating
    
    if (self.tabBarController) {
        
        NSString *error = notification.userInfo[@"error"];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ERROR", nil)
                                                                message:error
                                                               delegate:self
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
            alertView.tag = 0;
            [alertView show];
            
        }];

    }
    
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    [(STMAuthVC *)[self.viewControllers lastObject] dismissSpinner];
}


#pragma marl - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
//    NSLog(@"willShowViewController: %@", viewController);
//    NSLog(@"navigationController %@", navigationController.viewControllers);
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
//    NSLog(@"didShowViewController: %@", viewController);
//    NSLog(@"navigationController %@", navigationController.viewControllers);
}


#pragma mark - STMTabBarViewController protocol

- (BOOL)shouldShowOwnActions {
    return NO;
}

- (void)showActionPopoverFromTabBarItem {
    
    if ([STMCoreRootTBC sharedRootVC].newAppVersionAvailable) {
        
//        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"UPDATE", nil), nil];
//        
//        CGRect rect = [STMFunctions frameOfHighlightedTabBarButtonForTBC:self.tabBarController];
//        
//        [actionSheet showFromRect:rect inView:self.view animated:YES];

    }
    
}

- (void)selectSiblingAtIndex:(NSUInteger)index {
    
}

- (void)selectActionAtIndex:(NSUInteger)index {
    
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    
//    if (buttonIndex != -1) {
//
//    }
    
}


#pragma mark - view lifecycle

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(authControllerStateChanged)
               name:@"authControllerStateChanged"
             object:[STMCoreAuthController sharedAuthController]];
    
    [nc addObserver:self
           selector:@selector(authControllerError:)
               name:@"authControllerError"
             object:[STMCoreAuthController sharedAuthController]];

}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)setupViewControllers {

    [self authControllerStateChanged];
    
}

- (void)customInit {
    
    self.delegate = self;
    [self addObservers];
    [self setupViewControllers];
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
}


@end
