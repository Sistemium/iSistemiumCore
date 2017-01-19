//
//  STMRecordStatusController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"


@interface STMRecordStatusController : STMCoreController

+ (NSDictionary *)existingRecordStatusForXid:(NSString *)objectXid;
+ (NSArray *)recordStatusesForXids:(NSArray *)xids;


@end
