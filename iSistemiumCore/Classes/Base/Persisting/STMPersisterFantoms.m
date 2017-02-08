//
//  STMPersisterFantoms.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisterFantoms.h"

#import "STMFunctions.h"


@implementation STMPersisterFantoms

@synthesize persistenceDelegate = _persistenceDelegate;

+ (instancetype)persisterFantomsWithPersistenceDelegate:(id <STMPersistingFullStack>)persistenceDelegate {
    
    STMPersisterFantoms *persisterFantoms = [[STMPersisterFantoms alloc] init];
    persisterFantoms.persistenceDelegate = persistenceDelegate;
    
    return persisterFantoms;
    
}

- (NSArray *)findAllFantomsSync:(NSString *)entityName {
    
    NSError *error = nil;
    
    return [self.persistenceDelegate findAllSync:entityName
                                       predicate:nil
                                         options:@{STMPersistingOptionFantoms : @YES}
                                           error:&error];
    
}

- (BOOL)destroyFantomSync:(NSString *)entityName identifier:(NSString *)identifier {
    
    NSError *error = nil;
    
    return [self.persistenceDelegate destroySync:entityName
                                      identifier:identifier
                                         options:nil
                                           error:&error];
    
}

- (void)mergeFantomAsync:(NSString *)entityName attributes:(NSDictionary *)attributes completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    NSDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]};
    
    [self.persistenceDelegate mergeAsync:entityName
                              attributes:attributes
                                 options:options
                       completionHandler:completionHandler];
    
}


@end
