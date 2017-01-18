//
//  STMPersistingPromised.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@import PromiseKit;

@protocol STMPersistingPromised <NSObject>

@required

- (AnyPromise *)find:(NSString *)entityName
                  id:(NSString *)identifier
             options:(NSDictionary *)options;

- (AnyPromise *)findAll:(NSString *)entityName
              predicate:(NSPredicate *)predicate
                options:(NSDictionary *)options;

- (AnyPromise *)merge:(NSString *)entityName
           attributes:(NSDictionary *)attributes
              options:(NSDictionary *)options;

- (AnyPromise *)mergeMany:(NSString *)entityName
           attributeArray:(NSArray *)attributeArray
                  options:(NSDictionary *)options;

- (AnyPromise *)destroy:(NSString *)entityName
                     id:(NSString *)identifier
                options:(NSDictionary *)options;

@optional

- (AnyPromise *)create:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options;

- (AnyPromise *)update:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options;

- (AnyPromise *)updateAll:(NSString *)entityName
               attributes:(NSDictionary *)attributes
                predicate:(NSPredicate *)predicate
                  options:(NSDictionary *)options;


@end
