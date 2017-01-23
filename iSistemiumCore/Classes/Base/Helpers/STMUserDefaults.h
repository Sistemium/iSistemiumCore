//
//  STMUserDefaults.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 26/07/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMUserDefaults : NSObject

+ (instancetype)standardUserDefaults;


- (NSArray *)arrayForKey:(NSString *)defaultName;
- (id)objectForKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;

- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;

- (void)removeObjectForKey:(NSString *)defaultName;

- (NSDictionary<NSString *,id> *)dictionaryRepresentation;

- (BOOL)synchronize;


@end
