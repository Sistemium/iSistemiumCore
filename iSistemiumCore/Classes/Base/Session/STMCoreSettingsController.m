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

@property (nonatomic, strong) NSFetchedResultsController *fetchedSettingsResultController;
@property (nonatomic, weak) id <STMPersistingSync, STMPersistingAsync> persistenceDelegate;

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

        NSMutableArray *groupNames = [NSMutableArray array];
        
        for (id <NSFetchedResultsSectionInfo> sectionInfo in self.fetchedSettingsResultController.sections) {
            
            [groupNames addObject:[sectionInfo name]];

        }
        
        _groupNames = groupNames;
        
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

- (void)setSession:(id<STMSession>)session {
    
    _session = session;
    
    self.persistenceDelegate = session.persistenceDelegate;

    NSError *error;
    if (![self.fetchedSettingsResultController performFetch:&error]) {
        
        NSLog(@"settingsController performFetch error %@", error);
        
    } else {
        
        [self checkSettings];
//        [self NSLogSettings];
        
    }
    
}

- (NSFetchedResultsController *)fetchedSettingsResultController {
    
    if (!_fetchedSettingsResultController) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMSetting class])];

        NSSortDescriptor *groupSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"group"
                                                                              ascending:YES
                                                                               selector:@selector(caseInsensitiveCompare:)];
        
        NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name"
                                                                             ascending:YES
                                                                              selector:@selector(caseInsensitiveCompare:)];

        request.sortDescriptors = @[groupSortDescriptor, nameSortDescriptor];
        
        _fetchedSettingsResultController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                               managedObjectContext:self.session.document.managedObjectContext
                                                                                 sectionNameKeyPath:@"group"
                                                                                          cacheName:nil];
        _fetchedSettingsResultController.delegate = self;
        
    }
    
    return _fetchedSettingsResultController;
    
}

- (void)NSLogSettings {

#ifdef DEBUG
//    NSLog(@"self.currentSettings %@", self.currentSettings);
    
    for (NSDictionary *setting in [self currentSettings]) {
        
        NSLog(@"setting %@", setting);
        
    }
#endif
}

- (NSArray *)currentSettings {
    
    NSError *error = nil;
    NSArray *currentSettings = [self.persistenceDelegate findAllSync:NSStringFromClass([STMSetting class])
                                                           predicate:nil
                                                             options:nil
                                                               error:&error];
    
    return currentSettings;
    
}

