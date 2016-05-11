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
#import "STMSettingsController.h"
#import "STMCoreLocationTracker.h"
#import "STMCoreBatteryTracker.h"
#import "STMSyncer.h"


@interface STMCoreSession : NSObject <STMSession>

@property (nonatomic, strong) id <STMRequestAuthenticatable> authDelegate;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic) STMSessionStatus status;
@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) STMLogger *logger;
@property (nonatomic, strong) id <STMSessionManager> manager;
@property (nonatomic, strong) STMSettingsController *settingsController;
@property (nonatomic, strong) STMCoreLocationTracker *locationTracker;
@property (nonatomic, strong) STMCoreBatteryTracker *batteryTracker;
@property (nonatomic, strong) NSArray *startTrackers;
@property (nonatomic, strong) NSMutableDictionary *trackers;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (nonatomic, strong) NSDictionary *defaultSettings;
@property (nonatomic, strong) STMSyncer *syncer;


+ (STMCoreSession *)initWithUID:(NSString *)uid
                     iSisDB:(NSString *)iSisDB
              authDelegate:(id <STMRequestAuthenticatable>)authDelegate
                  trackers:(NSArray *)trackers
             startSettings:(NSDictionary *)startSettings
            documentPrefix:(NSString *)prefix;

- (void)stopSession;

- (void)dismissSession;


@end
