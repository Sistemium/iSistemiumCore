//
//  STMCoreSessionManager.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSessionManagement.h"
#import "STMCoreSession.h"

@interface STMCoreSessionManager : NSObject <STMSessionManager>

@property (nonatomic, strong) NSMutableDictionary <NSString *, STMCoreSession *> *sessions;
@property (nonatomic, strong) id <STMSession> currentSession;
@property (nonatomic, strong) NSString *currentSessionUID;

+ (instancetype)sharedManager;

- (id <STMSession>)startSessionForUID:(NSString *)uid
                               iSisDB:(NSString *)iSisDB
                        authDelegate:(id <STMRequestAuthenticatable>)authDelegate
                            trackers:(NSArray *)trackers
                            startSettings:(NSDictionary *)startSettings
                    defaultSettingsFileName:(NSString *)defaultSettingsFileName;

- (void)stopSessionForUID:(NSString *)uid;

- (void)sessionStopped:(id <STMSession>)session;

- (void)cleanStoppedSessions;

- (void)removeSessionForUID:(NSString *)uid;


@end
