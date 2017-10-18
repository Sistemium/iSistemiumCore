//
//  STMSyncer.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

#import "STMSocketConnection.h"
#import "STMDataSyncing.h"
#import "STMDefantomizing.h"
#import "STMDataDownloading.h"

@interface STMSyncer : STMCoreController <STMSyncer, STMSocketConnectionOwner, STMDataSyncingSubscriber, STMDataDownloadingOwner, STMDefantomizingOwner>

@property (nonatomic, strong) id <STMDataSyncing> dataSyncingDelegate;
@property (nonatomic, strong) id <STMDataDownloading> dataDownloadingDelegate;
@property (nonatomic, strong) id <STMDefantomizing> defantomizingDelegate;

@property (nonatomic) NSTimeInterval syncInterval;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;
@property (nonatomic,readwrite) BOOL transportIsReady;
@property (nonatomic,readwrite) BOOL isReceivingData;
@property (nonatomic,readwrite) BOOL isSendingData;

@property (nonatomic, strong) NSString *socketUrlString;

- (void)checkSocket;

- (void)closeSocketInBackground;

- (void)upload;
- (void)fullSync;
- (void)receiveEntities:(NSArray *)entitiesNames;

- (void)sendEventViaSocket:(STMSocketEvent)event
                 withValue:(id)value;

- (void)sendFindWithValue:(NSDictionary *)value;


@end
