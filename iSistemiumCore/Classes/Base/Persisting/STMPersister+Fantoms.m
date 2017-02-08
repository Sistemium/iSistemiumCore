//
//  STMPersister+Fantoms.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Fantoms.h"

#import "STMPersister+Async.h"
#import "STMFunctions.h"


@implementation STMPersister (Fantoms)

- (NSArray *)findAllFantomsSync:(NSString *)entityName {

    NSError *error = nil;
    
    return [self findAllSync:entityName
                   predicate:nil
                     options:@{STMPersistingOptionFantoms : @YES}
                       error:&error];
    
}

- (BOOL)destroyFantomSync:(NSString *)entityName identifier:(NSString *)identifier {
    
    NSError *error = nil;

    return [self destroySync:entityName
                  identifier:identifier
                     options:nil
                       error:&error];
    
}

- (void)mergeFantomAsync:(NSString *)entityName attributes:(NSDictionary *)attributes completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    NSDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]};

    [self mergeAsync:entityName
          attributes:attributes
             options:options
   completionHandler:completionHandler];
    
}


@end
