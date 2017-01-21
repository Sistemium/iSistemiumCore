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

typedef NS_ENUM(NSInteger, STMSocketEvent) {
    STMSocketEventConnect,
    STMSocketEventDisconnect,
    STMSocketEventError,
    STMSocketEventReconnect,
    STMSocketEventReconnectAttempt,
    STMSocketEventStatusChange,
    STMSocketEventInfo,
    STMSocketEventAuthorization,
    STMSocketEventRemoteCommands,
    STMSocketEventData,
    STMSocketEventJSData
};


@interface STMSyncer : NSObject <STMSyncer>

// new

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic) NSTimeInterval syncInterval;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;
@property (nonatomic) BOOL transportIsReady;

- (void)socketReceiveAuthorization;
- (void)socketLostConnection;
- (void)checkSocket;
- (void)closeSocketInBackground;

- (void)prepareToDestroy;

- (void)upload;
- (void)fullSync;
- (void)receiveEntities:(NSArray *)entitiesNames;
- (void)sendObjects:(NSDictionary *)parameters;

- (void)sendEventViaSocket:(STMSocketEvent)event
                 withValue:(id)value;


// old

//@property (nonatomic) STMSyncerState syncerState;
//@property (nonatomic) STMSyncerState timeoutErrorSyncerState;

//- (NSTimeInterval)timeout;

#warning - have to do something with setSyncerState: method
- (void)setSyncerState:(STMSyncerState)syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;

//- (void)nothingToSend;
//- (void)bunchOfObjectsSended;
//- (void)postObjectsSendedNotification;
//- (void)sendFinishedWithError:(NSString *)errorString;

//- (NSArray *)unsyncedObjects;
//- (NSUInteger)numbersOfAllUnsyncedObjects;
//- (NSUInteger)numberOfCurrentlyUnsyncedObjects;

//- (void)socketReceiveJSDataAck:(NSArray *)data;
//- (void)socketReceiveTimeout;


@end
