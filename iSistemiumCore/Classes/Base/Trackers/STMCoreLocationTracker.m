//
//  STMCoreLocationTracker.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 4/3/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import "STMCoreLocationTracker.h"
#import "STMEntityDescription.h"

#import "STMClientDataController.h"
#import "STMCoreObjectsController.h"
#import "STMLocationController.h"
#import "STMCoreSession.h"
#import "STMSocketTransport.h"


#define ACTUAL_LOCATION_CHECK_TIME_INTERVAL 5.0


// TODO: it seems this class use almost none of the parent class methods after implemetation of new "desiredAccuracy zero-rule"


@interface STMCoreLocationTracker() <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocationManager *requestManager;

@property (nonatomic) CLLocationAccuracy desiredAccuracy;
@property (nonatomic) CLLocationAccuracy foregroundDesiredAccuracy;
@property (nonatomic) CLLocationAccuracy backgroundDesiredAccuracy;
@property (nonatomic) CLLocationAccuracy offtimeDesiredAccuracy;

@property (nonatomic) CLLocationAccuracy checkinAccuracy;

@property (nonatomic) double requiredAccuracy;
@property (nonatomic) CLLocationDistance distanceFilter;
@property (nonatomic) NSTimeInterval timeFilter;
@property (nonatomic) NSTimeInterval locationWaitingTimeInterval;

@property (nonatomic) NSTimeInterval trackDetectionTime;
@property (nonatomic) CLLocationDistance trackSeparationDistance;
@property (nonatomic) CLLocationSpeed maxSpeedThreshold;

@property (nonatomic) BOOL singlePointMode;
@property (nonatomic) BOOL checkinMode;
@property (nonatomic) BOOL getLocationsWithNegativeSpeed;
@property (nonatomic, strong) NSTimer *locationWaitingTimer;

@property (nonatomic, strong) CLLocation *bestCheckinLocation;

@property (nonatomic, strong) NSTimer *startTimer;
@property (nonatomic, strong) NSTimer *finishTimer;

@property (nonatomic, strong) NSString *requestLocationServiceAuthorization;
@property (nonatomic, strong) NSMutableArray *checkinRequests;


@end


@implementation STMCoreLocationTracker

@synthesize lastLocation = _lastLocation;

- (NSString *)locationConcreteName {
    
    STMCoreSession *currentSession = self.session;
    return NSStringFromClass([currentSession locationClass]);
    
}

- (id <STMPersistingAsync, STMModelling>)persistenceDelegate {
    return [self.session persistenceDelegate];
}

- (void)customInit {
    
    self.group = @"location";
    
    [super customInit];
    
    [self initAppStateObservers];
    [self shipmentRoutesObservers];
    
}

- (void)initAppStateObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    SEL selector = @selector(appStateDidChange);
    
    [nc addObserver:self
           selector:selector
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

    [nc addObserver:self
           selector:selector
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(appSettingsChanged:)
               name:@"appSettingsSettingsChanged"
             object:self.session];
    
}

- (void)shipmentRoutesObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(shipmentRouteProcessingChanged)
               name:@"shipmentRouteProcessingChanged"
             object:nil];
    
}

- (void)shipmentRouteProcessingChanged {
    [self checkTrackerAutoStart];
}

- (void)appStateDidChange {
    [self checkTrackerAutoStart];
}

- (void)appSettingsChanged:(NSNotification *)notification {

    if ([[notification.userInfo allKeys] containsObject:@"requestLocationServiceAuthorization"]) {
        
        self.requestLocationServiceAuthorization = nil;
        
        [self checkTrackerAutoStart];
        
    }

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if ([change valueForKey:NSKeyValueChangeNewKey] != [change valueForKey:NSKeyValueChangeOldKey]) {
        
        if ([keyPath isEqualToString:@"distanceFilter"] ||
            [keyPath isEqualToString:@"desiredAccuracy"] ||
            [keyPath hasSuffix:@"DesiredAccuracy"]) {
            
            [self updateDesiredAccuracy];
            self.locationManager.distanceFilter = self.distanceFilter;
            [self checkTrackerAutoStart];
            
        }
        
    }
    
}

