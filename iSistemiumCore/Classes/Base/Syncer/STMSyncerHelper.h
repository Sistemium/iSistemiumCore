//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataSyncing.h"

#import "STMPersistingPromised.h"
#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMPersistingObserving.h"
#import "STMModelling.h"


@interface STMSyncerHelper : NSObject <STMDataSyncing>

@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMPersistingObserving, STMModelling> persistenceDelegate;

@property (nonatomic, strong, readonly) NSMutableArray *failToResolveFantomsArray;


@end
