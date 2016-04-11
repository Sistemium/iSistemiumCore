//
//  STMActionPopoverNC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 19/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMActionPopoverNC.h"
#import "STMRootTBC.h"
#import "STMTabBarButtonTVC.h"
#import "STMFunctions.h"


@interface STMActionPopoverNC () <UIPopoverControllerDelegate>

@property (nonatomic, strong) NSArray *siblings;
@property (nonatomic, strong) UIPopoverController *actionSheetPopover;


@end


@implementation STMActionPopoverNC

- (NSArray *)siblings {
    
    if (!_siblings) {
        _siblings = [[STMRootTBC sharedRootVC] siblingsForViewController:self];
    }
    return _siblings;
    
}

- (STMTabBarButtonTVC *)buttonsTVC {

    STMTabBarButtonTVC *vc = [[STMTabBarButtonTVC alloc] init];
    
    vc.siblings = self.siblings;
    vc.actions = self.actions;
    vc.parentVC = self;

    return vc;
    
}

- (UIPopoverController *)actionSheetPopover {
    
    if (!_actionSheetPopover) {
        
        STMTabBarButtonTVC *vc = [self buttonsTVC];
        
        UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:vc];
        popover.delegate = self;
        popover.popoverContentSize = CGSizeMake(vc.view.frame.size.width, vc.view.frame.size.height);
        
        _actionSheetPopover = popover;
        
    }
    return _actionSheetPopover;
    
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.actionSheetPopover = nil;
}


#pragma mark - STMTabBarItemControllable protocol

- (BOOL)shouldShowOwnActions {
    return NO;
}

- (void)showActionPopoverFromTabBarItem {
    
    if (self.siblings.count > 1 || self.actions.count > 0) {
        
        if (IPAD) {
            
            if (self.tabBarController.view) {

                CGRect rect = [STMFunctions frameOfHighlightedTabBarButtonForTBC:(UITabBarController *)self.tabBarController];
                
                [self.actionSheetPopover presentPopoverFromRect:rect
                                                         inView:(UIView * _Nonnull)self.tabBarController.view
                                       permittedArrowDirections:UIPopoverArrowDirectionAny
                                                       animated:YES];

            }
            
        } else if (IPHONE) {
            
            STMTabBarButtonTVC *vc = [self buttonsTVC];
            
            [self presentViewController:vc animated:YES completion:^{
                
            }];
            
        }
        
    }
    
}

- (void)selectSiblingAtIndex:(NSUInteger)index {

    [self dismissButtonsTVC];

    UIViewController *vc = self.siblings[index];
    
    if (vc != self) {
        [[STMRootTBC sharedRootVC] replaceVC:self withVC:vc];
    }

}

- (void)selectActionAtIndex:(NSUInteger)index {
    
    [self dismissButtonsTVC];
    
}

- (void)dismissButtonsTVC {
    
    if (IPAD) {
        
        [self.actionSheetPopover dismissPopoverAnimated:YES];
        
    } else if (IPHONE) {
        
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
        
    }
    
}


#pragma mark - view lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