- (void)updateDesiredAccuracy {

    CLLocationAccuracy currentAccuracy = [self currentDesiredAccuracy];
    
    if (self.locationManager.desiredAccuracy != currentAccuracy) {
        
        self.locationManager.desiredAccuracy = currentAccuracy;

        NSString *logMessage = [NSString stringWithFormat:@"change desired accuracy to %f", currentAccuracy];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];
        
    }
    
}


#pragma mark - locationTracker settings

- (NSString *)requestLocationServiceAuthorization {
    
    if (!_requestLocationServiceAuthorization) {
        
        NSDictionary *appSettings = [[self.session settingsController] currentSettingsForGroup:@"appSettings"];
        NSString *requestLocationServiceAuthorization = [appSettings valueForKey:@"requestLocationServiceAuthorization"];

        _requestLocationServiceAuthorization = requestLocationServiceAuthorization;
        
    }
    return _requestLocationServiceAuthorization;

}

- (CLLocationAccuracy)currentDesiredAccuracy {
    
    if ([self.geotrackerControl isEqualToString:GEOTRACKER_CONTROL_SHIPMENT_ROUTE] || [self currentTimeIsInsideOfScheduleLimits]) {
        
        UIApplicationState appState = [UIApplication sharedApplication].applicationState;
        
        switch (appState) {
            case UIApplicationStateActive: {
                return self.foregroundDesiredAccuracy;
                break;
            }
            case UIApplicationStateInactive: {
                return self.foregroundDesiredAccuracy;
                break;
            }
            case UIApplicationStateBackground: {
                return self.backgroundDesiredAccuracy;
                break;
            }
            default: {
                return self.desiredAccuracy;
                break;
            }
        }
        
    } else {
        
        return self.offtimeDesiredAccuracy;
        
    }

}

- (CLLocationAccuracy)desiredAccuracy {
    return [self.settings[@"desiredAccuracy"] doubleValue];
}

- (CLLocationAccuracy)backgroundDesiredAccuracy {
    return (self.settings[@"backgroundDesiredAccuracy"]) ? [self.settings[@"backgroundDesiredAccuracy"] doubleValue] : self.desiredAccuracy;
}

- (CLLocationAccuracy)foregroundDesiredAccuracy {
    return (self.settings[@"foregroundDesiredAccuracy"]) ? [self.settings[@"foregroundDesiredAccuracy"] doubleValue] : self.desiredAccuracy;
}

- (CLLocationAccuracy)offtimeDesiredAccuracy {
    return (self.settings[@"offtimeDesiredAccuracy"]) ? [self.settings[@"offtimeDesiredAccuracy"] doubleValue] : self.desiredAccuracy;
}

- (double)requiredAccuracy {
    return [self.settings[@"requiredAccuracy"] doubleValue];
}

- (CLLocationDistance)distanceFilter {
    return [self.settings[@"distanceFilter"] doubleValue];
}

- (NSTimeInterval)timeFilter {
    return [self.settings[@"timeFilter"] doubleValue];
}

- (NSTimeInterval)locationWaitingTimeInterval {
    return [self.settings[@"locationWaitingTimeInterval"] doubleValue];
}

- (NSTimeInterval)trackDetectionTime {
    return [self.settings[@"trackDetectionTime"] doubleValue];
}

- (CLLocationDistance)trackSeparationDistance {
    return [self.settings[@"trackSeparationDistance"] doubleValue];
}

- (CLLocationSpeed)maxSpeedThreshold {
    return [self.settings[@"maxSpeedThreshold"] doubleValue];
}

- (BOOL)getLocationsWithNegativeSpeed {
    return [self.settings[@"getLocationsWithNegativeSpeed"] boolValue];
}

- (NSString *)geotrackerControl {
    return self.settings[@"geotrackerControl"];
}

- (STMCoreLocation *)lastLocationObject {
    
    if (!_lastLocationObject) {
        
        NSError *error;
        NSDictionary *options = @{
            STMPersistingOptionOrder: @"timestamp",
            STMPersistingOptionOrderDirectionDesc,
            STMPersistingOptionPageSize: @"1"
        };
        
        NSDictionary *location = [[self.session.persistenceDelegate findAllSync:self.locationConcreteName predicate:nil options:options error:&error] lastObject];
        
        if (location) {
            _lastLocationObject = (STMCoreLocation *)[self.session.persistenceDelegate newObjectForEntityName:@"STMCoreLocation"];
            
            [self.session.persistenceDelegate setObjectData:location toObject:_lastLocationObject];
        }

    }
    return _lastLocationObject;
    
}

