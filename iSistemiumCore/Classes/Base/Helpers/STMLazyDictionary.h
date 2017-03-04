//
//  STMLazyDictionary.h
//  iSisSales
//
//  Created by Alexander Levin on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMLazyDictionary <KeyType,ObjectType> : NSObject

+ (instancetype)lazyDictionaryWithItemsClass:(Class)itemsClass;
- (instancetype)initWithItemsClass:(Class)itemsClass;

- (ObjectType)objectForKeyedSubscript:(KeyType)key;
- (void)setObject:(ObjectType)obj forKeyedSubscript:(KeyType)key;

- (id)objectForKey:(KeyType)aKey;
- (id)valueForKey:(KeyType)aKey;

- (void)setObject:(ObjectType)anObject forKey:(KeyType)aKey;
- (void)removeObjectForKey:(KeyType)aKey;

- (BOOL)hasKey:(KeyType)aKey;

@property(readonly, copy) NSArray <KeyType> *allKeys;

@end
