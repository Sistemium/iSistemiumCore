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


@interface STMSyncerHelper : NSObject <STMDataSyncing>

@property (nonatomic, weak) id <STMPersistingPromised,STMPersistingAsync,STMPersistingSync>persistenceDelegate;

- (void)findFantomsWithCompletionHandler:(void (^)(NSArray *fantomsArray))completionHandler;


@end
