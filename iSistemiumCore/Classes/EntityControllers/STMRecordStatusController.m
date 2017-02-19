//
//  STMRecordStatusController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMRecordStatusController.h"


@implementation STMRecordStatusController

+ (NSDictionary *)existingRecordStatusForXid:(NSString *)objectXid {
    
    NSError* error;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.objectXid == %@", objectXid];
    
    NSArray* recordStatus = [[self persistenceDelegate] findAllSync:STM_RECORDSTATUS_NAME predicate:predicate options:nil error:&error];
    
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
    NSArray *recordStatuses = [[self persistenceDelegate] findAllSync:STM_RECORDSTATUS_NAME predicate:predicate options:nil error:&error];

    return recordStatuses;
    
}


#pragma mark - PersistingMergeInterceptor protocol


- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error inTransaction:(id<STMPersistingTransaction>)transaction {
    
    if ([options[STMPersistingOptionRecordstatuses] isEqual:@NO]) return attributes;
    
    if ([STMFunctions isNotNullAndTrue:attributes[@"isRemoved"]]) {
        
        NSString *objectXid = attributes[@"objectXid"];
        NSString *entityNameToDestroy = [STMFunctions addPrefixToEntityName:attributes[@"name"]];
        NSPredicate *predicate = [transaction.modellingDelegate primaryKeyPredicateEntityName:entityNameToDestroy values:@[objectXid]];
        
        if (predicate) {
            [transaction destroyWithoutSave:entityNameToDestroy predicate:predicate options:@{STMPersistingOptionRecordstatuses:@NO} error:error];
        }
        
    }
    
    if ([STMFunctions isNotNullAndTrue:attributes[@"isTemporary"]]) return nil;

    return attributes;
}

@end
