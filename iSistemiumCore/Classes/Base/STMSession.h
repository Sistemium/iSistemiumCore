//
//  STMSession.h
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
#import "STMLocationTracker.h"
#import "STMBatteryTracker.h"
#import "STMSyncer.h"

@interface STMSession : NSObject <STMSession>

@property (nonatomic, strong) id <STMRequestAuthenticatable> authDelegate;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic, strong) NSString *status;
@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) STMLogger *logger;
@property (nonatomic, strong) id <STMSessionManager> manager;
@property (nonatomic, strong) STMSettingsController *settingsController;
@property (nonatomic, strong) STMLocationTracker *locationTracker;
@property (nonatomic, strong) STMBatteryTracker *batteryTracker;
@property (nonatomic, strong) NSMutableDictionary *trackers;
@property (nonatomic, strong) NSDictionary *settingsControls;
@property (nonatomic, strong) NSDictionary *defaultSettings;
@property (nonatomic, strong) STMSyncer *syncer;


+ (STMSession *)initWithUID:(NSString *)uid
                     iSisDB:(NSString *)iSisDB
              authDelegate:(id <STMRequestAuthenticatable>)authDelegate
                  trackers:(NSArray *)trackers
             startSettings:(NSDictionary *)startSettings
            documentPrefix:(NSString *)prefix;

- (void)stopSession;

- (void)dismissSession;


@end
