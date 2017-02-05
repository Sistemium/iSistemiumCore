//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingSync.h"
#import "STMDataSyncingState.h"

#import "STMConstants.h"
#import "STMDocument.h"
#import "STMSessionManager.h"


@interface STMSyncerHelper : NSObject

@property (nonatomic, weak) id <STMDataDownloadingOwner> dataDownloadingOwner;
@property (nonatomic, strong) id <STMDataSyncingState> downloadingState;
@property (nonatomic, strong) NSArray *receivingEntitiesNames;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;
@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) id <STMSession> session;

@property (nonatomic, strong, readonly) NSMutableArray *failToResolveFantomsArray;
@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMPersistingObserving> persistenceDelegate;


@end
