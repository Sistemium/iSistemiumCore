//
//  STMPersisterFantoms.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingFantoms.h"


@interface STMPersisterFantoms : NSObject <STMPersistingFantoms>

+ (instancetype)persisterFantomsWithPersistenceDelegate:(id <STMPersistingFullStack>)persistenceDelegate;


@end
