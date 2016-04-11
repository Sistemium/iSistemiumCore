//
//  STMLocationController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 02/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"

@interface STMLocationController : STMController

+ (STMLocation *)locationObjectFromCLLocation:(CLLocation *)location;
+ (CLLocation *)locationFromLocationObject:(STMLocation *)locationObject;


@end
