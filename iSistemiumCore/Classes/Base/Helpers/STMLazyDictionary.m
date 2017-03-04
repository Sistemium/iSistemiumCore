//
//  STMLazyDictionary.m
//  iSisSales
//
//  Created by Alexander Levin on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMLazyDictionary.h"

@interface STMLazyDictionary ()

@property (nonatomic, strong) NSMutableDictionary *privateData;
@property (nonatomic, strong) Class itemsClass;

@end


@implementation STMLazyDictionary

+ (instancetype)lazyDictionaryWithItemsClass:(Class)itemsClass {
    return [[self alloc] initWithItemsClass:itemsClass];
}

- (instancetype)init {
    self = [super init];
    self.privateData = [NSMutableDictionary dictionary];
    return self;
}

- (instancetype)initWithItemsClass:(Class)itemsClass {
    [self init].itemsClass = itemsClass;
    return self;
}

- (id)objectForKeyedSubscript:(id)key {
    
    id item = self.privateData[key];
    
    if (!item) {
        item = self.privateData[key] = [[self.itemsClass alloc] init];
    }
    
    return item;

}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    
    if (obj) {
        self.privateData[key] = obj;
    } else {
        [self removeObjectForKey:key];
    }
    
}

- (void)setObject:(id)anObject forKey:(id)aKey{
    self[aKey] = anObject;
}

- (void)removeObjectForKey:(NSString *)aKey {
    [self.privateData removeObjectForKey:aKey];
}

- (id)valueForKey:(NSString *)aKey {
    return self[aKey];
}

- (id)objectForKey:(NSString *)aKey {
    return self[aKey];
}

- (BOOL)hasKey:(id)aKey {
    return !!self.privateData[aKey];
}

- (NSArray *)allKeys {
    return self.privateData.allKeys;
}

@end
