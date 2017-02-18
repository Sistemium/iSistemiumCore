//
//  STMCoreSession.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMRequestAuthenticatable.h"
#import "STMSessionManagement.h"
#import "STMDocument.h"
#import "STMLogger.h"
#import "STMCoreSettingsController.h"
#import "STMCoreLocationTracker.h"
#import "STMCoreBatteryTracker.h"
#import "STMModelling.h"
#import "STMSyncer.h"

@interface STMCoreSession : STMCoreObject <STMSession>

@property (nonatomic, weak) id <STMRequestAuthenticatable> authDelegate;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic) STMSessionStatus status;

@property (nonatomic, weak) STMDocument *document;
@property (nonatomic, strong) NSObject <STMPersistingFullStack> * persistenceDelegate;

@property (nonatomic, strong) STMLogger *logger;
@property (nonatomic, weak) id <STMSessionManager> manager;
@property (nonatomic, strong) STMCoreSettingsController *settingsController;
@property (nonatomic, strong) STMCoreLocationTracker *locationTracker;
@property (nonatomic, strong) STMCoreBatteryTracker *batteryTracker;
@property (nonatomic, strong) NSArray *startTrackers;
@property (nonatomic, strong) NSMutableDictionary *trackers;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (nonatomic, strong) NSDictionary *defaultSettings;
@property (nonatomic, strong) NSDictionary *startSettings;

@property (nonatomic,strong) STMSyncer *syncer;

- (void)stopSession;
- (void)dismissSession;

- (Class)settingsControllerClass;
- (void)checkTrackersToStart;

@end
