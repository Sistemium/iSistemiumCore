//
//  STMCoreSession.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession+Private.h"
#import "STMCoreSession+Persistable.h"

@implementation STMCoreSession

@synthesize syncer =_syncer;
@synthesize directoring = _directoring;
@synthesize filing = _filing;


- (instancetype)initWithUID:(NSString *)uid iSisDB:(NSString *)iSisDB accountOrg:(NSString *)accountOrg authDelegate:(id<STMRequestAuthenticatable>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings {
    
    if (!uid) {
        NSLog(@"no uid");
        return nil;
    }
    
    self.uid = uid;
    self.iSisDB = iSisDB;
    self.accountOrg = accountOrg;
    self.status = STMSessionStarting;
    self.startSettings = startSettings;
    self.authDelegate = authDelegate;
    self.startTrackers = trackers;
    self.controllers = [NSMutableDictionary dictionary];
    
    [self addObservers];

    return [self initPersistable];
}

- (void)initController:(Class)controllerClass {
    id <STMCoreControlling> controller = [controllerClass controllerWithPersistenceDelegate:self.persistenceDelegate];
    self.controllers[NSStringFromClass(controllerClass)] = controller;
    controller.session = self;
}

- (id)controllerWithClass:(Class)controllerClass {
    return [self controllerWithName:NSStringFromClass(controllerClass)];
}

- (id)controllerWithName:(NSString *)name {
    return self.controllers[name];
}

- (void)stopSession {
    
    self.status = (self.status == STMSessionRemoving) ? self.status : STMSessionFinishing;

    self.logger.session = nil;
    
    [self removePersistable:^(BOOL success) {
        
        if (!success) {
            NSLog(@"Can not stop session with uid %@", self.uid);
            return;
        }
            
        self.status = (self.status == STMSessionRemoving) ? self.status : STMSessionStopped;
        
        self.settingsController = nil;
        self.trackers = nil;
        self.logger = nil;
        self.syncer = nil;
                
        [self.manager sessionStopped:self];
        
    }];
    
}

- (void)dismissSession {
    
    if (self.status == STMSessionStopped) {
        
        [self removeObservers];
        
        // TODO: move to +Persistable
        if (self.document.documentState != UIDocumentStateClosed) {
            
            [self.document closeWithCompletionHandler:^(BOOL success) {
                
                if (success) {
                    
                    for (STMCoreTracker *tracker in self.trackers.allValues) {
                        [tracker prepareToDestroy];
                    }
                    [self.syncer prepareToDestroy];
                    [self.document.managedObjectContext reset];
                    [self.manager removeSessionForUID:self.uid];
                    
                }
                
            }];
            
        }
        
    }
    
}


- (void)addObservers {
    
    [self observeNotification:UIApplicationDidEnterBackgroundNotification
                     selector:@selector(applicationDidEnterBackground)];
    
}

- (BOOL)isRunningTests {
    return [[[NSProcessInfo processInfo] environment] valueForKey:@"XCTestConfigurationFilePath"] != nil;
}


#pragma mark - properties classes definition (may override in subclasses)

- (Class)settingsControllerClass {
    return [STMCoreSettingsController class];
}

- (Class)locationTrackerClass {
    return [STMCoreLocationTracker class];
}

- (Class)batteryTrackerClass {
    return [STMCoreBatteryTracker class];
}


#pragma mark - handle notifications

- (void)checkTrackersToStart {
    
    if ([self.startTrackers containsObject:@"location"]) {
        
        self.locationTracker = [[[self locationTrackerClass] alloc] init];
        self.trackers[self.locationTracker.group] = self.locationTracker;
        self.locationTracker.session = self;
        
    }
    
    if ([self.startTrackers containsObject:@"battery"]) {
        
        self.batteryTracker = [[[self batteryTrackerClass] alloc] init];
        self.trackers[self.batteryTracker.group] = self.batteryTracker;
        self.batteryTracker.session = self;
        
    }

}


- (void)applicationDidEnterBackground {
    
}

- (void)setAuthDelegate:(id<STMRequestAuthenticatable>)authDelegate {
    
    if (_authDelegate != authDelegate) {
        _authDelegate = authDelegate;
    }
    
}

- (void)setStatus:(STMSessionStatus)status {
    
    if (_status != status) {
        
        _status = status;
        
            NSString *statusString = nil;
        
        switch (_status) {
            case STMSessionIdle: {
                statusString = @"STMSessionIdle";
                break;
            }
            case STMSessionStarting: {
                statusString = @"STMSessionStarting";
                break;
            }
            case STMSessionRunning: {
                statusString = @"STMSessionRunning";
                break;
            }
            case STMSessionFinishing: {
                statusString = @"STMSessionFinishing";
                break;
            }
            case STMSessionStopped: {
                statusString = @"STMSessionStopped";
                break;
            }
            case STMSessionRemoving: {
                statusString = @"STMSessionRemoving";
                break;
            }
        }
        
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SESSION_STATUS_CHANGED
                                                            object:self];
        
        NSString *logMessage = [NSString stringWithFormat:@"Session #%@ status changed to %@", self.uid, statusString];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage];

	}
    
}


@end
