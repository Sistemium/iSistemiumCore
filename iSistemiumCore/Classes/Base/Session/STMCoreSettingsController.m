//
//  STMCoreSettingsController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 1/24/13.
//  Copyright (c) 2013 Maxim V. Grigoriev. All rights reserved.
//

#import "STMCoreSettingsController.h"
#import "STMSetting.h"

@interface STMCoreSettingsController()

@property (nonatomic,strong) STMPersistingObservingSubscriptionID subscriptionId;
@property (nonatomic,strong) NSDictionary *defaultSettings;
@property (nonatomic,strong) NSMutableDictionary *startSettings;

@end


@implementation STMCoreSettingsController


#pragma mark - Initialization

+ (instancetype)controllerWithSettings:(NSDictionary *)startSettings defaultSettings:(NSDictionary *)defaultSettings {
    return [[self alloc] initWithSettings:startSettings defaultSettings:(NSDictionary *)defaultSettings];
}

+ (NSString *)stringValueForSettings:(NSString *)settingsName forGroup:(NSString *)group {
    
    return [[self session].settingsController currentSettingsForGroup:group][settingsName];
//    return [[self sharedInstance] currentSettingsForGroup:group][settingsName];
    
}

- (instancetype)initWithSettings:(NSDictionary *)startSettings defaultSettings:(NSDictionary *)defaultSettings{
    
    self = [self init];
    self.startSettings = startSettings.mutableCopy;
    self.defaultSettings = defaultSettings;
    
    return self;
}


- (void)dealloc {
    [self unsubscribeFromSettings];
    NSLogMethodName;
}

- (void)setSession:(id<STMSession>)session {
    
    [super setSession:session];
    
    [self checkSettings];
    
}

- (void)setPersistenceDelegate:(id)persistenceDelegate {
    
    if (self.persistenceDelegate) [self unsubscribeFromSettings];
    
    [super setPersistenceDelegate:persistenceDelegate];
    
    if (persistenceDelegate) {
        [self subscribeForSettings];
    }
    
}

#pragma mark - SettingsController protocol

- (NSArray *)currentSettings {
    
    if (!_currentSettings) [self reloadCurrentSettings];
    
    return _currentSettings;
    
}


- (NSArray *)groupNames {
    return [self.currentSettings valueForKeyPath:@"@distinctUnionOfObjects.group"];
}


- (NSDictionary *)currentSettingsForGroup:(NSString *)group {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.group == %@ AND name != nil AND value != nil", group];
    NSArray *groupSettings = [self.currentSettings filteredArrayUsingPredicate:predicate];
    
    return [NSDictionary dictionaryWithObjects:[groupSettings valueForKeyPath:@"value"]
                                       forKeys:[groupSettings valueForKeyPath:@"name"]];
    
}

- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group {
    
    for (NSString *settingName in newSettings.allKeys) {
        
        NSMutableDictionary *setting = [self settingWithName:settingName forGroup:group].mutableCopy;
        NSString *value = [self normalizeValue:newSettings[settingName] forKey:settingName];
        
        if (!value) {
            NSLog(@"wrong value %@ for setting %@", newSettings[settingName], settingName);
            continue;
        }
        
        if (!setting) {
            
            setting = @{@"group"    : group,
                        @"name"     : settingName}.mutableCopy;
            
        }
        
        setting[@"value"] = ([value isKindOfClass:[NSString class]]) ? value : [NSNull null];
        
        [self mergeSync:setting];

    }
    
    // subscription handler will reload currentSettings if there were any changes
    
    return @"";
    
}

#pragma mark - Public methods


