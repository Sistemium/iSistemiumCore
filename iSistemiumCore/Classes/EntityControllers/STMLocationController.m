//
//  STMLocationController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 02/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMLocationController.h"
#import "STMObjectsController.h"


@implementation STMLocationController

+ (STMLocation *)locationObjectFromCLLocation:(CLLocation *)location {
    
    STMLocation *locationObject = (STMLocation *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMLocation class]) isFantom:NO];
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

+ (CLLocation *)locationFromLocationObject:(STMLocation *)locationObject {
    
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
