//
//  STMCoreSettingsController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 1/24/13.
//  Copyright (c) 2013 Maxim V. Grigoriev. All rights reserved.
//

#import "STMCoreController.h"
#import "STMSessionManagement.h"
#import "STMPersistingIntercepting.h"

@interface STMCoreSettingsController : STMCoreController <STMSettingsController,STMPersistingMergeInterceptor>

+ (instancetype)controllerWithSettings:(NSDictionary *)startSettings defaultSettings:(NSDictionary *)defaultSettings;

+ (NSString *)stringValueForSettings:(NSString *)settingsName forGroup:(NSString *)group;

- (id)normalizeValue:(id)value forKey:(NSString *)key;

- (BOOL)isPositiveDouble:(NSString *)value;
- (BOOL)isBool:(NSString *)value;
- (BOOL)isValidTime:(NSString *)value;
- (BOOL)isValidURI:(NSString *)value;

- (BOOL)key:(NSString *)key hasSuffixFromArray:(NSArray *)array;

@property (nonatomic, weak) id <STMSession> session;
@property (nonatomic, strong) NSArray *currentSettings;

@end
