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
    return (STMCoreSession *) self.sessions[self.currentSessionUID];
}

- (void)setCurrentSessionUID:(NSString *)currentSessionUID {

    if (!currentSessionUID || self.sessions[currentSessionUID]) {

        if (_currentSessionUID != currentSessionUID) {

            _currentSessionUID = currentSessionUID;

// this notification is never observe
//            [[NSNotificationCenter defaultCenter] postNotificationName:@"currentSessionChanged"
//                                                                object:currentSessionUID ? self.sessions[currentSessionUID] : nil];

        }

    }

}

- (id <STMSession>)startSessionWithAuthDelegate:(id <STMCoreAuth>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings defaultSettingsFileName:(NSString *)defualtSettingsFileName {

    NSString *uid = authDelegate.userID;

    if (!uid) {
        NSLog(@"no uid");
        return nil;
    }

    STMCoreSession *session = self.sessions[uid];

    if (session) {
        // TODO: it's not good but the deleted code was even worse
        [session stopSession];
        [session dismissSession];
    }

    NSDictionary *validSettings = [STMSettingsData settingsFromFileName:defualtSettingsFileName
                                                         withSchemaName:@"settings_schema"];

    session = [[[self sessionClass] alloc] init];
    session.defaultSettings = validSettings[@"values"];
    session.settingsControls = validSettings[@"controls"];
    session.manager = self;

    session = [session initWithAuthDelegate:authDelegate
                                   trackers:trackers
                              startSettings:startSettings];

    self.sessions[uid] = session;

    self.currentSessionUID = uid;

    return session;

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

    if (session.status == STMSessionRemoving || session.status == STMSessionFinishing || session.status == STMSessionStopped) {

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

        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_REMOVED
                                                            object:self
                                                          userInfo:@{@"uid": uid}];

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
