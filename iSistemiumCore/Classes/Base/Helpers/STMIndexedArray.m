//
//  STMIndexedArray.m
//  iSisSales
//
//  Created by Alexander Levin on 04/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMIndexedArray.h"

@interface STMIndexedArray ()

@property(nonatomic, strong) NSString *primaryKey;
@property(nonatomic, strong) NSMutableDictionary <NSString *, NSNumber *> *primaryIndex;

@end

@implementation STMIndexedArray {
    // What's the difference between this declaration and private property?
    NSMutableArray <NSDictionary *> *_data;
}

+ (instancetype)array {
    return [self.class arrayWithPrimaryKey:STM_INDEXED_ARRAY_DEFAULT_PRIMARY_KEY];
}

+ (instancetype)arrayWithPrimaryKey:(NSString *)key {
    STMIndexedArray *instance = [[self.class alloc] init];
    instance.primaryKey = key;
    return instance;
}

- (instancetype)init {
    _data = [NSMutableArray array];
    _primaryIndex = [NSMutableDictionary dictionary];
    return [super init];
}

- (NSDictionary *)primaryIndex {
    @synchronized (self) {
        if (!_primaryIndex) _primaryIndex = [NSMutableDictionary dictionary];
        return _primaryIndex;
    }
}

- (NSString *)primaryKey {
    if (!_primaryKey) {
        _primaryKey = STM_INDEXED_ARRAY_DEFAULT_PRIMARY_KEY;
    }
    return _primaryKey;
}

- (NSDictionary *)addObject:(NSDictionary *)anObject {
    @synchronized (self) {

        NSString *primaryKey = anObject[self.primaryKey];

        if (!primaryKey) {
            primaryKey = [[NSUUID UUID] UUIDString].lowercaseString;
            NSMutableDictionary *anObjectCopy = anObject.mutableCopy;
            anObjectCopy[self.primaryKey] = primaryKey;
            anObject = anObjectCopy.copy;
        }

        NSNumber *index = self.primaryIndex[primaryKey];

        if (!index) {
            [_data addObject:anObject];
            self.primaryIndex[primaryKey] = @(_data.count - 1);
        } else {
            _data[index.integerValue] = anObject;
        }

        return anObject;

    }
}

- (NSArray <NSDictionary *> *)addObjectsFromArray:(NSArray <NSDictionary *> *)array {
    @synchronized (self) {
        NSMutableArray <NSDictionary *> *result = [NSMutableArray array];
        [array enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            [result addObject:[self addObject:obj]];
        }];
        return result.copy;
    }
}

- (BOOL)removeObjectWithKey:(NSString *)key {
    @synchronized (self) {
        NSNumber *index = self.primaryIndex[key];
        if (!index) return NO;
        [self removeObjectAtIndex:index.integerValue];
        return YES;
    }
}

- (NSDictionary *)objectWithKey:(NSString *)identifier {
    @synchronized (self) {
        NSNumber *index = self.primaryIndex[identifier];
        return index ? [_data objectAtIndex:index.integerValue] : nil;
    }
}

- (NSArray <NSDictionary *> *)filteredArrayUsingPredicate:(NSPredicate *)predicate {
    @synchronized (self) {

        NSMutableArray *predicates = [NSMutableArray arrayWithObject:[NSPredicate predicateWithFormat:@"id != nil"]];

        if (predicate) [predicates addObject:predicate];

        NSCompoundPredicate *predicateWithNotDeleted = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];

        return [_data filteredArrayUsingPredicate:predicateWithNotDeleted];
    }
}

- (NSDictionary *)objectAtIndex:(NSUInteger)index {
    @synchronized (self) {
        return _data[index];
    }
}


#pragma mark - Private

- (void)removeObjectAtIndex:(NSUInteger)index {
    @synchronized (self) {
        NSString *pk = _data[index][self.primaryKey];
        [self.primaryIndex removeObjectForKey:pk];
        _data[index] = @{};
    }
}

@end
