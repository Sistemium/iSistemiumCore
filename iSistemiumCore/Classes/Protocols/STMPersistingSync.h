//
//  STMPersistingSync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingSync <NSObject>

@required

- (NSDictionary *)findSync:(NSString *)entityName
                        id:(NSString *)identifier
                   options:(NSDictionary *)options
                     error:(NSError *)error;

- (NSArray *)findAllSync:(NSString *)entityName
               predicate:(NSPredicate *)predicate
                 options:(NSDictionary *)options
                   error:(NSError *)error;

- (NSDictionary *)mergeSync:(NSString *)entityName
                 attributes:(NSDictionary *)attributes
                    options:(NSDictionary *)options
                      error:(NSError *)error;

- (NSArray *)mergeManySync:(NSString *)entityName
            attributeArray:(NSArray *)attributeArray
                   options:(NSDictionary *)options
                     error:(NSError *)error;

@optional

- (BOOL *)destroySync:(NSString *)entityName
                   id:(NSString *)identifier
              options:(NSDictionary *)options
                error:(NSError *)error;

- (NSDictionary *)createSync:(NSString *)entityName
                  attributes:(NSDictionary *)attributes
                     options:(NSDictionary *)options
                       error:(NSError *)error;

- (NSDictionary *)updateSync:(NSString *)entityName
                  attributes:(NSDictionary *)attributes
                     options:(NSDictionary *)options
                       error:(NSError *)error;

- (NSArray *)updateAllSync:(NSString *)entityName
                attributes:(NSDictionary *)attributes
                 predicate:(NSPredicate *)predicate
                   options:(NSDictionary *)options
                     error:(NSError *)error;


@end
