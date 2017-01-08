//
//  STMCoreSession.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession.h"

#import "STMCoreDataModel.h"
#import "STMCoreAuthController.h"


@interface STMCoreSession()

@property (nonatomic, strong) NSDictionary *startSettings;

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

        NSString *dataModelName = [startSettings valueForKey:@"dataModelName"];
        
        if (!dataModelName) {
            dataModelName = [[STMCoreAuthController authController] dataModelName];
        }

        STMDocument *document = [STMDocument documentWithUID:session.uid
                                                      iSisDB:session.iSisDB
                                               dataModelName:dataModelName
                                                      prefix:prefix];
        
        session.persister = [STMPersister initWithDocument:document
                                                forSession:session];
        
        session.document = document;

        return session;
        
    } else {
        
        NSLog(@"no uid");
        return nil;
        
    }

}

- (void)stopSession {
    
    self.status = (self.status == STMSessionRemoving) ? self.status : STMSessionFinishing;

    self.logger.session = nil;
    
    if (self.document.documentState == UIDocumentStateNormal) {
        
        [self.document saveDocument:^(BOOL success) {
            
            if (success) {
                
                self.status = (self.status == STMSessionRemoving) ? self.status : STMSessionStopped;
                
                if (self.status == STMSessionRemoving) {

                    self.document = nil;
                    self.persister = nil;

                }
                
                [self.manager sessionStopped:self];
                
            } else {
                
                NSLog(@"Can not stop session with uid %@", self.uid);
                
            }
            
        }];
        
    }
    
}

- (void)dismissSession {
    
    if (self.status == STMSessionStopped) {
        
        [self removeObservers];
        
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

- (void)persisterCompleteInitializationWithSuccess:(BOOL)success {
    
    if (success) {
        
        [[STMLogger sharedLogger] saveLogMessageWithText:@"document ready"];
        
        self.settingsController = [[self settingsControllerClass] initWithSettings:self.startSettings];
        self.trackers = [NSMutableDictionary dictionary];
        self.syncer = [[STMSyncer alloc] init];
        
        [self checkTrackersToStart];
        
        self.logger = [STMLogger sharedLogger];
        self.logger.session = self;
        self.settingsController.session = self;

    } else {
        
        NSLog(@"persister is not ready, have to do something with it");

    }
    
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
        self.syncer.authDelegate = self.authDelegate;
        self.syncer.session = self;
        self.status = STMSessionRunning;

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
