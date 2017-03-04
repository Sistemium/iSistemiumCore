//
//  STMPersistingPromised.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersisting.h"

@import PromiseKit;

@protocol STMPersistingPromised

@required

- (AnyPromise *)find:(NSString *)entityName
          identifier:(NSString *)identifier
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
             identifier:(NSString *)identifier
                options:(NSDictionary *)options;

- (AnyPromise *)destroyAll:(NSString *)entityName
                 predicate:(NSPredicate *)predicate
                   options:(NSDictionary *)options;

@optional

- (AnyPromise *)update:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options;

- (AnyPromise *)updateAll:(NSString *)entityName
               attributes:(NSDictionary *)attributes
                predicate:(NSPredicate *)predicate
                  options:(NSDictionary *)options;

- (AnyPromise *)create:(NSString *)entityName
            attributes:(NSDictionary *)attributes
               options:(NSDictionary *)options;

@end
