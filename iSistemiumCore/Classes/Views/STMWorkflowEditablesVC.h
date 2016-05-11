//
//  STMWorkflowEditablesVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/09/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMWorkflowable.h"


@interface STMWorkflowEditablesVC : UIViewController

@property (nonatomic, strong) NSString *workflow;
@property (nonatomic, strong) NSString *toProcessing;

@property (nonatomic, strong) NSArray *editableFields;

@property (nonatomic, weak) id <STMWorkflowable> parent;


@end
