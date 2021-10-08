//
//  STMCoreSession.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession+Private.h"
#import "STMCoreSession+Persistable.h"
#import "STMCoreSessionFiler.h"
#import "STMCoreObjectsController.h"
#import "STMCoreAuthController.h"

#define STM_MODEL_REQUEST_TIMEOUT 3;

@implementation STMCoreSession

NSString *const STM_MODELS_URL = @"https://api.sistemium.com/models/%@.mom";

@synthesize syncer = _syncer;
@synthesize filing = _filing;

NSTimer *flushTimer;

- (instancetype)initWithAuthDelegate:(id <STMCoreAuth>)authDelegate trackers:(NSArray *)trackers startSettings:(NSDictionary *)startSettings {

    NSString *uid = authDelegate.userID;

    if (!uid) {
        NSLog(@"no uid");
        return nil;
    }

    self.uid = uid;
    self.status = STMSessionStarting;
    self.startSettings = startSettings;
    self.authDelegate = authDelegate;
    self.startTrackers = trackers;
    self.controllers = [NSMutableDictionary dictionary];

    STMCoreSessionFiler *filer = [[STMCoreSessionFiler alloc] initWithOrg:authDelegate.accountOrg userId:STMIsNull(authDelegate.iSisDB, uid)];
    
    self.filing = filer;

    [self addObservers];
    
    [self downloadModel]
        .then(^(NSString *modelPath) {

            if (!modelPath) {
                return [AnyPromise promiseWithValue:[STMFunctions errorWithMessage:@"Empty model file"]];
            }

            NSLog(@"Model file success: %@", modelPath);
            return [AnyPromise promiseWithValue:[self initPersistableWithModelPath:modelPath]];

        })
        .catch(^(NSError *error) {
            NSLog(@"Error downloading model: %@", error);

            NSString *message = error.localizedDescription;

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{

                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ERROR", nil) message:message delegate:STMCoreAuthController.sharedAuthController cancelButtonTitle:@"OK" otherButtonTitles:nil];
                alertView.tag = 1;
                [alertView show];

            }];

        });

    return self;
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

    if (self.status != STMSessionStopped) return;

    [self removeObservers];

    // TODO: move to +Persistable
    if (self.document.documentState == UIDocumentStateClosed) return;

    [self.document closeWithCompletionHandler:^(BOOL success) {

        if (!success) return;

        for (STMCoreTracker *tracker in self.trackers.allValues) {
            [tracker prepareToDestroy];
        }

        [self.syncer prepareToDestroy];
        [self.document.managedObjectContext reset];
        [self.manager removeSessionForUID:self.uid];

    }];

}


- (void)addObservers {

    [self observeNotification:UIApplicationDidEnterBackgroundNotification
                     selector:@selector(applicationDidEnterBackground)];
    
    [self observeNotification:UIApplicationWillEnterForegroundNotification
                     selector:@selector(applicationWillEnterForeground)];

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
    
    [STMCoreObjectsController checkObjectsForFlushing];
    
    flushTimer = [NSTimer scheduledTimerWithTimeInterval:90.0
                                                  target:[STMCoreObjectsController class]
                                                selector:@selector(checkObjectsForFlushing)
                                                userInfo:nil
                                                 repeats:YES];
    
}

- (void)applicationWillEnterForeground {
    
    [flushTimer invalidate];
    flushTimer = nil;
    
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

//- (void)checkModelToDownload {
//    [[NSURLSession sessionWithConfiguration:(nonnull NSURLSessionConfiguration *)] dow
//}

- (NSString *)currentAppVersion {
    
    NSString *displayName = BUNDLE_DISPLAY_NAME;
    NSString *appVersionString = APP_VERSION;
    NSString *modelVersion = self.persistenceDelegate.modelVersion;
    
    NSString *result = [NSString stringWithFormat:@"%@ %@ (%@)", displayName, appVersionString, modelVersion];

    return result;
    
}

- (NSURL *)modelURL {
    
    NSString *dataModelName = self.startSettings[@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController sharedAuthController] dataModelName];
    }
    
    NSString *modelsRole = [STMCoreAuthController sharedAuthController].rolesResponse[@"roles"][@"models"];
   
    NSString *modelName = dataModelName.mutableCopy;
    
    if (modelsRole) {
        modelName = [NSString stringWithFormat:@"%@/%@", modelsRole, modelName];
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:STM_MODELS_URL, modelName]];
    
    NSLog(@"Model URI: %@", url);

    return url;

}

- (AnyPromise *)downloadModel {
    
    if ([[STMCoreAuthController sharedAuthController].rolesResponse[@"roles"][@"org"] isEqual:@"DEMO ORG"]){
        NSString *model = [STMCoreAuthController sharedAuthController].rolesResponse[@"roles"][@"models"];
        NSString *bundledModelFile = [self.filing bundledModelFile:model];
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
            resolve(bundledModelFile);
        }];
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self modelURL]];
    
    NSString *modelPath = [self.filing persistencePath:@"model"];
    NSString *etagPath = [modelPath stringByAppendingPathComponent:@"etag"];
    NSString *momPath = [modelPath stringByAppendingPathComponent:@"mom"];
    
    NSData *etagData = [self.filing fileAtPath:etagPath];
    
    Boolean modelExists = [self.filing fileExistsAtPath:momPath];
    
    if (etagData && [self.filing fileExistsAtPath:momPath]) {
        NSString *etag = [[NSString alloc] initWithData:etagData encoding:NSASCIIStringEncoding];
        [req setValue:etag forHTTPHeaderField:@"if-none-match"];
        req.timeoutInterval = STM_MODEL_REQUEST_TIMEOUT;
        NSLog(@"Model request with etag: %@", etag);
    }

    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:req completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            
            if (error) {
                NSLog(@"Error downloading: %@", error.description);
                resolve(error);
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            
            if (httpResponse.statusCode == 304) {
                NSLog(@"Not modified model");
                resolve(momPath);
                return;
            }
            
            if (httpResponse.statusCode != 200) {
                NSString *otherError = [NSString stringWithFormat:@"Error downloading model: %li", (long)httpResponse.statusCode];
                resolve([STMFunctions errorWithMessage:otherError]);
                return;
            }
            
            NSString *gotEtag = httpResponse.allHeaderFields[@"etag"];
            
            NSLog(@"Model response status %u %@", httpResponse.statusCode, gotEtag);
            
            if (gotEtag) {
                [gotEtag writeToFile:etagPath atomically:YES encoding:NSASCIIStringEncoding error:&error];
                if (error) {
                    NSLog(@"Error saving etag: %@", error.description);
                    resolve(error);
                    return;
                }
                NSLog(@"Model etag saved");
            }
            
            [self.filing copyItemAtPath:location.path
                                 toPath:momPath
                                  error:&error];
            if (error) {
                NSLog(@"Error copying: %@", error.description);
                resolve(error);
                return;
            }
            
            NSLog(@"Model download complete %@", location.path);
            
            resolve(momPath);
            
        }];
        
        [task resume];
    
    }]
    .catch(^(NSError *error) {
        if (modelExists) {
            NSLog(@"Use cached model after: %@", error.localizedDescription);
            return [AnyPromise promiseWithValue:momPath];
        }
        return [AnyPromise promiseWithValue:error];;
    });
    
}


@end