- (CLLocation *)lastLocation {
    
    if (!_lastLocation) {
        
        if (self.lastLocationObject) {
            
            _lastLocation = [STMLocationController locationFromLocationObject:self.lastLocationObject];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"lastLocationUpdated" object:self];

        }

    }
    return _lastLocation;
    
}

- (void)setLastLocation:(CLLocation *)lastLocation {
    
    _lastLocation = lastLocation;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"lastLocationUpdated" object:self];
    
}

- (void)setCurrentAccuracy:(CLLocationAccuracy)currentAccuracy {
    
    if (_currentAccuracy != currentAccuracy) {
        
        _currentAccuracy = currentAccuracy;
        
        NSDictionary *userInfo = @{@"isAccuracySufficient":@(self.isAccuracySufficient)};
        
        [self postAsyncMainQueueNotification:@"currentAccuracyUpdated" userInfo:userInfo];

    }
    
}

- (BOOL)isAccuracySufficient {
    return (self.currentAccuracy <= self.requiredAccuracy);
}

- (NSString *)locationServiceStatus {
    
    NSString *status = nil;
    
    if ([CLLocationManager locationServicesEnabled]) {
        
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusNotDetermined:
                status = @"notDetermined";
                break;
            case kCLAuthorizationStatusRestricted:
                status = @"restricted";
                break;
            case kCLAuthorizationStatusDenied:
                status = @"denied";
                break;
            case kCLAuthorizationStatusAuthorizedAlways:
                status = @"authorizedAlways";
                break;
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                status = @"authorizedWhenInUse";
                break;
                
            default:
                break;
        }
        
    } else {
        
        status = @"disabled";
        
    }
    
//    NSLog(@"locationServiceStatus %@", status);
    
    return status;
    
}

- (NSMutableArray *)checkinRequests {
    
    if (!_checkinRequests) {
        _checkinRequests = @[].mutableCopy;
    }
    return _checkinRequests;
    
}


#pragma mark - tracking

- (void)startTracking {

    [super startTracking];
    
    if (self.tracking) {
        [self checkStatus];
    }

}

- (void)checkStatus {
    
    float systemVersion = SYSTEM_VERSION;
    
    if (systemVersion >= 8.0) {
        
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

        if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
            
            NSString *errorString = @"location tracking is not permitted";
            [[self.session logger] infoMessage:errorString];
            [self checkinLocationError:errorString];
            
            self.locationManager = nil;
            [super stopTracking];
            
        } else if (status == kCLAuthorizationStatusNotDetermined) {
            
            [super stopTracking];
            [self requestAuthorization:^(BOOL success) {
                if (success) [self startUpdatingLocation];
            }];
            
        } else {
            
            if ([CLLocationManager locationServicesEnabled]) {
                
                [self startUpdatingLocation];
                
            } else {
                
                NSString *errorString = @"location tracking disabled";
                [[self.session logger] infoMessage:errorString];
                [self checkinLocationError:errorString];
                
                [super stopTracking];
                
            }
            
        }
        
    } else if (systemVersion >= 2.0 && systemVersion < 8.0) {
        
        [self startUpdatingLocation];
        
    }

}

- (void)requestAuthorization:(void (^)(BOOL success))completionHandler {

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        
        [[self.session logger] saveLogMessageWithText:@"location tracking is not permitted"
                                              numType:STMLogMessageTypeError];
        
        completionHandler(NO);
        
    } else if (status == kCLAuthorizationStatusNotDetermined) {
        
        float systemVersion = SYSTEM_VERSION;

        if (systemVersion >= 8.0) {

            if ([self.requestLocationServiceAuthorization isEqualToString:@"requestWhenInUseAuthorization"]) {

//                [self.requestManager requestWhenInUseAuthorization];

            } else if ([self.requestLocationServiceAuthorization isEqualToString:@"requestAlwaysAuthorization"]) {

//                [self.requestManager requestAlwaysAuthorization];

            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"requestLocationServiceAuthorization wrong value: %@", self.requestLocationServiceAuthorization];
                [[self.session logger] saveLogMessageWithText:logMessage
                                                      numType:STMLogMessageTypeError];
                
            }
            
        } else if (systemVersion >= 2.0 && systemVersion < 8.0) {
            
            [self.requestManager startUpdatingLocation];
            
        }
        
        completionHandler(NO);

    } else {

        completionHandler(YES);
        
    }

}

