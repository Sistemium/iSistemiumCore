//
//  STMUnsyncedDataHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncing.h"
#import "STMCoreController.h"

@interface STMUnsyncedDataHelper : STMCoreController <STMDataSyncing>

+ (STMUnsyncedDataHelper *)unsyncedDataHelperWithPersistence:(id <STMPersistingFullStack>)persistenceDelegate
                                                  subscriber:(id <STMDataSyncingSubscriber>)subscriberDelegate;

@end
