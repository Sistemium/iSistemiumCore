//
//  STMCoreUserDefaults.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 16/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMCoreUserDefaults

- (NSArray *)arrayForKey:(NSString *)defaultName;

- (id)objectForKey:(NSString *)defaultName;

- (BOOL)boolForKey:(NSString *)defaultName;

- (NSInteger)integerForKey:(NSString *)defaultName;

- (void)setObject:(id)value forKey:(NSString *)defaultName;

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;

- (void)removeObjectForKey:(NSString *)defaultName;

- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

- (BOOL)synchronize;

@end
