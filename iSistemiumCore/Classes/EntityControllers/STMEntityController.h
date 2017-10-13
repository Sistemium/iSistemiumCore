//
//  STMEntityController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMEntity.h"

#define STM_ENTITY_NAME @"STMEntity"


@interface STMEntityController : STMCoreController

+ (void)flushSelf;

+ (NSDictionary <NSString *, NSDictionary *> *)stcEntities;

+ (NSString *)resourceForEntity:(NSString *)entityName;

+ (void)checkEntitiesForDuplicates;

+ (NSArray <NSString *> *)entityNamesWithResolveFantoms;

+ (NSSet <NSString *> *)entityNamesWithLifeTime;

+ (NSArray <NSString *> *)downloadableEntityNames;

+ (NSArray <NSDictionary *> *)entitiesWithLifeTime;

+ (NSArray *)uploadableEntitiesNames;

+ (NSDictionary *)entityWithName:(NSString *)name;

+ (void)addChangesObserver:(STMCoreObject *)anObject selector:(SEL)selector;

+ (BOOL)downloadableEntityReady;


@end
