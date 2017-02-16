//
//  STMLocationController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 02/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMCoreLocation.h"
#import <CoreLocation/CoreLocation.h>

@interface STMLocationController : STMCoreController

+ (STMCoreLocation *)locationObjectFromCLLocation:(CLLocation *)location;
+ (CLLocation *)locationFromLocationObject:(STMCoreLocation *)locationObject;


@end
