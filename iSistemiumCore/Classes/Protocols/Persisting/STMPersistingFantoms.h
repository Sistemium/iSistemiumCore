//
//  STMPersistingFantoms.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingAsync.h"


@protocol STMPersistingFantoms <NSObject>

- (NSArray *)findAllFantomsSync:(NSString *)entityName
                      predicate:(NSPredicate *)predicate
                        options:(NSDictionary *)options
                          error:(NSError **)error;

- (BOOL)destroyFantomSync:(NSString *)entityName
               identifier:(NSString *)identifier
                  options:(NSDictionary *)options
                    error:(NSError **)error;

- (void)mergeFantomAsync:(NSString *)entityName
              attributes:(NSDictionary *)attributes
                 options:(NSDictionary *)options
       completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;


@end
