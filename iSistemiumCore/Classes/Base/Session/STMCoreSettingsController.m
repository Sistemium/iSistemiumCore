//
//  STMCoreSettingsController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 1/24/13.
//  Copyright (c) 2013 Maxim V. Grigoriev. All rights reserved.
//

#import "STMCoreSettingsController.h"
#import "STMCoreSession.h"
#import "STMSettingsData.h"
#import "STMEntityDescription.h"
#import "STMCoreObjectsController.h"
#import "STMCoreSessionManager.h"


@interface STMCoreSettingsController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, weak) id <STMPersistingSync, STMPersistingAsync, STMPersistingObserving> persistenceDelegate;
@property (nonatomic, strong) STMPersistingObservingSubscriptionID subscriptionId;

@end


@implementation STMCoreSettingsController


#pragma mark - class methods

+ (STMCoreSettingsController *)initWithSettings:(NSDictionary *)startSettings {
    
    STMCoreSettingsController *settingsController = [[self alloc] init];
    settingsController.startSettings = [startSettings mutableCopy];
    return settingsController;
    
}

- (NSDictionary *)defaultSettings {
    return  self.session.defaultSettings;
}

- (NSMutableArray *)groupNames {
    
    if (!_groupNames) {
        _groupNames = [self.currentSettings valueForKeyPath:@"@distinctUnionOfObjects.group"];
    }
    
    return _groupNames;
    
}

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
        
        NSArray *URIValues = @[@"xmlNamespace",
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

- (BOOL)key:(NSString *)key hasSuffixFromArray:(NSArray *)array {
    
    BOOL result = NO;
    
    for (NSString *suffix in array) {
        result |= [key hasSuffix:suffix];
    }
    
    return result;
    
}


#pragma mark - instance methods

- (void)dealloc {
    [self unsubscribeFromSettings];
    NSLog(@"dealloc settings");
}

- (void)setSession:(id<STMSession>)session {
    
    _session = session;
    
    self.persistenceDelegate = session.persistenceDelegate;
    
    [self unsubscribeFromSettings];

    if (!session) {
        NSLog(@"empty session");
        return;
    }
    
    [self subscribeForSettings];
    [self checkSettings];
    
}

- (void)unsubscribeFromSettings {
    if (!self.subscriptionId) return;
    NSLog(@"subscriptionId: %@", self.subscriptionId);
    [self.persistenceDelegate cancelSubscription:self.subscriptionId];
    self.subscriptionId = nil;
}

- (void)NSLogSettings {

#ifdef DEBUG
//    NSLog(@"self.currentSettings %@", self.currentSettings);
    
    for (NSDictionary *setting in self.currentSettings) {
        
        NSLog(@"setting %@", setting);
        
    }
#endif
}

- (NSArray *)currentSettings {
    
    if (!_currentSettings) {
    
        NSError *error = nil;
        NSArray *currentSettings = [self.persistenceDelegate findAllSync:NSStringFromClass([STMSetting class])
                                                               predicate:nil
                                                                 options:nil
                                                                   error:&error];
        
        _currentSettings = currentSettings;

    }
    return _currentSettings;
    
}

- (NSMutableDictionary *)currentSettingsForGroup:(NSString *)group {
    
    NSMutableDictionary *settingsDictionary = [NSMutableDictionary dictionary];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.group == %@", group];
    NSArray *groupSettings = [self.currentSettings filteredArrayUsingPredicate:predicate];
    
    for (NSDictionary *setting in groupSettings) {
        if (setting[@"name"] && setting[@"value"]) settingsDictionary[setting[@"name"]] = setting[@"value"];
    }
    
    return settingsDictionary;
    
}

+ (NSString *)stringValueForSettings:(NSString *)settingsName forGroup:(NSString *)group {
    
    STMCoreSession *currentSession = [STMCoreSessionManager sharedManager].currentSession;
    STMCoreSettingsController *currentController = currentSession.settingsController;
    
    NSDictionary *settingsGroup = [currentController currentSettingsForGroup:group];
    
    NSString *value = settingsGroup[settingsName];
    
    return value;
    
}

+ (NSDictionary *)settingWithName:(NSString *)name forGroup:(NSString *)group {
    
    STMCoreSession *currentSession = [STMCoreSessionManager sharedManager].currentSession;
    STMCoreSettingsController *currentController = currentSession.settingsController;

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@ && name == %@", group, name];
    NSDictionary *setting = [currentController.currentSettings filteredArrayUsingPredicate:predicate].lastObject;

    return setting;
    
}

- (void)checkSettings {
    
    NSDictionary *defaultSettings = [self defaultSettings];
    //        NSLog(@"defaultSettings %@", defaultSettings);
    
    NSArray *currentSettings = self.currentSettings;
    
    for (NSString *settingsGroupName in defaultSettings.allKeys) {
        //            NSLog(@"settingsGroup %@", settingsGroupName);
        
        NSDictionary *settingsGroup = defaultSettings[settingsGroupName];
        
        for (NSString *settingName in settingsGroup.allKeys) {
            //                NSLog(@"setting %@ %@", settingName, [settingsGroup valueForKey:settingName]);
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name == %@ AND SELF.group == %@", settingName, settingsGroupName];
            NSMutableDictionary *settingToCheck = [currentSettings filteredArrayUsingPredicate:predicate].lastObject;

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
    
    self.currentSettings = nil;

    [[NSNotificationCenter defaultCenter] postNotificationName:@"settingsLoadComplete"
                                                        object:self];

}

- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group {

    NSArray *currentSettings = self.currentSettings;
    
    for (NSString *settingName in newSettings.allKeys) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.group == %@ && SELF.name == %@", group, settingName];
        NSMutableDictionary *setting = [currentSettings filteredArrayUsingPredicate:predicate].lastObject;
        NSString *value = [self normalizeValue:newSettings[settingName] forKey:settingName];
        
        if (value) {
            
            if (!setting) {
                
                setting = @{@"group"    : group,
                            @"name"     : settingName}.mutableCopy;
                
            }
            
            setting[@"value"] = ([value isKindOfClass:[NSString class]]) ? value : [NSNull null];
            
            [self mergeSync:setting];
            
        } else {
            
            NSLog(@"wrong value %@ for setting %@", newSettings[settingName], settingName);
            
        }
        
    }

    self.currentSettings = nil;

    return @"";
    
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
                                options:@{STMPersistingOptionLts : [STMFunctions stringFromNow]}
                                  error:&error];

}


#pragma mark - subscribing

- (void)subscribeForSettings {
    
    self.subscriptionId = [self.persistenceDelegate observeEntity:NSStringFromClass([STMSetting class]) predicate:nil callback:^(NSArray * data) {
        [self getSubscribedData:data];
    }];
    
}

- (void)getSubscribedData:(NSArray *)data {
    
    for (NSDictionary *anObject in data) {
        [self getSubscribedObject:anObject];
    }
    
    self.groupNames = nil;
    self.currentSettings = nil;
    
}

- (void)getSubscribedObject:(NSDictionary *)anObject {
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        NSString *notificationName = [NSString stringWithFormat:@"%@SettingsChanged", anObject[@"group"]];
        
        NSDictionary *userInfo = nil;
        
        if (anObject[@"value"] && anObject[@"name"]) {
            userInfo = @{anObject[@"name"]: anObject[@"value"]};
        }

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc postNotificationName:notificationName
                          object:self.session
                        userInfo:userInfo];
        
        [nc postNotificationName:@"settingsChanged"
                          object:self.session
                        userInfo:@{@"changedObject": anObject}];

    });
    
}


@end
