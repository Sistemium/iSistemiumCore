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

typedef NS_ENUM(NSInteger, STMSyncerState) {
    STMSyncerIdle,
    STMSyncerSendData,
    STMSyncerSendDataOnce,
    STMSyncerReceiveData
};

typedef NS_ENUM(NSInteger, STMSessionStatus) {
    STMSessionIdle,
    STMSessionStarting,
    STMSessionRunning,
    STMSessionFinishing,
    STMSessionStopped,
    STMSessionRemoving
};

typedef NS_ENUM(NSInteger, STMLogMessageType) {
    STMLogMessageTypeImportant,
    STMLogMessageTypeError,
    STMLogMessageTypeWarning,
    STMLogMessageTypeInfo,
    STMLogMessageTypeDebug
};


@protocol STMLogger <NSObject>

- (void)saveLogMessageWithText:(NSString *)text;
- (void)saveLogMessageWithText:(NSString *)text type:(NSString *)type;
- (void)saveLogMessageWithText:(NSString *)text numType:(STMLogMessageType)numType;
- (void)saveLogMessageDictionaryToDocument;

- (void)saveLogMessageWithText:(NSString *)text
                          type:(NSString *)type
                         owner:(STMDatum *)owner;

@property (nonatomic, weak) UITableView *tableView;

@end


@protocol STMSyncer <NSObject>

@property (nonatomic) STMSyncerState syncerState;
@property (readonly) BOOL transportIsReady;
@property (readonly) BOOL isReceivingData;
@property (readonly) BOOL isSendingData;

- (void) setSyncerState:(STMSyncerState) syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result)) handler;

- (void)sendEventViaSocket:(STMSocketEvent)event withValue:(id)value;

- (void)prepareToDestroy;

@end


@protocol STMSettingsController <NSObject>

- (NSArray *)currentSettings;
- (NSMutableDictionary *)currentSettingsForGroup:(NSString *)group;
- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group;
//- (id)settingForDictionary:(NSDictionary *)dictionary;


@end


@protocol STMSession <NSObject>

@property (readonly) STMDocument *document; // have to remove document property after full implementation of persister

@property (nonatomic, strong) NSObject <STMPersistingFullStack> * persistenceDelegate;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic) STMSessionStatus status;
@property (nonatomic, strong) id <STMSettingsController> settingsController;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (nonatomic, strong) NSDictionary *defaultSettings;
@property (nonatomic, strong) NSDictionary *startSettings;
@property (nonatomic, strong) id <STMLogger, UITableViewDataSource, UITableViewDelegate> logger;
@property (nonatomic, strong) id <STMSyncer> syncer;

+ (id <STMSession>)initWithUID:(NSString *)uid
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
