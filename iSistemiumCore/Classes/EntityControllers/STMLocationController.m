//
//  STMLocationController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 02/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMLocationController.h"

#import "STMCoreObjectsController.h"
#import "STMCoreSessionManager.h"


@implementation STMLocationController

+ (NSString *)locationConcreteName {
    return NSStringFromClass([[self session] locationClass]);
}

+ (STMCoreLocation *)locationObjectFromCLLocation:(CLLocation *)location {

    if (!location) return nil;
    
    STMCoreLocation *locationObject = (STMCoreLocation *)[[self session].persistenceDelegate newObjectForEntityName:[self locationConcreteName]];
    
    locationObject.isFantom = @(NO);
    locationObject.xid = [STMFunctions xidDataFromXidString:[[[NSUUID alloc] init] UUIDString]];

    locationObject.latitude = [NSDecimalNumber decimalNumberWithDecimal:@(location.coordinate.latitude).decimalValue];
    locationObject.longitude = [NSDecimalNumber decimalNumberWithDecimal:@(location.coordinate.longitude).decimalValue];
    locationObject.horizontalAccuracy = [NSDecimalNumber decimalNumberWithDecimal:@(location.horizontalAccuracy).decimalValue];
    locationObject.speed = [NSDecimalNumber decimalNumberWithDecimal:@(location.speed).decimalValue];
    locationObject.course = [NSDecimalNumber decimalNumberWithDecimal:@(location.course).decimalValue];
    locationObject.altitude = [NSDecimalNumber decimalNumberWithDecimal:@(location.altitude).decimalValue];
    locationObject.verticalAccuracy = [NSDecimalNumber decimalNumberWithDecimal:@(location.verticalAccuracy).decimalValue];
    locationObject.timestamp = location.timestamp;
    return locationObject;
    
}

+ (CLLocation *)locationFromLocationObject:(STMCoreLocation *)locationObject {
    
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([locationObject.latitude doubleValue], [locationObject.longitude doubleValue]);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                         altitude:[locationObject.altitude doubleValue]
                                               horizontalAccuracy:[locationObject.horizontalAccuracy doubleValue]
                                                 verticalAccuracy:[locationObject.verticalAccuracy doubleValue]
                                                           course:[locationObject.course doubleValue]
                                                            speed:[locationObject.speed doubleValue]
                                                        timestamp:(locationObject.deviceCts) ? (NSDate * _Nonnull)locationObject.deviceCts : [NSDate dateWithTimeIntervalSince1970:0]];
    return location;
    
}


@end
