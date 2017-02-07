//
//  STMSyncer.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMSessionManagement.h"
#import "STMRequestAuthenticatable.h"
#import "STMSocketConnection.h"
#import "STMDataSyncing.h"
#import "STMDefantomizing.h"
#import "STMDataDownloading.h"


@interface STMSyncer : NSObject <STMSyncer, STMSocketConnectionOwner, STMDataSyncingSubscriber, STMDataDownloadingOwner, STMDefantomizingOwner>

@property (nonatomic, strong) id <STMSession> session;

@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMPersistingObserving> persistenceDelegate;
@property (nonatomic, strong) id <STMDataSyncing> dataSyncingDelegate;
@property (nonatomic, strong) id <STMDataDownloading> dataDownloadingDelegate;
@property (nonatomic, strong) id <STMDefantomizing> defantomizingDelegate;

@property (nonatomic) NSTimeInterval syncInterval;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;
@property (nonatomic) BOOL transportIsReady;
@property (nonatomic) BOOL isReceivingData;
@property (nonatomic) BOOL isSendingData;


- (void)checkSocket;
- (void)checkSocketForBackgroundFetchWithFetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;

- (void)closeSocketInBackground;

- (void)prepareToDestroy;

- (void)upload;
- (void)fullSync;
- (void)receiveEntities:(NSArray *)entitiesNames;

- (void)sendEventViaSocket:(STMSocketEvent)event
                 withValue:(id)value;


@end
