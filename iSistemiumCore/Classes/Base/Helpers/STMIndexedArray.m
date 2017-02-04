//
//  STMIndexedArray.m
//  iSisSales
//
//  Created by Alexander Levin on 04/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMIndexedArray.h"

@implementation STMIndexedArray {
    // What's the difference between this declaration and private property?
    NSMutableArray <NSDictionary *> *_data;
}


+ (instancetype)array {
    return [[self.class alloc] init];
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

- (void)addObject:(NSDictionary*)anObject {
    @synchronized (self) {
        NSString *primaryKey = anObject[STM_INDEXED_ARRAY_PRIMARY_KEY];
        NSNumber *index = self.primaryIndex[primaryKey];
        if (!index) {
            [_data addObject:anObject];
            self.primaryIndex[primaryKey] = @(_data.count - 1);
        } else {
            _data[index.integerValue] = anObject;
        }
    }
}

- (void)addObjectsFromArray:(NSArray <NSDictionary*> *)array {
    @synchronized (self) {
        [array enumerateObjectsUsingBlock:^(NSDictionary * obj, NSUInteger idx, BOOL * stop) {
            [self addObject:obj];
        }];
    }
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    @synchronized (self) {
        NSString *pk = _data[index][STM_INDEXED_ARRAY_PRIMARY_KEY];
        [self.primaryIndex removeObjectForKey:pk];
        [_data removeObjectAtIndex:index];
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
        return [_data filteredArrayUsingPredicate:predicate];
    }
}

- (NSDictionary *)objectAtIndex:(NSUInteger)index {
    @synchronized (self) {
        return _data[index];
    }
}

@end