- (void)stopTracking {
    
    [self flushLocationManager];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"locationManagerDidPauseLocationUpdates" object:self];
    [super stopTracking];
    
}

- (void)flushLocationManager {
    
    [self resetLocationWaitingTimer];
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    self.locationManager = nil;
    
}

- (void)getLocation {
    
    CLLocation *lastLocation = self.locationManager.location;
    NSTimeInterval locationAge = -[lastLocation.timestamp timeIntervalSinceNow];

    if (lastLocation &&
        self.tracking &&
        locationAge < ACTUAL_LOCATION_CHECK_TIME_INTERVAL) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"currentLocationWasUpdated"
                                                            object:self
                                                          userInfo:@{@"currentLocation":lastLocation}];
        
    } else {
        
        [self checkStatus];
        self.singlePointMode = YES;
        
    }
    
}

- (void)checkinWithAccuracy:(NSNumber *)checkinAccuracy checkinData:(NSDictionary *)checkinData requestId:(NSNumber *)requestId timeout:(NSTimeInterval)timeout delegate:(id <STMCheckinDelegate>)delegate {
    
    if (!delegate || !requestId) return;
    if (!checkinData) checkinData = @{};
    if (!timeout) timeout = 20;
    timeout = (timeout >= 1) ? timeout - 1 : 0;
    
    [self performSelector:@selector(checkinTimeout)
               withObject:nil
               afterDelay:timeout];
    
    self.checkinAccuracy = checkinAccuracy.doubleValue;
    
    NSDictionary *checkinRequest = @{@"delegate"    : delegate,
                                     @"checkinData" : checkinData,
                                     @"requestId"   : requestId};
    
    if (![self.checkinRequests containsObject:checkinRequest]) [self.checkinRequests addObject:checkinRequest];

    CLLocation *lastLocation = self.locationManager.location;
    NSTimeInterval locationAge = -[lastLocation.timestamp timeIntervalSinceNow];
    
    if (lastLocation &&
        (self.tracking || locationAge < ACTUAL_LOCATION_CHECK_TIME_INTERVAL) &&
        lastLocation.horizontalAccuracy <= self.checkinAccuracy && [self checkNANValues:lastLocation]) {

        NSString *logMessage = @"have recent location for checkin";
        [[self.session logger] saveLogMessageWithText:logMessage
                                              numType:STMLogMessageTypeImportant];
        
        self.checkinMode = YES;
        [self receiveCheckinLocation:lastLocation];
        
    } else {
        
        NSString *logMessage = @"location tracker checkin mode, set distance filter to none, desired accuracy to best for navigation";
        [[self.session logger] saveLogMessageWithText:logMessage
                                              numType:STMLogMessageTypeImportant];
        
        [self checkStatus];
        
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        
        self.checkinMode = YES;

    }

}

- (void)startUpdatingLocation {
    
    [self.locationManager startUpdatingLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"locationManagerDidResumeLocationUpdates"
                                                        object:self];

}


#pragma mark - CLLocationManager

- (CLLocationManager *)locationManager {
    
    if (!_locationManager) {
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = self.distanceFilter;
        _locationManager.desiredAccuracy = [self currentDesiredAccuracy];
        _locationManager.pausesLocationUpdatesAutomatically = NO;
        
        if ([_locationManager respondsToSelector:@selector(allowsBackgroundLocationUpdates)]) {
            
//            _locationManager.allowsBackgroundLocationUpdates = YES;
            NSLog(@"locationManager allowsBackgroundLocationUpdates set");
            
        }

        NSString *logMessage = [NSString stringWithFormat:@"set desired accuracy to %f", _locationManager.desiredAccuracy];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];
        
    }
    
    return _locationManager;
    
}

