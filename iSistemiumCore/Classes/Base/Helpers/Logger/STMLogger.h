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

@property (nonatomic, weak) id <STMSession> session;
@property (nonatomic, weak) UITableView *tableView;

@property (nonatomic) NSUInteger patternDepth;
@property (nonatomic, strong) NSMutableArray <NSDictionary *> *lastLogMessagesArray;
@property (nonatomic, strong) NSMutableArray <NSDictionary *> *possiblePatternArray;
@property (nonatomic) BOOL patternDetected;


@end

#import "STMLogger+Logger.h"
#import "STMLogger+TableView.h"
