//
//  STMUnsyncedDataHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncing.h"

#import "STMPersistingPromised.h"
#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMPersistingObserving.h"
#import "STMModelling.h"


@interface STMUnsyncedDataHelper : NSObject <STMDataSyncing>

@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMPersistingObserving, STMModelling> persistenceDelegate;


@end