- (CLLocationManager *)requestManager {
    
    if (!_requestManager) {

        _requestManager = [[CLLocationManager alloc] init];
        _requestManager.delegate = self;

    }
    return _requestManager;
    
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
    
    [self.session.logger saveLogMessageWithText:@"locationManagerDidResumeLocationUpdates"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"locationManagerDidResumeLocationUpdates"
                                                        object:self];
    
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager {
    
    [self.session.logger saveLogMessageWithText:@"locationManagerDidPauseLocationUpdates"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"locationManagerDidPauseLocationUpdates"
                                                        object:self];
    
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    if ([manager isEqual:self.requestManager]) {
        
        if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) [self checkTrackerAutoStart];
        
    } else {
        
        [STMClientDataController checkClientData];
        
        if ((status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) && self.tracking) {
            
            if ([CLLocationManager locationServicesEnabled]) {
                [self startUpdatingLocation];
            } else {
                [[self.session logger] saveLogMessageWithText:@"location tracking disabled" numType:STMLogMessageTypeError];
                [super stopTracking];
            }
            
        }
        
    }
    
    switch (status) {
        case kCLAuthorizationStatusNotDetermined: {
            break;
        }
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied: {
            [self checkinLocationError:@"location tracking is not permitted"];
            break;
        }
        case kCLAuthorizationStatusAuthorizedAlways: {
            break;
        }
        case kCLAuthorizationStatusAuthorizedWhenInUse: {
            break;
        }
    }

}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    if ([manager isEqual:self.requestManager]) {
        
        [self.requestManager stopUpdatingLocation];
        return;
        
    }
    
    CLLocation *newLocation = [locations lastObject];
    
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    
    CLLocationAccuracy previousAccuracy = self.currentAccuracy;
    self.currentAccuracy = newLocation.horizontalAccuracy;
    
    if (locationAge < ACTUAL_LOCATION_CHECK_TIME_INTERVAL && self.currentAccuracy > 0 && [self checkNANValues:newLocation]) {

        BOOL shouldSaveLocation = [self.geotrackerControl isEqualToString:GEOTRACKER_CONTROL_SHIPMENT_ROUTE] || [self currentTimeIsInsideOfScheduleLimits];
        
        if ([self isAccuracySufficient] && shouldSaveLocation) {
            
            if (!self.getLocationsWithNegativeSpeed && newLocation.speed < 0) {
                
                [self.session.logger saveLogMessageWithText:@"location w/negative speed recieved"];
                
            } else {
                
                NSTimeInterval time = [newLocation.timestamp timeIntervalSinceDate:self.lastLocation.timestamp];
                
                if (!self.lastLocation || time > self.timeFilter || self.currentAccuracy < previousAccuracy) {
                    
                    if (self.tracking) {
                        [self addLocation:newLocation];
                    }
                    
                }
                
            }

        }
        
        if (self.singlePointMode) {
            [self handleSinglePointModeLocation:newLocation];
        }
        
        if (self.checkinMode) {
            [self handleCheckinModeLocation:newLocation];
        }
        
    }
    
}


#pragma mark - handle tracker SinglePointMode

- (void)handleSinglePointModeLocation:(CLLocation *)location {
    
    self.singlePointMode = NO;
            
	if (!self.tracking) {
		[self flushLocationManager];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"currentLocationWasUpdated"
														object:self
											  userInfo:@{@"currentLocation":location}];
	
}


#pragma mark - handle tracker CheckinMode

- (void)handleCheckinModeLocation:(CLLocation *)location {
    
    if (location.horizontalAccuracy <= self.checkinAccuracy && [self checkNANValues:location]) {
        
        [self receiveCheckinLocation:location];

        if (!self.tracking) {
            
            [self flushLocationManager];
            
        } else {
            
            NSLog(@"end of location tracker checkin mode");
            NSLog(@"get checkin location: %@", location);
            NSLog(@"set location manager desired accuracy and distance filter to previous values: %@, %@", @([self currentDesiredAccuracy]), @(self.distanceFilter));

            self.locationManager.desiredAccuracy = [self currentDesiredAccuracy];
            self.locationManager.distanceFilter = self.distanceFilter;
            
	    }
        
    } else {
        
        if ((!self.bestCheckinLocation || location.horizontalAccuracy <= self.bestCheckinLocation.horizontalAccuracy)
                                          && [self checkNANValues:location]) {
            self.bestCheckinLocation = location;
        }
        
    }
    
}

- (void)checkinTimeout {
    
    if (self.bestCheckinLocation) {
        [self receiveCheckinLocation:self.bestCheckinLocation];
    } else {
        [self checkinLocationError:NSLocalizedString(@"HAVE NO CHECKIN LOCATION", nil)];
    }
    
}

