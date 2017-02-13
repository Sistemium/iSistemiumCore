//
//  STMCoreSessionManager.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreSessionManager.h"
#import "STMSettingsData.h"

#define SETTINGS_SCHEMA @"settings_schema"

@implementation STMCoreSessionManager

+ (instancetype)sharedManager {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedManager = nil;
    
    dispatch_once(&pred, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
    
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
    }
    return self;
    
}

- (NSMutableDictionary <NSString *, STMCoreSession *> *)sessions {
    
    if (!_sessions) {
        _sessions = [NSMutableDictionary dictionary];
    }
    return _sessions;
    
}

- (STMCoreSession *)currentSession {
    return (STMCoreSession *)self.sessions[self.currentSessionUID];
}

- (void)setCurrentSessionUID:(NSString *)currentSessionUID {
    
    if ([[self.sessions allKeys] containsObject:currentSessionUID] || !currentSessionUID) {
        
        if (_currentSessionUID != currentSessionUID) {
            
            _currentSessionUID = currentSessionUID;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"currentSessionChanged"
                                                                object:(self.sessions)[_currentSessionUID]];
            
        }
        
    }
    
}

- (id <STMSession>)startSessionForUID:(NSString *)uid iSisDB:(NSString *)iSisDB authDelegate:(id<STMRequestAuthenticatable>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings defaultSettingsFileName:(NSString *)defualtSettingsFileName {
    
    if (uid) {
        
        STMCoreSession *session = (self.sessions)[uid];
        
        if (!session) {
            
            NSDictionary *validSettings = [STMSettingsData settingsFromFileName:defualtSettingsFileName withSchemaName:@"settings_schema"];
            
            session = [[self sessionClass] initWithUID:uid
                                                iSisDB:(NSString *)iSisDB
                                          authDelegate:authDelegate
                                              trackers:trackers
                                         startSettings:startSettings];
            
            session.defaultSettings = validSettings[@"values"];
            session.settingsControls = validSettings[@"controls"];
            session.manager = self;

            self.sessions[uid] = session;

            self.currentSessionUID = uid;

        } else {

            self.currentSessionUID = uid;

            session.authDelegate = authDelegate;
            session.status = STMSessionRunning;
            session.logger.session = session;
            session.settingsController.startSettings = startSettings.mutableCopy;
            session.settingsController.session = session;
            
            if (session.document) {
                
                if (session.document.documentState == UIDocumentStateClosed) {
                    [STMDocument openDocument:session.document];
                }
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"session %@ have no document", session.uid];
                
                [session.logger saveLogMessageWithText:logMessage
                                               numType:STMLogMessageTypeError];
                
            }

        }
        return session;
        
    } else {
        
        NSLog(@"no uid");
        return nil;
        
    }

}

- (Class)sessionClass {
    return [STMCoreSession class];
}

- (void)stopSessionForUID:(NSString *)uid {
    
    STMCoreSession *session = (self.sessions)[uid];
    
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
        [self removeSessionForUID:session.uid];
    }
    
}

- (void)cleanStoppedSessions {

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.status == %@", @"stopped"];
    NSArray *completedSessions = [[self.sessions allValues] filteredArrayUsingPredicate:predicate];
    
    for (STMCoreSession *session in completedSessions) {
        [session dismissSession];
    }

}

- (void)removeSessionForUID:(NSString *)uid {

    STMCoreSession *session = (self.sessions)[uid];
    
    if (session.status == STMSessionStopped) {
        
        [session dismissSession];
        [self.sessions removeObjectForKey:uid];
        
    } else {

        session.status = STMSessionRemoving;
        [self stopSessionForUID:uid];
        
    }

}

- (void)applicationWillTerminate {
    
    [self cleanStoppedSessions];
    [self removeSessionForUID:self.currentSessionUID];
    
}


@end
