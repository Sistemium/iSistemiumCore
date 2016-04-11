//
//  STMClientDataController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"

@interface STMClientDataController : STMController

+ (void)checkClientData;
+ (void)checkAppVersion;

+ (STMClientData *)clientData;

+ (NSData *)deviceUUID;


@end
