//
//  STMSessionManagement.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 3/24/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMCoreControlling.h"

#import "STMRequestAuthenticatable.h"
#import "STMDocument.h"
#import "STMPersistingFullStack.h"
#import "STMSocketConnection.h"
#import "STMNotifications.h"
#import "STMDataSyncingSubscriber.h"
#import "STMLogging.h"

typedef NS_ENUM(NSInteger, STMSessionStatus) {
    STMSessionIdle,
    STMSessionStarting,
    STMSessionRunning,
    STMSessionFinishing,
    STMSessionStopped,
    STMSessionRemoving
};


@protocol STMSyncer <NSObject>

@property (readonly) BOOL transportIsReady;
@property (readonly) BOOL isReceivingData;
@property (readonly) BOOL isSendingData;

- (void)sendData; // only used for checkClientData — may be do it some other way
- (void)receiveData;

- (void)sendEventViaSocket:(STMSocketEvent)event withValue:(id)value;

- (void)prepareToDestroy;

@end


@protocol STMSettingsController <NSObject>

- (NSDictionary *)currentSettingsForGroup:(NSString *)group;
- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group;

@property (readonly) NSArray *currentSettings;
@property (readonly) NSArray *groupNames;

@end

#define STM_SESSION_SETTINGS_CHANGED @"SettingsChanged"

@protocol STMSession <NSObject,STMNotifications>

@property (readonly) STMDocument *document; // have to remove document property after full implementation of persister

@property (nonatomic, strong) NSObject <STMPersistingFullStack> * persistenceDelegate;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic) STMSessionStatus status;
@property (nonatomic, strong) id <STMSettingsController> settingsController;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (readonly) id <STMLogger, UITableViewDataSource, UITableViewDelegate> logger;
@property (nonatomic, strong) id <STMSyncer,STMDataSyncingSubscriber> syncer;

- (id <STMSession>)initWithUID:(NSString *)uid
                        iSisDB:(NSString *)iSisDB
                  authDelegate:(id <STMRequestAuthenticatable>)authDelegate
                      trackers:(NSArray *)trackers
                 startSettings:(NSDictionary *)startSettings;

- (BOOL)isRunningTests;

- (id <STMCoreControlling>)controllerWithClass:(Class)controllerClass;
- (id <STMCoreControlling>)controllerWithName:(NSString *)name;

@optional

- (Class)locationClass;

@end


@protocol STMSessionManager <NSObject>

- (id <STMSession>)startSessionForUID:(NSString *)uid
                               iSisDB:(NSString *)iSisDB
                         authDelegate:(id <STMRequestAuthenticatable>)authDelegate
                             trackers:(NSArray *)trackers
                        startSettings:(NSDictionary *)startSettings
              defaultSettingsFileName:(NSString *)defualtSettingsFileName;

- (void)stopSessionForUID:(NSString *)uid;
- (void)sessionStopped:(id)session;
- (void)cleanStoppedSessions;
- (void)removeSessionForUID:(NSString *)uid;

@end
