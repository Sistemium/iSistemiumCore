//
//  STMCoreTracker.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 3/11/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import "STMCoreObject.h"
#import "STMSessionManagement.h"

@interface STMCoreTracker : STMCoreObject

@property (nonatomic, weak) id <STMSession> session;
@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic, strong) NSString *group;
@property (nonatomic) BOOL tracking;
@property (nonatomic) BOOL trackerAutoStart;
@property (nonatomic) double trackerStartTime;
@property (nonatomic) double trackerFinishTime;

- (void)customInit;
- (void)startTracking;
- (void)stopTracking;
- (void)prepareToDestroy;
- (void)didReceiveRemoteNotification:(NSNotification *)notification;
- (BOOL)currentTimeIsInsideOfScheduleLimits;
- (BOOL)isValidTimeValue:(double)timeValue;


@end
