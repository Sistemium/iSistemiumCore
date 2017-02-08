//
//  STMCoreObjectsController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 07/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

#import <CoreData/CoreData.h>

@interface STMCoreObjectsController : STMCoreController

+ (STMCoreObjectsController *)sharedController;

+ (void)checkObjectsForFlushing;

+ (void)setObjectData:(NSDictionary *)objectData
             toObject:(STMDatum *)object;

+ (NSArray <NSString *> *)localDataModelEntityNames;
+ (NSArray *)coreEntityKeys;

+ (NSSet *)ownObjectKeysForEntityName:(NSString *)entityName;
+ (NSDictionary *)ownObjectRelationshipsForEntityName:(NSString *)entityName;
+ (NSDictionary *)toManyRelationshipsForEntityName:(NSString *)entityName;

+ (void)dataLoadingFinished;

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName
                            isFantom:(BOOL)isFantom;

+ (NSDictionary *)objectForIdentifier:(NSString *)identifier;

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName;

+ (void)logTotalNumberOfObjectsInStorages;
+ (BOOL)isWaitingToSyncForObject:(NSManagedObject *)object;

@end
