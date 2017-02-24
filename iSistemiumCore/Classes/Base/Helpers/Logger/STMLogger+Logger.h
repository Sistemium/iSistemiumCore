//
//  STMLogger+Logger.h
//  iSisSales
//
//  Created by Alexander Levin on 10/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMLogger.h"
#import "STMLogging.h"

@interface STMLogger (Logger) <STMLogger>

+ (void)requestInfo:(NSString *)xidString;
+ (void)requestObjects:(NSDictionary *)parameters;
+ (void)requestDefaults;

- (NSArray *)syncingTypesForSettingType:(NSString *)settingType;

- (NSString *)stringTypeForNumType:(STMLogMessageType)numType;

- (NSString *)loggerKey;


- (NSArray *)checkMessageForRepeatingPattern:(NSDictionary *)logMessageDic;


@end
