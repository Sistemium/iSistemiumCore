//
//  STMPersistingAsync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingAsync <NSObject>

- (void)findAsyncWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler;

- (void)findAllAsyncWithEntityName:(NSString *)entityName withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSArray *))completionHandler;

- (void)mergeAsyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler;

- (void)mergeManyAsyncWithEntityName:(NSString *)entityName withAttributeArray:(NSArray *)attributeArray withOptions:(NSDictionary *)options withError:(NSError *)error withCompletionHandler:(void (^)(NSArray *))completionHandler;

- (void)destroyAsyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(bool *))completionHandler;

- (void)createAsyncWithEntityName:(NSString *)entityName WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler;

- (void)updateAsyncWithEntityName:(NSString *)entityName WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(NSDictionary *))completionHandler;

- (void)updateAllAsyncWithEntityName:(NSString *)entityName WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error withCompletionHandler:(void (^)(NSArray *))completionHandler;

@end
