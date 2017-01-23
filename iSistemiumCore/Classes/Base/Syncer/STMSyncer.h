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


@interface STMSyncer : NSObject <STMSyncer, STMSocketTransportOwner>

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic) NSTimeInterval syncInterval;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;
@property (nonatomic) BOOL transportIsReady;

- (void)checkSocket;
- (void)closeSocketInBackground;

- (void)prepareToDestroy;

- (void)upload;
- (void)fullSync;
- (void)receiveEntities:(NSArray *)entitiesNames;
- (void)sendObjects:(NSDictionary *)parameters;

- (void)sendEventViaSocket:(STMSocketEvent)event
                 withValue:(id)value;


#warning - have to do something with setSyncerState: method
- (void)setSyncerState:(STMSyncerState)syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler;


@end
