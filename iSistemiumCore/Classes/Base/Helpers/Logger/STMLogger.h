//
//  STMLogger.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSessionManagement.h"


@interface STMLogger : NSObject

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic, weak) UITableView *tableView;

@end

#import "STMLogger+Logger.h"
#import "STMLogger+TableView.h"
