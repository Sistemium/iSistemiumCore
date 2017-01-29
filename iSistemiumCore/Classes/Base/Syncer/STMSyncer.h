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
#import "STMSocketTransportOwner.h"
#import "STMDataSyncing.h"
#import "STMDefantomizing.h"


@interface STMSyncer : NSObject <STMSyncer, STMSocketTransportOwner>

@property (nonatomic, strong) id <STMSession> session;

@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingAsync, STMPersistingSync> persistenceDelegate;
@property (nonatomic, strong) id <STMDataSyncing> dataSyncingDelegate;
@property (nonatomic, strong) id <STMDefantomizing> syncerHelper;

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
- (void)sendObjects:(NSDictionary *)parameters;

- (void)sendEventViaSocket:(STMSocketEvent)event
                 withValue:(id)value;


@end
