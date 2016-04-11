//
//  STMLogMessagesSVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMSplitViewController.h"
#import "STMLogMessagesMasterTVC.h"
#import "STMLogMessagesDetailTVC.h"


@interface STMLogMessagesSVC : STMSplitViewController

@property (nonatomic, strong) STMLogMessagesMasterTVC *masterTVC;
@property (nonatomic, strong) STMLogMessagesDetailTVC *detailTVC;

@end
