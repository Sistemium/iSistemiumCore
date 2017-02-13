//
//  STMPersistingWithHeadersAsync.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^STMPersistingWithHeadersAsyncArrayResultCallback)(BOOL success, NSArray *result, NSDictionary *headers, NSError *error);
typedef void (^STMPersistingWithHeadersAsyncDictionaryResultCallback)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error);

@protocol STMPersistingWithHeadersAsync <NSObject>

- (void)findAsync:(NSString *)entityName
       identifier:(NSString *)identifier
          options:(NSDictionary *)options
completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler;

- (void)findAllAsync:(NSString *)entityName
           predicate:(NSPredicate *)predicate
             options:(NSDictionary *)options
   completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncArrayResultCallback)completionHandler;

- (void)mergeAsync:(NSString *)entityName
        attributes:(NSDictionary *)attributes
           options:(NSDictionary *)options
 completionHandlerWithHeaders:(STMPersistingWithHeadersAsyncDictionaryResultCallback)completionHandler;


@end
