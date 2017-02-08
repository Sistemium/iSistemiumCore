//
//  STMPersister+Fantoms.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Fantoms.h"

#import "STMPersister+Async.h"


@implementation STMPersister (Fantoms)

- (NSArray *)findAllFantomsSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    
    NSMutableDictionary *fantomsOptions = options.mutableCopy;
    if (!fantomsOptions) fantomsOptions = @{}.mutableCopy;
    
    fantomsOptions[STMPersistingOptionFantoms] = @YES;
    
    return [self findAllSync:entityName
                   predicate:predicate
                     options:fantomsOptions
                       error:error];
    
}

- (BOOL)destroyFantomSync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options error:(NSError **)error {
    
    return [self destroySync:entityName
                  identifier:identifier
                     options:options
                       error:error];
    
}

- (void)mergeFantomAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler {
    
    [self mergeAsync:entityName
          attributes:attributes
             options:options
   completionHandler:completionHandler];
    
}


@end
