//
//  STMCoreSession.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession.h"

#import "STMSyncerHelper.h"
#import "STMUnsyncedDataHelper.h"

#import "STMCoreSession+Persistable.h"
#import "STMSyncerHelper+Defantomizing.h"
#import "STMSyncerHelper+Downloading.h"


@interface STMCoreSession()


@end

@implementation STMCoreSession

+ (instancetype)initWithUID:(NSString *)uid iSisDB:(NSString *)iSisDB authDelegate:(id<STMRequestAuthenticatable>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings {
    
    if (uid) {
        
        STMCoreSession *session = [[self alloc] init];
        session.uid = uid;
        session.iSisDB = iSisDB;
        session.status = STMSessionStarting;
        session.startSettings = startSettings;
        session.authDelegate = authDelegate;
        session.startTrackers = trackers;
        
        [session addObservers];
        
        return [session initPersistable];
        
    } else {
        
        NSLog(@"no uid");
        return nil;
        
    }

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

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(settingsLoadComplete:)
               name:@"settingsLoadComplete"
             object:self.settingsController];
    
    [nc addObserver:self
           selector:@selector(applicationDidEnterBackground)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    
}

- (void)removeObservers {

    [[NSNotificationCenter defaultCenter] removeObserver:self];

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
        
    }
    
    if ([self.startTrackers containsObject:@"battery"]) {
        
        self.batteryTracker = [[[self batteryTrackerClass] alloc] init];
        self.trackers[self.batteryTracker.group] = self.batteryTracker;
        
    }

}

- (void)settingsLoadComplete:(NSNotification *)notification {
    
    if (notification.object == self.settingsController) {
    
        //    NSLog(@"currentSettings %@", [self.settingsController currentSettings]);
        self.locationTracker.session = self;
        self.batteryTracker.session = self;
        self.status = STMSessionRunning;

        STMSyncerHelper *syncerHelper = [[STMSyncerHelper alloc] init];
        syncerHelper.persistenceDelegate = self.persistenceDelegate;
        syncerHelper.dataDownloadingOwner = self.syncer;
        self.syncer.dataDownloadingDelegate = syncerHelper;
        self.syncer.defantomizingDelegate = syncerHelper;
        
        STMUnsyncedDataHelper *unsyncedHelper = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persistenceDelegate
                                                                                              subscriber:self.syncer];
        self.syncer.dataSyncingDelegate = unsyncedHelper;
        
        self.syncer.persistenceDelegate = self.persistenceDelegate;
        self.syncer.session = self;

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


#pragma mark - used classes

- (Class)locationClass {
    return [STMCoreLocation class];
}



@end
