//
//  STMPersistingAsync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingAsync <NSObject>

@required

- (void)findAsync:(NSString *)entityName
               id:(NSString *)identifier
          options:(NSDictionary *)options
completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler;

- (void)findAllAsync:(NSString *)entityName
           predicate:(NSPredicate *)predicate
             options:(NSDictionary *)options
   completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler;

- (void)mergeAsync:(NSString *)entityName
        attributes:(NSDictionary *)attributes
           options:(NSDictionary *)options
 completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler;

- (void)mergeManyAsync:(NSString *)entityName
        attributeArray:(NSArray *)attributeArray
               options:(NSDictionary *)options
     completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler;

- (void)destroyAsync:(NSString *)entityName
                  id:(NSString *)identifier
             options:(NSDictionary *)options
   completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

@optional

- (void)createAsync:(NSString *)entityName
         attributes:(NSDictionary *)attributes
            options:(NSDictionary *)options
  completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler;

- (void)updateAsync:(NSString *)entityName
         attributes:(NSDictionary *)attributes
            options:(NSDictionary *)options
  completionHandler:(void (^)(BOOL success, NSDictionary *result, NSError *error))completionHandler;

- (void)updateAllAsync:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options
     completionHandler:(void (^)(BOOL success, NSArray *result, NSError *error))completionHandler;

@end