- (id)normalizeValue:(id)value forKey:(NSString *)key {
    
    if ([value isKindOfClass:[NSString class]]) {
        
        NSArray *positiveDoubleValues = @[@"trackDetectionTime",
                                          @"trackSeparationDistance",
                                          @"fetchLimit",
                                          @"syncInterval",
                                          @"deviceMotionUpdateInterval",
                                          @"maxSpeedThreshold",
                                          @"http.timeout.foreground",
                                          @"http.timeout.background",
                                          @"objectsLifeTime",
                                          @"locationWaitingTimeInterval"];
        
        NSArray *zeroPositiveValues = @[@"timeFilter",
                                        @"requiredAccuracy",
                                        @"permanentLocationRequiredAccuracy"];
        
        NSArray *desiredAccuracySuffixes = @[@"DesiredAccuracy"];
        
        NSArray *boolValues = @[@"localAccessToSettings",
                                @"deviceMotionUpdate",
                                @"enableDownloadViaWWAN",
                                @"getLocationsWithNegativeSpeed",
                                @"blockIfNoLocationPermission"];
        
        NSArray *boolValueSuffixes = @[@"TrackerAutoStart"];
        
        NSArray *URIValues = @[@"restServerURI",
                               @"xmlNamespace",
                               @"recieveDataServerURI",
                               @"sendDataServerURI",
                               @"API.url",
                               @"socketUrl"];
        
        NSArray *timeValues = @[];
        NSArray *timeValueSuffixes = @[@"TrackerStartTime",
                                       @"TrackerFinishTime"];
        
        NSArray *stringValue = @[@"entityResource",
                                 @"uploadLog.type",
                                 @"geotrackerControl"];
        
        NSArray *logicValue = @[@"timeDistanceLogic"];
        
        if ([positiveDoubleValues containsObject:key]) {
            if ([self isPositiveDouble:value]) {
                return [NSString stringWithFormat:@"%f", [value doubleValue]];
            }
            
        } else  if ([boolValues containsObject:key] || [self key:key hasSuffixFromArray:boolValueSuffixes]) {
            if ([self isBool:value]) {
                return [NSString stringWithFormat:@"%d", [value boolValue]];
            }
            
        } else if ([URIValues containsObject:key]) {
            if ([self isValidURI:value]) {
                return value;
            }
            
        } else if ([timeValues containsObject:key] || [self key:key hasSuffixFromArray:timeValueSuffixes]) {
            if ([self isValidTime:value]) {
                return [NSString stringWithFormat:@"%f", [value doubleValue]];
            }
            
        } else if ([key isEqualToString:@"desiredAccuracy"] || [self key:key hasSuffixFromArray:desiredAccuracySuffixes]) {
            double dValue = [value doubleValue];
            if (dValue == -2 || dValue == -1 || dValue == 0 || dValue == 10 || dValue == 100 || dValue == 1000 || dValue == 3000) {
                return [NSString stringWithFormat:@"%f", dValue];
            }
            
        } else if ([key isEqualToString:@"distanceFilter"]) {
            double dValue = [value doubleValue];
            if (dValue == -1 || dValue >= 0) {
                return [NSString stringWithFormat:@"%f", dValue];
            }
            
        } else if ([zeroPositiveValues containsObject:key]) {
            double dValue = [value doubleValue];
            if (dValue >= 0) {
                return [NSString stringWithFormat:@"%f", dValue];
            }
            
        } else if ([key isEqualToString:@"jpgQuality"]) {
            double dValue = [value doubleValue];
            if (dValue >= 0 && dValue <= 1) {
                return [NSString stringWithFormat:@"%f", dValue];
            }
            
        } else if ([stringValue containsObject:key]) {
            return value;
            
        } else if ([logicValue containsObject:key]) {
            
            NSString *orValue = @"OR";
            NSString *andValue = @"AND";
            
            NSArray *availableValues = @[orValue, andValue];
            
            if ([availableValues containsObject:[(NSString *)value uppercaseString]]) {
                return [(NSString *)value uppercaseString];
            } else {
                return andValue;
            }
            
        } else if ([key isEqualToString:@"requestLocationServiceAuthorization"]) {
            
            NSArray *availableValues = @[@"noRequest", @"requestAlwaysAuthorization", @"requestWhenInUseAuthorization"];
            
            if ([availableValues containsObject:value]) {
                return value;
            } else {
                return @"noRequest";
            }
            
        }
        
        return nil;
        
    } else {
        
        return [NSNull null];
        
    }
    
}

- (BOOL)isPositiveDouble:(NSString *)value {
    return ([value doubleValue] > 0);
}

- (BOOL)isBool:(NSString *)value {
    double dValue = [value doubleValue];
    return (dValue == 0 || dValue == 1);
}

- (BOOL)isValidTime:(NSString *)value {
    double dValue = [value doubleValue];
    return (dValue >= 0 && dValue <= 24);
}

- (BOOL)isValidURI:(NSString *)value {
    return ([value hasPrefix:@"http://"] || [value hasPrefix:@"https://"]);
}

#pragma mark - Private helpers

- (BOOL)key:(NSString *)key hasSuffixFromArray:(NSArray *)array {
    
    BOOL result = NO;
    
    for (NSString *suffix in array) {
        result |= [key hasSuffix:suffix];
    }
    
    return result;
    
}

- (NSDictionary *)settingWithName:(NSString *)name forGroup:(NSString *)group {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@ && name == %@", group, name];
    NSDictionary *setting = [self.currentSettings filteredArrayUsingPredicate:predicate].lastObject;

    return setting;
    
}

