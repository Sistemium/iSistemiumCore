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

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSNumber *> *primaryIndex;

- (void)addObject:(NSDictionary*)anObject;
- (void)addObjectsFromArray:(NSArray <NSDictionary*> *)array;

- (void)removeObjectAtIndex:(NSUInteger)index;

- (NSDictionary *)objectWithKey:(NSString *)idettifier;
- (NSDictionary *)objectAtIndex:(NSUInteger)index;

- (NSArray <NSDictionary *> *)filteredArrayUsingPredicate:(NSPredicate *)predicate;


@end
