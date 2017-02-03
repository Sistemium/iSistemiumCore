//
//  STMFakePersisting.h
//  iSisSales
//
//  Created by Alexander Levin on 03/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersistingFullStack.h"

#define STMFakePersistingOptions NSDictionary *

@interface STMFakePersisting : NSObject <STMPersistingSync, STMPersistingPromised>

+ (instancetype)fakePersistingWithOptions:(STMFakePersistingOptions)options;

@end
