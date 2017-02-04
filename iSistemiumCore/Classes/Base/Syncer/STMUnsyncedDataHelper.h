//
//  STMUnsyncedDataHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncing.h"
#import "STMPersistingFullStack.h"


@interface STMUnsyncedDataHelper : NSObject <STMDataSyncing>

@property (nonatomic, strong) id <STMPersistingFullStack> persistenceDelegate;

+ (STMUnsyncedDataHelper *)unsyncedDataHelperWithPersistence:(id <STMPersistingFullStack>)persistenceDelegate
                                                  subscriber:(id <STMDataSyncingSubscriber>)subscriberDelegate;


@end
