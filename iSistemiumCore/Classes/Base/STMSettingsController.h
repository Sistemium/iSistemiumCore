//
//  STMSettingsController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 1/24/13.
//  Copyright (c) 2013 Maxim V. Grigoriev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <CoreLocation/CoreLocation.h>
#import "STMSessionManagement.h"
#import "STMDataModel.h"

@interface STMSettingsController : NSObject <STMSettingsController>

+ (STMSettingsController *)initWithSettings:(NSDictionary *)startSettings;

+ (NSString *)stringValueForSettings:(NSString *)settingsName forGroup:(NSString *)group;

- (NSDictionary *)defaultSettings;
- (NSArray *)currentSettings;
- (NSString *)normalizeValue:(NSString *)value forKey:(NSString *)key;
- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group;

- (NSMutableDictionary *)currentSettingsForGroup:(NSString *)group;

- (STMSetting *)settingForDictionary:(NSDictionary *)dictionary;

- (BOOL)isPositiveDouble:(NSString *)value;
- (BOOL)isBool:(NSString *)value;
- (BOOL)isValidTime:(NSString *)value;
- (BOOL)isValidURI:(NSString *)value;


@property (nonatomic, strong) NSMutableDictionary *startSettings;
@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic, strong) NSMutableArray *groupNames;

@end
