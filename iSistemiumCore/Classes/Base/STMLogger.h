//
//  STMLogger.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSessionManagement.h"
#import "STMDataModel.h"


@interface STMLogger : NSObject <STMLogger, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic, weak) UITableView *tableView;

+ (STMLogger *)sharedLogger;

+ (void)requestInfo:(NSString *)xidString;
+ (void)requestObjects:(NSDictionary *)parameters;
+ (void)requestDefaults;

- (void)saveLogMessageWithText:(NSString *)text;

- (void)saveLogMessageWithText:(NSString *)text
                          type:(NSString *)type;

- (void)saveLogMessageWithText:(NSString *)text
                          type:(NSString *)type
                         owner:(STMDatum *)owner;

- (void)saveLogMessageDictionary:(NSDictionary *)logMessageDic;
- (void)saveLogMessageDictionaryToDocument;

- (NSArray *)syncingTypesForSettingType:(NSString *)settingType;


@end
