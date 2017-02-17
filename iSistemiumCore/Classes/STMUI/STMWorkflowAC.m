//
//  STMWorkflowAC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/09/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMWorkflowAC.h"

@implementation STMWorkflowAC

+ (instancetype)alertControllerWithTitle:(nullable NSString *)title message:(nullable NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle{
    return [super.class
     alertControllerWithTitle:title
     message:message
     preferredStyle:preferredStyle];
}

@end
