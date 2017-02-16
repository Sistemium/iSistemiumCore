//
//  STMUserDefaults.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 26/07/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreUserDefaults.h"

@interface STMUserDefaults : NSObject <STMCoreUserDefaults>

+ (instancetype)standardUserDefaults;

@end
