//
//  STMRemotePersisterController.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 28/06/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMRemotePersisterController.h"

@implementation STMRemotePersisterController

+ (NSArray *)findAllRemote:(NSDictionary *)data{
    
    NSError *error = nil;
    
    NSString * entityName = data[@"entityName"];
    
    NSString *predicateFormat = data[@"predicateFormat"];
    
    NSDictionary *options = data[@"options"];
    
    NSPredicate *predicate = predicateFormat ? [NSPredicate predicateWithFormat:predicateFormat] : nil;
    
    NSArray *response = nil;
    
    if (!entityName){
        [STMFunctions error:&error withMessage:@"No entity name given"];
    }else{
        response = [self.persistenceDelegate findAllSync:entityName predicate:predicate options:options error:&error];
    }
    
    if (error){
        
        [NSException raise:@"findAllRemote exception" format:@"%@", [error localizedDescription]];
        
    }
    
    return response;

}

+ (NSNumber *)countRemote:(NSDictionary *)data{
    
    NSError *error = nil;
    
    NSString * entityName = data[@"entityName"];
    
    NSString *predicateFormat = data[@"predicateFormat"];
    
    NSDictionary *options = data[@"options"];
    
    NSPredicate *predicate = predicateFormat ? [NSPredicate predicateWithFormat:predicateFormat] : nil;
    
    NSNumber *response = 0;
    
    if (!entityName){
        [STMFunctions error:&error withMessage:@"No entity name given"];
    }else{
        response = [NSNumber numberWithUnsignedInteger:[self.persistenceDelegate countSync:entityName predicate:predicate options:options error:&error]];
    }
    
    if (error){
        
        [NSException raise:@"findAllRemote exception" format:@"%@", [error localizedDescription]];
        
    }
    
    return response;
    
}

+ (NSString *)destroyAllRemote:(NSDictionary *)data{

    NSError *error = nil;
    
    NSString * entityName = data[@"entityName"];
    
    NSString *predicateFormat = data[@"predicateFormat"];
    
    NSDictionary *options = data[@"options"];
    
    NSPredicate *predicate = predicateFormat ? [NSPredicate predicateWithFormat:predicateFormat] : nil;
    
    NSUInteger response = 0;
    
    if (!entityName){
        [STMFunctions error:&error withMessage:@"No entity name given"];
    }else{
        response = [self.persistenceDelegate destroyAllSync:entityName predicate:predicate options:options error:&error];
    }
    
    if (error){
        
        [NSException raise:@"findAllRemote exception" format:@"%@", [error localizedDescription]];
        
    }
    
    return [NSString stringWithFormat:@"%lu rows deleted",(unsigned long)response];
    
}

@end
