//
//  STMClientEntityController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMClientEntityController.h"
#import "STMEntityController.h"
#import "STMCoreObjectsController.h"


@implementation STMClientEntityController

+ (NSString *)clientEntityClassName {
    return NSStringFromClass([STMClientEntity class]);
}

+ (void)clientEntityWithName:(NSString *)name setETag:(NSString *)eTag {
    
    NSMutableDictionary *clientEntity = [self clientEntityWithName:name].mutableCopy;
    
    clientEntity[@"eTag"] = eTag ? eTag : [NSNull null];
    
    NSError *error = nil;
    
//    NSDictionary *result =
    [[self persistenceDelegate] mergeSync:[self clientEntityClassName]
                               attributes:clientEntity
                                  options:nil
                                    error:&error];
    
//    NSLog(@"clientEntity set eTag %@ result: %@", eTag, result);
    
}

+ (NSDictionary *)clientEntityWithName:(NSString *)name {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    
    NSError *error = nil;
    NSArray *result = [[self persistenceDelegate] findAllSync:[self clientEntityClassName]
                                                    predicate:predicate
                                                      options:nil
                                                        error:&error];
    
    if (result.count > 1) {
        
        NSString *logMessage = [NSString stringWithFormat:@"more than one clientEntity with name %@", name];
        [self.session.logger saveLogMessageWithText:logMessage
                                            numType:STMLogMessageTypeError];
        
    }
    
    NSDictionary *clientEntity = result.lastObject;

    if (!clientEntity) {
        
        NSString *eTag = [STMEntityController entityWithName:name][@"eTag"];
        
        clientEntity = @{@"name"    : name,
                         @"eTag"    : eTag ? eTag : [NSNull null]};
    
    }
    
    return clientEntity;
    
}


@end
