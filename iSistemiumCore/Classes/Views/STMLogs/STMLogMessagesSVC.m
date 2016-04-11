//
//  STMLogMessagesSVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMLogMessagesSVC.h"


@interface STMLogMessagesSVC ()


@end

@implementation STMLogMessagesSVC

- (STMLogMessagesDetailTVC *)detailTVC {
    
    if (!_detailTVC) {
        
        UINavigationController *navController = (UINavigationController *)self.viewControllers[1];
        
        UIViewController *detailTVC = navController.viewControllers[0];
        
        if ([detailTVC isKindOfClass:[STMLogMessagesDetailTVC class]]) {
            _detailTVC = (STMLogMessagesDetailTVC *)detailTVC;
        }
        
    }
    
    return _detailTVC;
    
}

- (STMLogMessagesMasterTVC *)masterTVC {
    
    if (!_masterTVC) {
        
        UINavigationController *navController = (UINavigationController *)self.viewControllers[0];
        
        UIViewController *masterTVC = navController.viewControllers[0];
        
        if ([masterTVC isKindOfClass:[STMLogMessagesMasterTVC class]]) {
            
            _masterTVC = (STMLogMessagesMasterTVC *)masterTVC;
            
        }
        
    }
    
    return _masterTVC;
    
}


#pragma mark - view lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];

}

@end
