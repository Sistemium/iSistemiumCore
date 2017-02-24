//
//  STMLogging.h
//  iSisSales
//
//  Created by Alexander Levin on 24/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, STMLogMessageType) {
    STMLogMessageTypeImportant,
    STMLogMessageTypeError,
    STMLogMessageTypeWarning,
    STMLogMessageTypeInfo,
    STMLogMessageTypeDebug
};

@protocol STMLogger <NSObject>

- (void)importantMessage:(NSString *)text;
- (void)errorMessage:(NSString *)text;
- (void)warningMessage:(NSString *)text;
- (void)infoMessage:(NSString *)text;
- (void)debugMessage:(NSString *)text;

- (void)saveLogMessageWithText:(NSString *)text;
- (void)saveLogMessageWithText:(NSString *)text numType:(STMLogMessageType)numType;
- (void)saveLogMessageDictionaryToDocument;

@property (nonatomic, weak) UITableView *tableView;

@end
