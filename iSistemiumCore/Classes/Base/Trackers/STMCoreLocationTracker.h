//
//  STMCoreLocationTracker.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 4/3/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import "STMCoreTracker.h"
#import "STMCheckinDelegate.h"
#import <CoreLocation/CoreLocation.h>
#import "STMCoreLocation.h"

@interface STMCoreLocationTracker : STMCoreTracker

@property (nonatomic) CLLocationAccuracy currentAccuracy;
@property (nonatomic) BOOL isAccuracySufficient;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, strong) STMCoreLocation *lastLocationObject;
@property (nonatomic, strong) NSString *geotrackerControl;

- (void)getLocation;

- (void)checkinWithAccuracy:(NSNumber *)checkinAccuracy
                checkinData:(NSDictionary *)checkinData
                  requestId:(NSNumber *)requestId
                    timeout:(NSTimeInterval)timeout
                   delegate:(id <STMCheckinDelegate>)delegate;

- (NSString *)locationServiceStatus;

- (void)checkAccuracyToStartTracking;
- (void)initTimers;


@end
