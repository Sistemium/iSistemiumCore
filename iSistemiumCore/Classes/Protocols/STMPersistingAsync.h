//
//  STMPersistingAsync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingAsync <NSObject>

- (NSDictionary *)createAsyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)findAsyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSArray *)findAllAsyncWithEntityName:(NSString *)entityName WithPredicate:(NSPredicate *)predicate WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)mergeAsyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)destroyAsyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options WithError:(NSError *)error;

@end