- (void)receiveCheckinLocation:(CLLocation *)checkinLocation {
    
    if (!self.checkinMode) return;
    
    if (!checkinLocation) {
        
        [self checkinLocationError:NSLocalizedString(@"HAVE NO CHECKIN LOCATION", nil)];
        return;
        
    }
    
    [STMCoreLocationTracker cancelPreviousPerformRequestsWithTarget:self
                                                           selector:@selector(checkinTimeout)
                                                             object:nil];
    
    for (NSDictionary *checkinRequest in self.checkinRequests) {
    
        STMCoreLocation *checkinLocationObject = [STMLocationController locationObjectFromCLLocation:checkinLocation];

        if (checkinLocationObject) {

            NSDictionary *checkinData = checkinRequest[@"checkinData"];
            [self.session.persistenceDelegate setObjectData:checkinData toObject:checkinLocationObject];

        }
        
        NSDictionary *checkinLocationDic = checkinLocationObject ? [[self persistenceDelegate] dictionaryFromManagedObject:checkinLocationObject] : @{};

        id <STMCheckinDelegate> checkinDelegate = checkinRequest[@"delegate"];
        NSNumber *requestId = checkinRequest[@"requestId"];
        
        [self.session.persistenceDelegate mergeAsync:self.locationConcreteName attributes:checkinLocationDic options:nil completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
            //TODO: check if success
            [checkinDelegate getCheckinLocation:result
                                   forRequestId:requestId];
        }];

    }
    
    NSString *logMessage = [NSString stringWithFormat:@"receiveCheckinLocation: %@", checkinLocation.description];
    [[self.session logger] saveLogMessageWithText:logMessage
                                          numType:STMLogMessageTypeImportant];
    
    [self endCheckinMode];

}

- (void)checkinLocationError:(NSString *)errorString {
    
    [[self.session logger] saveLogMessageWithText:errorString
                                          numType:STMLogMessageTypeError];
    
    for (NSDictionary *checkinRequest in self.checkinRequests) {
        
        id <STMCheckinDelegate> checkinDelegate = checkinRequest[@"delegate"];
        NSNumber *requestId = checkinRequest[@"requestId"];
        
        [checkinDelegate checkinLocationError:errorString forRequestId:requestId];
        
    }

    [self endCheckinMode];

}

- (void)endCheckinMode {

    self.checkinMode = NO;
    self.bestCheckinLocation = nil;
    self.checkinRequests = nil;
    
    if (!self.tracking) {
        [self flushLocationManager];
    }

}


#pragma mark - timeFilterTimer

- (NSTimer *)locationWaitingTimer {
    
    if (!_locationWaitingTimer) {
        
        NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:self.locationWaitingTimeInterval];
//        NSLog(@"fireDate %@", fireDate);
        
        _locationWaitingTimer = [[NSTimer alloc] initWithFireDate:fireDate
                                                    interval:0
                                                      target:self
                                                    selector:@selector(locationWaitingTimerTick)
                                                    userInfo:nil
                                                     repeats:NO];
        
//        NSLog(@"timer %@ fireDate %@", _timeFilterTimer, _timeFilterTimer.fireDate);
        
    }
    
    //    NSLog(@"_startTimer %@", _startTimer);
    return _locationWaitingTimer;
    
}

- (void)startLocationWaitingTimer {
    [[NSRunLoop currentRunLoop] addTimer:self.locationWaitingTimer forMode:NSRunLoopCommonModes];
}

- (void)locationWaitingTimerTick {
    [self updateLastSeenTimestamp];
}

- (void)resetLocationWaitingTimer {
    
    if (self.locationWaitingTimer) {
    
        [[NSRunLoop currentRunLoop] performSelector:@selector(invalidate)
                                             target:self.locationWaitingTimer
                                           argument:nil
                                              order:0
                                              modes:@[NSRunLoopCommonModes]];
        self.locationWaitingTimer = nil;

    }
    
}


#pragma mark - checking start tracking conditions

- (void)checkTrackerAutoStart {
    
    if (![self.requestLocationServiceAuthorization isEqualToString:@"noRequest"]) {
        
        [self requestAuthorization:^(BOOL success) {
            
            if (success) {
                [self successAuthorization];
            }
            
        }];
        
    } else {
        if (self.tracking) [self stopTracking];
    }

}

- (void)successAuthorization {
    
    [self initTimers];
    [self checkAccuracyToStartTracking];

}

