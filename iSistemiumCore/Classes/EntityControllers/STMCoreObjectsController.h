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

+ (NSArray *)coreEntityKeys;

+ (void)dataLoadingFinished;

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName isFantom:(BOOL)isFantom;

+ (NSDictionary *)objectForIdentifier:(NSString *)identifier;
+ (NSDictionary *)objectForIdentifier:(NSString *)identifier entityName:(NSString**)name;

+ (void)logTotalNumberOfObjectsInStorages;
+ (BOOL)isWaitingToSyncForObject:(NSManagedObject *)object;

@end
