//
//  STMEntityController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"


@interface STMEntityController : STMCoreController

+ (void)flushSelf;

+ (NSDictionary *)stcEntities;

+ (void)checkEntitiesForDuplicates;

+ (NSSet *)entityNamesWithResolveFantoms;

+ (NSSet *)entityNamesWithLifeTime;
+ (NSArray *)entitiesWithLifeTime;

+ (NSArray *)uploadableEntitiesNames;

+ (STMEntity *)entityWithName:(NSString *)name;

+ (void)deleteEntityWithName:(NSString *)name;

@end