- (void)checkAccuracyToStartTracking {
    
    if ([self currentDesiredAccuracy] != 0) {
        
        if (!self.tracking) [self startTracking];
        [self updateDesiredAccuracy];
        
    } else {
        
        if (self.tracking) [self stopTracking];
        
    }

}

- (void)checkTimeForTracking {
    // prevent from super class method execute - causes to undesirable stop of tracker
}

- (BOOL)checkNANValues:(CLLocation *)location {
    
    return location.coordinate.latitude != NAN
    && location.coordinate.longitude != NAN
    && location.horizontalAccuracy != NAN
    && location.verticalAccuracy != NAN
    && location.altitude != NAN;
    
}


#pragma mark - timers

- (void)initTimers {
    
    if (self.startTimer || self.finishTimer) {
        [self releaseTimers];
    }
    
    [[NSRunLoop currentRunLoop] addTimer:self.startTimer forMode:NSRunLoopCommonModes];
    [[NSRunLoop currentRunLoop] addTimer:self.finishTimer forMode:NSRunLoopCommonModes];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@TimersInit", self.group] object:self];
    
}

- (void)releaseTimers {
    
    [self.startTimer invalidate];
    [self.finishTimer invalidate];
    self.startTimer = nil;
    self.finishTimer = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@TimersRelease", self.group] object:self];
    
}

- (NSTimer *)startTimer {
    
    if (!_startTimer) {
        
        if ([self isValidTimeValue:self.trackerStartTime]) {
            
            NSDate *startTime = [self timerTimeFromDoubleTime:self.trackerStartTime];
            
            _startTimer = [[NSTimer alloc] initWithFireDate:startTime
                                                   interval:24*3600
                                                     target:self
                                                   selector:@selector(checkTrackerAutoStart)
                                                   userInfo:nil
                                                    repeats:YES];
        }
        
    }

    return _startTimer;
    
}

- (NSTimer *)finishTimer {
    
    if (!_finishTimer) {
        
        if ([self isValidTimeValue:self.trackerFinishTime]) {
            
            NSDate *finishTime = [self timerTimeFromDoubleTime:self.trackerFinishTime];
            
            _finishTimer = [[NSTimer alloc] initWithFireDate:finishTime
                                                    interval:24*3600
                                                      target:self
                                                    selector:@selector(checkTrackerAutoStart)
                                                    userInfo:nil
                                                     repeats:YES];
        }
        
    }

    return _finishTimer;
    
}

- (NSDate *)timerTimeFromDoubleTime:(double)time {

    NSDate *timerTime = [STMFunctions dateFromDouble:time];
    
    if ([timerTime compare:[NSDate date]] == NSOrderedAscending) {
        timerTime = [NSDate dateWithTimeInterval:24*3600 sinceDate:timerTime];
    }

    return timerTime;
    
}


#pragma mark - track management

- (void)addLocation:(CLLocation *)location {

//    [self tracksManagementWithLocation:currentLocation];

    [self resetLocationWaitingTimer];
    [self startLocationWaitingTimer];
    
    STMCoreLocation *locationObject = [STMLocationController locationObjectFromCLLocation:location];
    locationObject.lastSeenAt = locationObject.timestamp;
    
    self.lastLocation = location;
    self.lastLocationObject = locationObject;
    
    NSLog(@"location %@", self.lastLocation);
    
    [self.persistenceDelegate mergeAsync:self.locationConcreteName
                              attributes:[[self persistenceDelegate] dictionaryFromManagedObject:locationObject]
                                 options:nil
                       completionHandler:nil];
    
}

- (void)updateLastSeenTimestamp {
    
    [self resetLocationWaitingTimer];
    
    if ([self currentTimeIsInsideOfScheduleLimits]) {
    
        [self startLocationWaitingTimer];
        
        if (self.lastLocationObject) {
            
            NSLog(@"UPDATE LAST SEEN TIMESTAMP FOR LOCATION: %@", self.lastLocation);
            self.lastLocationObject.lastSeenAt = [NSDate date];
            
            [self.session.persistenceDelegate mergeAsync:self.locationConcreteName
                                              attributes:[[self persistenceDelegate] dictionaryFromManagedObject:self.lastLocationObject]
                                                 options:nil
                                       completionHandler:nil];

        }

    }
    
}


@end
