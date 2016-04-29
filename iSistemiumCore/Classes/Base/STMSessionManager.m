//
//  STMSessionManager.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMSessionManager.h"
#import "STMSession.h"
#import "STMSettingsData.h"

#define SETTINGS_SCHEMA @"settings_schema"

@implementation STMSessionManager

+ (STMSessionManager *)sharedManager {
    static dispatch_once_t pred = 0;
    __strong static id _sharedManager = nil;
    dispatch_once(&pred, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}

- (NSMutableDictionary *)sessions {
    if (!_sessions) {
        _sessions = [NSMutableDictionary dictionary];
    }
    return _sessions;
}

- (STMSession *)currentSession {
    return (self.sessions)[self.currentSessionUID];
}

- (void)setCurrentSessionUID:(NSString *)currentSessionUID {
    
    if ([[self.sessions allKeys] containsObject:currentSessionUID] || !currentSessionUID) {
        
        if (_currentSessionUID != currentSessionUID) {
            _currentSessionUID = currentSessionUID;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"currentSessionChanged" object:(self.sessions)[_currentSessionUID]];
        }
        
    }
    
}

- (id <STMSession>)startSessionForUID:(NSString *)uid iSisDB:(NSString *)iSisDB authDelegate:(id<STMRequestAuthenticatable>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings defaultSettingsFileName:(NSString *)defualtSettingsFileName documentPrefix:(NSString *)prefix {
    
    if (uid) {
        
        STMSession *session = (self.sessions)[uid];
        
        if (!session) {
            
            NSDictionary *validSettings = [STMSettingsData settingsFromFileName:defualtSettingsFileName withSchemaName:@"settings_schema"];
            
            session = [STMSession initWithUID:uid
                                       iSisDB:(NSString *)iSisDB
                                 authDelegate:authDelegate
                                     trackers:trackers
                                startSettings:startSettings
                               documentPrefix:prefix];
            
            session.defaultSettings = validSettings[@"values"];
            session.settingsControls = validSettings[@"controls"];
            session.manager = self;

            [self.sessions setValue:session forKey:uid];

            self.currentSessionUID = uid;

        } else {

            self.currentSessionUID = uid;

            session.authDelegate = authDelegate;
            session.status = STMSessionRunning;
            session.logger.session = session;
            
        }
        return session;
        
    } else {
        
        NSLog(@"no uid");
        return nil;
        
    }

}

- (void)stopSessionForUID:(NSString *)uid {
    
    STMSession *session = (self.sessions)[uid];
    
    if (session.status == STMSessionRunning || session.status == STMSessionRemoving) {
        
        if ([self.currentSessionUID isEqualToString:uid]) {
            self.currentSessionUID = nil;
        }
        
        [session stopSession];
        
    }
    
}

- (void)sessionStopped:(id <STMSession>)session {
    
    if (session.status == STMSessionRemoving) {
        
        session.status = STMSessionStopped;
        [self removeSessionForUID:session.uid];
        
    } else {
//        [self removeSessionForUID:session.uid];
    }
    
}

- (void)cleanStoppedSessions {

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.status == %@", @"stopped"];
    NSArray *completedSessions = [[self.sessions allValues] filteredArrayUsingPredicate:predicate];
    
    for (STMSession *session in completedSessions) {
        [session dismissSession];
    }

}

- (void)removeSessionForUID:(NSString *)uid {

    STMSession *session = (self.sessions)[uid];
    
    if (session.status == STMSessionStopped) {
        
        [self.sessions removeObjectForKey:uid];
        
    } else {

        session.status = STMSessionRemoving;
        [self stopSessionForUID:uid];
        
    }

}


@end
