//
//  STMSessionManagement.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 3/24/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMRequestAuthenticatable.h"
#import "STMDocument.h"
#import "STMPersistingPromised.h"
#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMModelling.h"
#import "STMPersistingObserving.h"

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


@protocol STMLogger <NSObject, UITableViewDataSource, UITableViewDelegate>

- (void)saveLogMessageWithText:(NSString *)text;
- (void)saveLogMessageWithText:(NSString *)text type:(NSString *)type;
- (void)saveLogMessageWithText:(NSString *)text numType:(STMLogMessageType)numType;
- (void)saveLogMessageDictionaryToDocument;

@property (nonatomic, weak) UITableView *tableView;

@end


@protocol STMSyncer <NSObject>

@property (nonatomic) STMSyncerState syncerState;
- (void) setSyncerState:(STMSyncerState) syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result)) handler;
@end


@protocol STMSettingsController <NSObject>

- (NSArray *)currentSettings;
- (NSMutableDictionary *)currentSettingsForGroup:(NSString *)group;
- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group;
- (id)settingForDictionary:(NSDictionary *)dictionary;

@end

@class STMPersister;

@protocol STMSession <NSObject>

@property (nonatomic, strong) STMDocument *document; // have to remove document property after full implementation of persister

@property (nonatomic, strong) NSObject <STMPersistingPromised,STMPersistingAsync,STMPersistingSync,STMModelling,STMPersistingObserving> * persistenceDelegate;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic) STMSessionStatus status;
@property (nonatomic, strong) id <STMSettingsController> settingsController;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (nonatomic, strong) NSDictionary *defaultSettings;
@property (nonatomic, strong) NSDictionary *startSettings;
@property (nonatomic, strong) id <STMLogger> logger;
@property (nonatomic, strong) id <STMSyncer> syncer;

+ (id <STMSession>)initWithUID:(NSString *)uid
                        iSisDB:(NSString *)iSisDB
                  authDelegate:(id <STMRequestAuthenticatable>)authDelegate
                      trackers:(NSArray *)trackers
                 startSettings:(NSDictionary *)startSettings;

- (void)persisterCompleteInitializationWithSuccess:(BOOL)success;

- (BOOL)isRunningTests;

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
