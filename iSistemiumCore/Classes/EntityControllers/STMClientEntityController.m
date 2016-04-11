//
//  STMClientEntityController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMClientEntityController.h"
#import "STMEntityController.h"
#import "STMObjectsController.h"


@implementation STMClientEntityController

+ (STMClientEntity *)clientEntityWithName:(NSString *)name {
    
    STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMClientEntity class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:nil];
    
    if (result.count > 1) {
        
        NSString *logMessage = [NSString stringWithFormat:@"more than one clientEntity with name %@", name];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
        
    }
    
    STMClientEntity *clientEntity = result.lastObject;
    
    if (!clientEntity) {
        
        clientEntity = (STMClientEntity *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMClientEntity class]) isFantom:NO];
        clientEntity.name = name;
        
        STMEntity *entity = [STMEntityController entityWithName:name];
        clientEntity.eTag = entity.eTag;
        
    }
    
    return clientEntity;
    
}


@end
