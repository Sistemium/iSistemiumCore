//
//  STMClientDataController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

@interface STMClientDataController : STMCoreController

+ (void)checkClientData;
+ (void)checkAppVersion;

+ (STMClientData *)clientData;

+ (NSString *)deviceUUIDString;


@end
