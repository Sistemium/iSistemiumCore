//
//  STMLazyDictionary.h
//  iSisSales
//
//  Created by Alexander Levin on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMLazyDictionary : NSObject

+ (instancetype)lazyDictionaryWithItemsClass:(Class)itemsClass;

- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

- (id)objectForKey:(NSString *)aKey;
- (id)valueForKey:(NSString *)aKey;

- (void)setObject:(id)anObject forKey:(NSString *)aKey;
- (void)removeObjectForKey:(NSString *)aKey;

- (BOOL)hasKey:(NSString *)aKey;

@property(readonly, copy) NSArray <NSString *> *allKeys;

@end
