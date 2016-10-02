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


@protocol STMSession <NSObject>

+ (id <STMSession>)initWithUID:(NSString *)uid iSisDB:(NSString *)iSisDB authDelegate:(id <STMRequestAuthenticatable>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings documentPrefix:(NSString *)prefix;

@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic) STMSessionStatus status;
@property (nonatomic, strong) id <STMSettingsController> settingsController;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (nonatomic, strong) NSDictionary *defaultSettings;
@property (nonatomic, strong) id <STMLogger> logger;
@property (nonatomic, strong) id <STMSyncer> syncer;

@end


@protocol STMSessionManager <NSObject>

- (id <STMSession>)startSessionForUID:(NSString *)uid iSisDB:(NSString *)iSisDB authDelegate:(id <STMRequestAuthenticatable>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings defaultSettingsFileName:(NSString *)defualtSettingsFileName documentPrefix:(NSString *)prefix;
- (void)stopSessionForUID:(NSString *)uid;
- (void)sessionStopped:(id)session;
- (void)cleanStoppedSessions;
- (void)removeSessionForUID:(NSString *)uid;

@end
