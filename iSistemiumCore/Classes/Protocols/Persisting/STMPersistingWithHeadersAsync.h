//
//  STMPersistingWithHeadersAsync.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingWithHeadersAsync <NSObject>

- (void)findAsync:(NSString *)entityName
       identifier:(NSString *)identifier
          options:(NSDictionary *)options
completionHandlerWithHeaders:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler;

- (void)findAllAsync:(NSString *)entityName
           predicate:(NSPredicate *)predicate
             options:(NSDictionary *)options
   completionHandlerWithHeaders:(void (^)(BOOL success, NSArray *result, NSDictionary *headers, NSError *error))completionHandler;

- (void)mergeAsync:(NSString *)entityName
        attributes:(NSDictionary *)attributes
           options:(NSDictionary *)options
 completionHandlerWithHeaders:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler;


@end
