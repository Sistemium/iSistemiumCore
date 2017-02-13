//
//  STMPersistingAsync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersisting.h"

#define STMP_ASYNC_ARRAY_RESULT_CALLBACK_ARGS \
BOOL success, NSArray <NSDictionary *> *result, NSError *error

#define STMP_ASYNC_DICTIONARY_RESULT_CALLBACK_ARGS \
BOOL success, NSDictionary *result, NSError *error

#define STMP_ASYNC_NORESULT_CALLBACK_ARGS \
BOOL success, NSError *error

#define STMP_ASYNC_INTEGER_RESULT_CALLBACK_ARGS \
BOOL success, NSUInteger result, NSError *error

typedef void (^STMPersistingAsyncArrayResultCallback)(STMP_ASYNC_ARRAY_RESULT_CALLBACK_ARGS);

typedef void (^STMPersistingAsyncDictionaryResultCallback)(STMP_ASYNC_DICTIONARY_RESULT_CALLBACK_ARGS);

typedef void (^STMPersistingAsyncNoResultCallback)(STMP_ASYNC_NORESULT_CALLBACK_ARGS);

typedef void (^STMPersistingAsyncIntegerResultCallback)(STMP_ASYNC_INTEGER_RESULT_CALLBACK_ARGS);

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
      completionHandler:(STMPersistingAsyncIntegerResultCallback)completionHandler;

- (void)updateAsync:(NSString *)entityName
         attributes:(NSDictionary *)attributes
            options:(NSDictionary *)options
  completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;

@optional

- (void)updateAllAsync:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options
     completionHandler:(STMPersistingAsyncArrayResultCallback)completionHandler;

- (void)createAsync:(NSString *)entityName
         attributes:(NSDictionary *)attributes
            options:(NSDictionary *)options
  completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;

@end
