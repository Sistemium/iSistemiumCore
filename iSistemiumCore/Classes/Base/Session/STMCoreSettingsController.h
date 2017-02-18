//
//  STMCoreSettingsController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 1/24/13.
//  Copyright (c) 2013 Maxim V. Grigoriev. All rights reserved.
//

#import "STMCoreController.h"

#import <CoreData/CoreData.h>
#import <CoreLocation/CoreLocation.h>
#import "STMSessionManagement.h"
#import "STMCoreDataModel.h"

#import "STMPersistingIntercepting.h"

@interface STMCoreSettingsController : STMCoreController <STMSettingsController,STMPersistingMergeInterceptor>

+ (STMCoreSettingsController *)initWithSettings:(NSDictionary *)startSettings;

+ (NSString *)stringValueForSettings:(NSString *)settingsName forGroup:(NSString *)group;

- (NSDictionary *)defaultSettings;
- (NSString *)normalizeValue:(NSString *)value forKey:(NSString *)key;

- (BOOL)isPositiveDouble:(NSString *)value;
- (BOOL)isBool:(NSString *)value;
- (BOOL)isValidTime:(NSString *)value;
- (BOOL)isValidURI:(NSString *)value;

- (BOOL)key:(NSString *)key hasSuffixFromArray:(NSArray *)array;

@property (nonatomic, strong) NSMutableDictionary *startSettings;
@property (nonatomic, weak) id <STMSession> session;
@property (nonatomic, strong) NSMutableArray *groupNames;
@property (nonatomic, strong) NSArray *currentSettings;

@end
