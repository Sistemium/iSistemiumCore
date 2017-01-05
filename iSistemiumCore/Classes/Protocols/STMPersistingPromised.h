//
//  STMPersistingPromised.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingPromised <NSObject>

- (AnyPromise *)createPromisedWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options;

- (AnyPromise *)findPromisedWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options;

- (AnyPromise *)findPromisedAllWithEntityName:(NSString *)entityName WithPredicate:(NSPredicate *)predicate WithOptions:(NSDictionary *)options;

- (AnyPromise *)mergePromisedWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options;

- (AnyPromise *)destroyPromisedWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options;

@end
