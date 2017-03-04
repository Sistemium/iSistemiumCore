//
//  STMRecordStatusController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMPersistingIntercepting.h"

#define STM_RECORDSTATUS_NAME @"STMRecordStatus"

@interface STMRecordStatusController : STMCoreController <STMPersistingMergeInterceptor>

+ (NSDictionary *)existingRecordStatusForXid:(NSString *)objectXid;
+ (NSArray *)recordStatusesForXids:(NSArray *)xids;


@end