- (NSMutableDictionary *)currentSettingsForGroup:(NSString *)group {
    
    NSMutableDictionary *settingsDictionary = [NSMutableDictionary dictionary];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.group == %@", group];
    NSArray *groupSettings = [[self currentSettings] filteredArrayUsingPredicate:predicate];
    
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

//- (STMSetting *)settingForDictionary:(NSDictionary *)dictionary {
//    
//    NSString *settingName = dictionary[@"name"];
//    NSString *settingGroup = dictionary[@"group"];
//    
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@ AND group == %@", settingName, settingGroup];
//    
//    NSArray *result = [self.fetchedSettingsResultController.fetchedObjects filteredArrayUsingPredicate:predicate];
//    
//    STMSetting *setting = [result lastObject];
//    
//    if (result.count > 1) {
//        
//        NSLog(@"More than one setting with name %@ and group %@, get lastObject", settingName, settingGroup);
//        NSLog(@"remove all other setting objects with name %@ and group %@", settingName, settingGroup);
//        
//        predicate = [NSPredicate predicateWithFormat:@"SELF != %@", setting];
//        result = [result filteredArrayUsingPredicate:predicate];
//        NSError *error;
//        
//        for (STMSetting *settingObject in result) {
//            [self.persistenceDelegate destroySync:@"STMSetting" identifier:[STMFunctions hexStringFromData:settingObject.xid] options:nil error:&error];
//        }
//        
//    }
//    
//    return setting;
//    
//}

- (void)checkSettings {
    
    NSDictionary *defaultSettings = [self defaultSettings];
    //        NSLog(@"defaultSettings %@", defaultSettings);
    
    NSArray *currentSettings = [self currentSettings];
    
    for (NSString *settingsGroupName in defaultSettings.allKeys) {
        //            NSLog(@"settingsGroup %@", settingsGroupName);
        
        NSDictionary *settingsGroup = defaultSettings[settingsGroupName];
        
        for (NSString *settingName in settingsGroup.allKeys) {
            //                NSLog(@"setting %@ %@", settingName, [settingsGroup valueForKey:settingName]);
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name == %@ AND SELF.group == %@", settingName, settingsGroupName];
            NSMutableDictionary *settingToCheck = [currentSettings filteredArrayUsingPredicate:predicate].lastObject;

            NSString *settingValue = [settingsGroup valueForKey:settingName];
            
            if ([self.startSettings.allKeys containsObject:settingName]) {
                
                id nValue = [self normalizeValue:self.startSettings[settingName] forKey:settingName];
                
                if (nValue) {
                    settingValue = ([nValue isKindOfClass:[NSString class]]) ? nValue : nil;
                } else {
                    NSLog(@"value %@ is not correct for %@", self.startSettings[settingName], settingName);
                    [self.startSettings removeObjectForKey:settingName];
                }
                
            }

            if (!settingToCheck) {

                id nValue = [self normalizeValue:settingValue forKey:settingName];
                id value = ([nValue isKindOfClass:[NSString class]]) ? nValue : [NSNull null];

                NSDictionary *newSetting = @{@"group"   : settingsGroupName,
                                             @"name"    : settingName,
                                             @"value"   : value};
                
                NSError *error = nil;
                [self.persistenceDelegate mergeSync:NSStringFromClass([STMSetting class])
                                         attributes:newSetting
                                            options:nil
                                              error:&error];

//                [self.persistenceDelegate mergeAsync:NSStringFromClass([STMSetting class])
//                                          attributes:newSetting
//                                             options:nil
//                                   completionHandler:nil];
                
            } else {
                
                id nValue = [self normalizeValue:settingToCheck[@"value"] forKey:settingName];

                settingToCheck[@"value"] = ([nValue isKindOfClass:[NSString class]]) ? nValue : [NSNull null];
                
                if ([[self.startSettings allKeys] containsObject:settingName]) {
                    
                    if (![settingToCheck[@"value"] isEqualToString:settingValue]) {
                        settingToCheck[@"value"] = settingValue;
                    }
                    
                }
                
            }
            
        }
        
    }
    
    [[(STMCoreSession *)self.session document] saveDocument:^(BOOL success) {
        if (success) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"settingsLoadComplete" object:self];
        }
    }];

}

- (NSString *)setNewSettings:(NSDictionary *)newSettings forGroup:(NSString *)group {

    NSArray *currentSettings = [self currentSettings];
    
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
            
            NSError *error = nil;
            
            [self.persistenceDelegate mergeSync:NSStringFromClass([STMSetting class])
                                     attributes:setting
                                        options:nil
                                          error:&error];
            
//            [self.persistenceDelegate mergeAsync:NSStringFromClass([STMSetting class])
//                                      attributes:setting
//                                         options:nil
//                               completionHandler:nil];
            
        } else {
            
            NSLog(@"wrong value %@ for setting %@", newSettings[settingName], settingName);
            
        }
        
    }

    return @"";
    
}


#pragma mark - NSFetchedResultsController delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
//    NSLog(@"controllerWillChangeContent");
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
//    NSLog(@"controllerDidChangeContent");
    
    self.groupNames = nil;
    
    [[(STMCoreSession *)self.session document] saveDocument:^(BOOL success) {
        if (success) {
            NSLog(@"save settings success");
        }
    }];
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    if ([anObject isKindOfClass:[STMSetting class]]) {
        
//        NSLog(@"anObject %@", anObject);
        
        NSString *notificationName = [NSString stringWithFormat:@"%@SettingsChanged", [anObject valueForKey:@"group"]];
        
        NSDictionary *userInfo = nil;
        
        if ([anObject valueForKey:@"value"]) {
            userInfo = @{[anObject valueForKey:@"name"]: [anObject valueForKey:@"value"]};
        }
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc postNotificationName:notificationName
                          object:self.session
                        userInfo:userInfo];
        
        [nc postNotificationName:@"settingsChanged"
                          object:self.session
                        userInfo:@{@"changedObject": anObject}];
        
    }
        
    if (type == NSFetchedResultsChangeDelete) {
        
//        NSLog(@"NSFetchedResultsChangeDelete");
        
    } else if (type == NSFetchedResultsChangeInsert) {
        
//        NSLog(@"NSFetchedResultsChangeInsert");
        
    } else if (type == NSFetchedResultsChangeUpdate) {
        
//        NSLog(@"NSFetchedResultsChangeUpdate");
        
    }
    
}


@end
