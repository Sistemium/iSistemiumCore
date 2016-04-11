//
//  STMSettingsTVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 4/13/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMSessionManagement.h"

@interface STMSettingsTVC : UITableViewController

@property (nonatomic, strong) id <STMSession> session;

@end


@interface STMSettingsTVCell : UITableViewCell

@end