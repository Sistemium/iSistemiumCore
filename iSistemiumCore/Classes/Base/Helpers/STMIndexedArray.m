//
//  STMIndexedArray.m
//  iSisSales
//
//  Created by Alexander Levin on 04/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMIndexedArray.h"

@interface STMIndexedArray ()

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSNumber *> *primaryIndex;

@end

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
        
        if (!primaryKey) {
            primaryKey = [[NSUUID UUID] UUIDString].lowercaseString;
            NSMutableDictionary *anObjectCopy = anObject.mutableCopy;
            anObjectCopy[STM_INDEXED_ARRAY_PRIMARY_KEY] = primaryKey;
            anObject = anObjectCopy.copy;
        }
        
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
        if (!predicate) return _data.copy;
        return [_data filteredArrayUsingPredicate:predicate];
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
        NSString *pk = _data[index][STM_INDEXED_ARRAY_PRIMARY_KEY];
        [self.primaryIndex removeObjectForKey:pk];
        [_data removeObjectAtIndex:index];
    }
}

@end
