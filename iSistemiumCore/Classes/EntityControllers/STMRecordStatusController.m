//
//  STMRecordStatusController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMRecordStatusController.h"
#import "STMCoreObjectsController.h"


@implementation STMRecordStatusController

+ (NSDictionary *)existingRecordStatusForXid:(NSString *)objectXid {
    
    NSError* error;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.objectXid == %@", objectXid];
    
    NSArray* recordStatus = [[self persistenceDelegate] findAllSync:@"STMRecordStatus" predicate:predicate options:nil error:&error];
    
    if (error){
        return nil;
    }
    
    if ([recordStatus count] > 0){
        return recordStatus.firstObject;
    }
    
    return nil;
    
}

+ (NSArray *)recordStatusesForXids:(NSArray *)xids {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"objectXid IN %@", xids];
    
    NSError *error;
    NSArray *recordStatuses = [[self persistenceDelegate] findAllSync:@"RecordStatus" predicate:predicate options:nil error:&error];

    return recordStatuses;
    
}

@end
