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

- (AnyPromise *)findPromisedWithEntityName:(NSString *)entityName qithId:(NSDictionary *)identifier qithOptions:(NSDictionary *)options;

- (AnyPromise *)findPromisedAllWithEntityName:(NSString *)entityName qithPredicate:(NSPredicate *)predicate qithOptions:(NSDictionary *)options;

- (AnyPromise *)mergePromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options;

- (AnyPromise *)mergeManyPromisedWithEntityName:(NSString *)entityName withAttributeArray:(NSArray *)attributeArray withOptions:(NSDictionary *)options;

- (AnyPromise *)destroyPromisedWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options;

- (AnyPromise *)createPromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options;

- (AnyPromise *)updatePromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options;

- (AnyPromise *)updateAllPromisedWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options;

@end
