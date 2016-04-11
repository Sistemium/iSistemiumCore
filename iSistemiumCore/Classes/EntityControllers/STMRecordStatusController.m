//
//  STMRecordStatusController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMRecordStatusController.h"
#import "STMObjectsController.h"


@implementation STMRecordStatusController

+ (STMRecordStatus *)existingRecordStatusForXid:(NSData *)objectXid {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMRecordStatus class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"SELF.objectXid == %@", objectXid];
    
    NSError *error;
    NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    STMRecordStatus *recordStatus = [fetchResult lastObject];
    
    return recordStatus;
    
}

+ (STMRecordStatus *)recordStatusForObject:(NSManagedObject *)object {
    
    NSData *objectXid = [object valueForKey:@"xid"];
    
    STMRecordStatus *recordStatus = [self existingRecordStatusForXid:objectXid];
    
    if (!recordStatus) {
        
        recordStatus = (STMRecordStatus *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMRecordStatus class]) isFantom:NO];
        recordStatus.objectXid = objectXid;
        
    }
    
    return recordStatus;
    
}

+ (NSArray *)recordStatusesForXids:(NSArray *)xids {
    
    STMFetchRequest *request = [[STMFetchRequest alloc] initWithEntityName:NSStringFromClass([STMRecordStatus class])];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"objectXid IN %@", xids];
    
    request.sortDescriptors = @[sortDescriptor];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *recordStatuses = [[self document].managedObjectContext executeFetchRequest:request error:&error];

    return recordStatuses;
    
}

@end
