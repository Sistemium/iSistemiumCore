//
//  STMEntityController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMEntity.h"
#import "STMPersistingIntercepting.h"

#define STM_ENTITY_NAME @"STMEntity"

@interface STMEntityController : STMCoreController <STMPersistingMergeInterceptor>

+ (void)flushSelf;

+ (NSDictionary *)stcEntities;

+ (void)checkEntitiesForDuplicates;

+ (NSArray *)entityNamesWithResolveFantoms;

+ (NSSet *)entityNamesWithLifeTime;
+ (NSArray *)entitiesWithLifeTime;

+ (NSArray *)uploadableEntitiesNames;

+ (NSDictionary *)entityWithName:(NSString *)name;

+ (void)addChangesObserver:(STMCoreObject *)anObject selector:(SEL)selector;

- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error;

@end
