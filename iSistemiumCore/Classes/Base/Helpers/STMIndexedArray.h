//
//  STMIndexedArray.h
//  iSisSales
//
//  Created by Alexander Levin on 04/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#define STM_INDEXED_ARRAY_DEFAULT_PRIMARY_KEY @"id"

@interface STMIndexedArray : NSObject

+ (instancetype)array;
+ (instancetype)arrayWithPrimaryKey:(NSString *)key;

- (NSString *)primaryKey;

- (NSDictionary *)addObject:(NSDictionary *)anObject;
- (NSArray <NSDictionary*> *)addObjectsFromArray:(NSArray <NSDictionary*> *)array;

- (BOOL)removeObjectWithKey:(NSString *)key;

- (NSDictionary *)objectWithKey:(NSString *)key;

- (NSArray <NSDictionary *> *)filteredArrayUsingPredicate:(NSPredicate *)predicate;

@end