- (void)checkSettings {
    
    NSDictionary *defaultSettings = [self defaultSettings];
    
    NSArray *currentSettings = self.currentSettings;
    
    for (NSString *settingsGroupName in defaultSettings.allKeys) {
        
        NSDictionary *settingsGroup = defaultSettings[settingsGroupName];
        
        for (NSString *settingName in settingsGroup.allKeys) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name == %@ AND SELF.group == %@", settingName, settingsGroupName];
            NSMutableDictionary *settingToCheck = [[currentSettings filteredArrayUsingPredicate:predicate].lastObject mutableCopy];

            id settingValue = settingsGroup[settingName];
            
            if ([self.startSettings.allKeys containsObject:settingName]) {
                
                id nValue = [self normalizeValue:self.startSettings[settingName] forKey:settingName];
                
                if (nValue) {
                    settingValue = ([nValue isKindOfClass:[NSString class]]) ? nValue : [NSNull null];
                } else {
                    NSLog(@"value %@ is not correct for %@", self.startSettings[settingName], settingName);
                    [self.startSettings removeObjectForKey:settingName];
                }
                
            }

            if (!settingToCheck) {

                id nValue = [self normalizeValue:settingValue forKey:settingName];
                nValue = ([nValue isKindOfClass:[NSString class]]) ? nValue : [NSNull null];

                NSDictionary *newSetting = @{@"group"   : settingsGroupName,
                                             @"name"    : settingName,
                                             @"value"   : nValue};
                
                [self mergeSync:newSetting];
                
            } else {
                
                id nValue = [self normalizeValue:settingToCheck[@"value"] forKey:settingName];
                
                nValue = [nValue isKindOfClass:[NSString class]] ? nValue : [NSNull null];

                settingToCheck[@"value"] = nValue;
                
                if ([self.startSettings.allKeys containsObject:settingName]) {
                    
                    if (![self value:nValue isEqual:settingValue]) {
                        
                        settingToCheck[@"value"] = settingValue;
                        
                        [self mergeSync:settingToCheck];

                    }
                    
                }
                
            }
            
        }
        
    }
    
    [self reloadCurrentSettings];
    
}

- (BOOL)value:(id)valueOne isEqual:(id)valueTwo {
    
    if ([self valueIsNSNull:valueOne] && [self valueIsNSNull:valueTwo]) {
        return YES;
    }
    
    if ([self valueIsNSString:valueOne] && [self valueIsNSString:valueTwo]) {
        return [valueOne isEqualToString:valueTwo];
    }
    
    return NO;
    
}

- (BOOL)valueIsNSNull:(id)value {
    return [value isKindOfClass:[NSNull class]];
}

- (BOOL)valueIsNSString:(id)value {
    return [value isKindOfClass:[NSString class]];
}

- (void)mergeSync:(NSDictionary *)setting {
    
    NSError *error = nil;
    [self.persistenceDelegate mergeSync:NSStringFromClass([STMSetting class])
                             attributes:setting
                                options:@{STMPersistingOptionLtsNow}
                                  error:&error];

}

- (void)reloadCurrentSettings {
    
    NSError *error = nil;
    _currentSettings = [self.persistenceDelegate findAllSync:NSStringFromClass([STMSetting class])
                                                   predicate:nil
                                                     options:nil
                                                       error:&error];
}

#pragma mark - Notifications of changes

- (void)subscribeForSettings {
    
    self.subscriptionId = [self.persistenceDelegate observeEntity:NSStringFromClass([STMSetting class]) predicate:nil callback:^(NSArray *theChangedData) {
        [self notifySubscribersFor:theChangedData];
    }];
    
}

- (void)notifySubscribersFor:(NSArray *)theChangedData {
    
    [self reloadCurrentSettings];
    
    for (NSDictionary *anObject in theChangedData) {
        
        NSString *notificationName = [anObject[@"group"] stringByAppendingString:STM_SESSION_SETTINGS_CHANGED];
        
        NSDictionary *userInfo = nil;
        
        if (anObject[@"value"] && anObject[@"name"]) {
            userInfo = @{anObject[@"name"]: anObject[@"value"]};
        }
        
        [self.session postAsyncMainQueueNotification:notificationName userInfo:userInfo];
        [self.session postAsyncMainQueueNotification:STM_SESSION_SETTINGS_CHANGED userInfo:@{@"changedObject": anObject}];

    }
    
}

- (void)unsubscribeFromSettings {
    if (!self.subscriptionId) return;
    [self.persistenceDelegate cancelSubscription:self.subscriptionId];
    self.subscriptionId = nil;
}

#pragma mark - PersistingMergeInterceptor protocol

- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    NSDictionary *setting = [self settingWithName:attributes[@"name"] forGroup:attributes[@"group"]];
    
    if (!setting) return attributes;
    
    return [STMFunctions setValue:setting[STMPersistingKeyPrimary] forKey:STMPersistingKeyPrimary inDictionary:attributes];
    
}

@end
