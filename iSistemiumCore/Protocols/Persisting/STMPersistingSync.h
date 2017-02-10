//
//  STMPersistingSync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersisting.h"

@protocol STMPersistingSync

@required

- (NSDictionary *)findSync:(NSString *)entityName
                identifier:(NSString *)identifier
                   options:(NSDictionary *)options
                     error:(NSError **)error;

- (NSArray *)findAllSync:(NSString *)entityName
               predicate:(NSPredicate *)predicate
                 options:(NSDictionary *)options
                   error:(NSError **)error;

- (NSDictionary *)mergeSync:(NSString *)entityName
                 attributes:(NSDictionary *)attributes
                    options:(NSDictionary *)options
                      error:(NSError **)error;

- (NSArray *)mergeManySync:(NSString *)entityName
            attributeArray:(NSArray *)attributeArray
                   options:(NSDictionary *)options
                     error:(NSError **)error;

- (BOOL)destroySync:(NSString *)entityName
         identifier:(NSString *)identifier
            options:(NSDictionary *)options
              error:(NSError **)error;

- (NSUInteger)destroyAllSync:(NSString *)entityName
                   predicate:(NSPredicate *)predicate
                     options:(NSDictionary *)options
                       error:(NSError **)error;

- (NSDictionary *)updateSync:(NSString *)entityName
                  attributes:(NSDictionary *)attributes
                     options:(NSDictionary *)options
                       error:(NSError **)error;

@optional

- (NSArray *)updateAllSync:(NSString *)entityName
                attributes:(NSDictionary *)attributes
                 predicate:(NSPredicate *)predicate
                   options:(NSDictionary *)options
                     error:(NSError **)error;


- (NSDictionary *)createSync:(NSString *)entityName
                  attributes:(NSDictionary *)attributes
                     options:(NSDictionary *)options
                       error:(NSError **)error;

- (NSUInteger)countSync:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options
                  error:(NSError **)error;


@end
