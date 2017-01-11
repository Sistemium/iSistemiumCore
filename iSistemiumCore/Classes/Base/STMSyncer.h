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


@interface STMSyncer : NSObject <STMSyncer>

// new

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic) double syncInterval;

- (void)socketReceiveAuthorization;

// old

@property (nonatomic, strong) id <STMRequestAuthenticatable> authDelegate;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;
@property (nonatomic) STMSyncerState syncerState;
@property (nonatomic) STMSyncerState timeoutErrorSyncerState;

- (NSTimeInterval)timeout;

- (void)prepareToDestroy;
- (void)setSyncerState:(STMSyncerState)syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;

- (void)upload;
- (void)fullSync;
- (void)receiveEntities:(NSArray *)entitiesNames;
- (void)sendObjects:(NSDictionary *)parameters;

- (void)nothingToSend;
- (void)bunchOfObjectsSended;
- (void)postObjectsSendedNotification;
- (void)sendFinishedWithError:(NSString *)errorString;

- (NSArray *)unsyncedObjects;
- (NSUInteger)numbersOfAllUnsyncedObjects;
- (NSUInteger)numberOfCurrentlyUnsyncedObjects;

- (void)socketReceiveJSDataAck:(NSArray *)data;
- (void)socketReceiveTimeout;

- (void)socketLostConnection;


@end
