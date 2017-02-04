//
//  STMIndexedArray.h
//  iSisSales
//
//  Created by Alexander Levin on 04/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#define STM_INDEXED_ARRAY_PRIMARY_KEY @"id"

@interface STMIndexedArray : NSObject

+ (instancetype)array;

- (void)addObject:(NSDictionary*)anObject;
- (void)addObjectsFromArray:(NSArray <NSDictionary*> *)array;

- (BOOL)removeObjectWithKey:(NSString *)key;

- (NSDictionary *)objectWithKey:(NSString *)key;
- (NSDictionary *)objectAtIndex:(NSUInteger)index;

- (NSArray <NSDictionary *> *)filteredArrayUsingPredicate:(NSPredicate *)predicate;

@end
