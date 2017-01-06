//
//  STMPersistingSync.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingSync <NSObject>

@required

- (NSDictionary *)findSyncWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options withError:(NSError *)error;

- (NSArray *)findAllSyncWithEntityName:(NSString *)entityName withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options withError:(NSError *)error;

- (NSDictionary *)mergeSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options withError:(NSError *)error;

- (NSArray *)mergeManySyncWithEntityName:(NSString *)entityName withAttributeArray:(NSArray *)attributeArray withOptions:(NSDictionary *)options withError:(NSError *)error;

- (bool *)destroySyncWithEntityName:(NSString *)entityName withId:(NSDictionary *)identifier withOptions:(NSDictionary *)options withError:(NSError *)error;

- (NSDictionary *)createSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSDictionary *)updateSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withOptions:(NSDictionary *)options WithError:(NSError *)error;

- (NSArray *)updateAllSyncWithEntityName:(NSString *)entityName withAttributes:(NSDictionary *)attributes withPredicate:(NSPredicate *)predicate withOptions:(NSDictionary *)options WithError:(NSError *)error;

@end
