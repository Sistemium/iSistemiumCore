//
//  STMLocationTracker.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 4/3/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import "STMTracker.h"
#import "STMCoreDataModel.h"

@interface STMLocationTracker : STMTracker

@property (nonatomic) CLLocationAccuracy currentAccuracy;
@property (nonatomic) BOOL isAccuracySufficient;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, strong) STMLocation *lastLocationObject;
@property (nonatomic, strong) NSString *geotrackerControl;

- (void)getLocation;

- (void)checkinWithAccuracy:(NSNumber *)checkinAccuracy;

- (NSString *)locationServiceStatus;

- (BOOL)currentTimeIsInsideOfScheduleLimits;

- (void)checkAccuracyToStartTracking;
- (void)initTimers;


@end
