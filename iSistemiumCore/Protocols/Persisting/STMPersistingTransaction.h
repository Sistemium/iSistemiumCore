//
//  STMPersistingTransaction.h
//  iSisSales
//
//  Created by Alexander Levin on 18/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMModelling.h"

#define STMPerisistingResultSet NSArray <NSDictionary *> *

@protocol STMPersistingTransaction

@property (readonly) id <STMModelling> modellingDelegate;

- (NSUInteger)destroyWithoutSave:(NSString *)entityName
                       predicate:(NSPredicate *)predicate
                         options:(NSDictionary *)options
                           error:(NSError **)error;

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName
                        attributes:(NSDictionary *)attributes
                           options:(NSDictionary *)options
                             error:(NSError **)error;

- (NSDictionary *)updateWithoutSave:(NSString *)entityName
                         attributes:(NSDictionary *)attributes
                            options:(NSDictionary *)options
                              error:(NSError **)error;

- (NSUInteger)count:(NSString *)entityName
          predicate:(NSPredicate *)predicate
            options:(NSDictionary *)options
              error:(NSError **)error;

@optional

- (STMPerisistingResultSet)findAllSync:(NSString *)entityName
                             predicate:(NSPredicate *)predicate
                               options:(NSDictionary *)options
                                 error:(NSError **)error;

- (STMPerisistingResultSet)findAllSync:(NSString *)name
                             predicate:(NSPredicate *)predicate
                               orderBy:(NSString *)orderBy
                             ascending:(BOOL)ascending
                            fetchLimit:(NSUInteger)fetchLimit
                           fetchOffset:(NSUInteger)fetchOffset
                               groupBy:(NSArray *)groupBy;

@end
