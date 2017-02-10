//
//  STMClientEntityController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

@interface STMClientEntityController : STMCoreController

+ (NSDictionary *)clientEntityWithName:(NSString *)name;

+ (void)clientEntityWithName:(NSString *)name
                     setETag:(NSString *)eTag;


@end
