//
//  STMPersistingAsync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersisting.h"

typedef void (^STMPersistingAsyncArrayResultCallback)(BOOL success, NSArray *result, NSError *error);
typedef void (^STMPersistingAsyncDictionaryResultCallback)(BOOL success, NSDictionary *result, NSError *error);
typedef void (^STMPersistingAsyncNoResultCallback)(BOOL success, NSError *error);

@protocol STMPersistingAsync

@required

- (void)findAsync:(NSString *)entityName
       identifier:(NSString *)identifier
          options:(NSDictionary *)options
completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;

- (void)findAllAsync:(NSString *)entityName
           predicate:(NSPredicate *)predicate
             options:(NSDictionary *)options
   completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler;

- (void)mergeAsync:(NSString *)entityName
        attributes:(NSDictionary *)attributes
           options:(NSDictionary *)options
 completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;

- (void)mergeManyAsync:(NSString *)entityName
        attributeArray:(NSArray *)attributeArray
               options:(NSDictionary *)options
     completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler;

- (void)destroyAsync:(NSString *)entityName
          identifier:(NSString *)identifier
             options:(NSDictionary *)options
   completionHandler:(STMPersistingAsyncNoResultCallback)completionHandler;

- (void)destroyAllAsync:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options
      completionHandler:(STMPersistingAsyncNoResultCallback)completionHandler;

@optional

- (void)createAsync:(NSString *)entityName
         attributes:(NSDictionary *)attributes
            options:(NSDictionary *)options
  completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;

- (void)updateAsync:(NSString *)entityName
         attributes:(NSDictionary *)attributes
            options:(NSDictionary *)options
  completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;

- (void)updateAllAsync:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options
     completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler;

@end
