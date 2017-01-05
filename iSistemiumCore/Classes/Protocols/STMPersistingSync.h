//
//  STMPersistingSync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingSync <NSObject>

- (NSDictionary *)createSyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)findSyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSArray *)findAllSyncWithEntityName:(NSString *)entityName WithPredicate:(NSPredicate *)predicate WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)mergeSyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithAttributes:(NSDictionary *)attributes WithOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)destroySyncWithEntityName:(NSString *)entityName WithId:(NSDictionary *)identifier WithOptions:(NSDictionary *)options WithError:(NSError *)error;

@end
