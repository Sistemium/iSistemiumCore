//
//  STMClientDataController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <AdSupport/AdSupport.h>
#import "STMCoreAuthController.h"
#import "STMCoreAppDelegate.h"

#import "STMKeychain.h"

#import "STMCoreAppDelegate.h"
#import "STMClientDataController.h"
#import "STMClientData.h"
#import "STMCoreAuthController.h"
#import "STMSetting.h"
#import "STMFunctions.h"
#import "STMCoreObjectsController.h"
#import "STMCoreSession.h"

#define DEVICE_UUID_KEY @"deviceUUID"


@implementation STMClientDataController


+ (STMCoreAppDelegate *)appDelegate {
    return (STMCoreAppDelegate *)[UIApplication sharedApplication].delegate;
}

#pragma mark - clientData properties

+ (NSString *)bundleIdentifier {
    return BUNDLE_DISPLAY_NAME;
}

+ (NSString *)appVersion {
    return [self persistenceDelegate].modelVersion;
}

+ (NSString *)bundleVersion {
    return APP_VERSION;
}


+ (NSString *)buildType {
    
#ifdef DEBUG
    return @"debug";
#else
    return @"release";
#endif
    
}

+ (NSString *)deviceName {
    if (@available(iOS 16, *)) {
        @throw [NSException exceptionWithName:@"UnsupportedVersionException"
                                       reason:@"UIDevice name not supported for iOS 16 or greater"
                                     userInfo:nil];
    } else {
        return [[UIDevice currentDevice] name];
    }
}

+ (NSString *)deviceToken {
    return [STMFunctions hexStringFromData:[self appDelegate].deviceToken];
}

+(NSString *)deviceTokenError {
    return [self appDelegate].deviceTokenError;
}

+ (NSString *)lastAuth {
    return [STMFunctions stringFromDate:[STMCoreAuthController sharedAuthController].lastAuth];
}

+ (NSString *)locationServiceStatus {
    return [(STMCoreSession *)self.session locationTracker].locationServiceStatus;
}

+ (NSString *)tokenHash {
    return [STMCoreAuthController sharedAuthController].tokenHash;
}

+ (NSString *)notificationTypes {
    return [[self appDelegate] currentNotificationTypes];
}

+ (NSString *)devicePlatform {
    return [STMFunctions devicePlatform];
}

+ (NSString *)systemVersion {
    return [UIDevice currentDevice].systemVersion;
}

+ (NSString *)deviceUUID {
    
    NSData *deviceUUID = [STMKeychain loadValueForKey:DEVICE_UUID_KEY];
    
    if (!deviceUUID || deviceUUID.length == 0) {
        
        NSUUID *advertisingIdentifier = [ASIdentifierManager sharedManager].advertisingIdentifier;
        
        if ([advertisingIdentifier.UUIDString isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
            
            NSUUID *identifierForVendor = [UIDevice currentDevice].identifierForVendor;
            deviceUUID = [STMFunctions UUIDDataFromNSUUID:identifierForVendor];

        } else {
            
            deviceUUID = [STMFunctions UUIDDataFromNSUUID:advertisingIdentifier];

        }
        
        [STMKeychain saveValue:deviceUUID forKey:DEVICE_UUID_KEY];
        
    }
    
    return [STMFunctions UUIDStringFromUUIDData:deviceUUID].uppercaseString;

}

+ (NSNumber *)freeDiskSpace {
    
    uint64_t freeSpace = [STMFunctions freeDiskspace];
    
    freeSpace = ((freeSpace/1024ll)/1024ll); // freeSpace in MiB
    
    freeSpace = (freeSpace / FREE_SPACE_PRECISION_MiB) * FREE_SPACE_PRECISION_MiB;
    
    if (freeSpace < FREE_SPACE_THRESHOLD) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"lowFreeDiskSpace" object:@(FREE_SPACE_THRESHOLD)];
        
    }
    
    return @(freeSpace);
    
}

#pragma mark - remote


+ (void)setDeviceNameRemote:(NSString *)name {
    
    NSMutableDictionary *clientData = [self clientData].mutableCopy;
    
    if (!clientData) {
        return;
    }
    
    NSString *entityName = NSStringFromClass([STMClientData class]);
    
    clientData[@"deviceName"] = name;
    
    [[self persistenceDelegate] mergeAsync:entityName
                                attributes:clientData
                                   options:nil
                         completionHandler:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"flutter invokeMethod setDeviceName");
        FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
        [channel invokeMethod:@"setDeviceName" arguments: name];
    });
}

#pragma mark - checking client state

+ (void)checkClientData {

    NSMutableDictionary *clientData = [self clientData].mutableCopy;
    
    if (!clientData) {
        return;
    }

    NSString *entityName = NSStringFromClass([STMClientData class]);
    
    NSSet *keys = [[self persistenceDelegate] ownObjectKeysForEntityName:entityName];
    
    BOOL haveUpdates = NO;
    
    for (NSString *key in keys) {
        
        SEL selector = NSSelectorFromString(key);
        
        if (![self respondsToSelector:selector]) {
            continue;
        }
            
        @try {
            // next 3 lines — implementation of id value = [self performSelector:selector] w/o warning
            IMP imp = [self methodForSelector:selector];
            id (*func)(id, SEL) = (void *)imp;
            id currentValue = func(self, selector);

            id storedValue = clientData[key];

            if ([currentValue isEqual:storedValue]) {
                continue;
            }

            if ([STMFunctions isNullBoth:currentValue and:storedValue]) {
                continue;
            }

            clientData[key] = currentValue;
            haveUpdates = YES;
        }
        @catch (NSException *exception) {
            NSLog(@"Exception occurred: %@, %@", exception.name, exception.reason);
        }
        
    }
    
    if (haveUpdates) {

        [[self persistenceDelegate] mergeAsync:entityName
                                    attributes:clientData
                                       options:nil
                             completionHandler:nil];

    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"flutter invokeMethod setDeviceName");
        FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
        [channel invokeMethod:@"setDeviceName" arguments: clientData[@"deviceName"]];
    });

}

+ (NSDictionary *)clientData {

    NSString *entityName = NSStringFromClass([STMClientData class]);
    
    NSError *error = nil;
    NSArray *fetchResult = [[self persistenceDelegate] findAllSync:entityName
                                                         predicate:nil
                                                           options:nil
                                                             error:&error];;
    NSDictionary *clientData = fetchResult.lastObject;
    
    if (!clientData) clientData = @{};
    
    return clientData;
    
}

+ (void)checkAppVersion {

    NSMutableDictionary *clientData = [self clientData].mutableCopy;
    
    if (!clientData) {
        return;
    }
    
    NSString *appVersion = [self appVersion];
    
    if (![clientData[@"appVersion"] isEqualToString:appVersion]) {
        
        clientData[@"appVersion"] = appVersion;
        
        [[self persistenceDelegate] mergeAsync:NSStringFromClass([STMClientData class])
                                    attributes:clientData
                                       options:nil
                             completionHandler:nil];
        
    }
    
    NSString *entityName = NSStringFromClass([STMSetting class]);
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"availableVersion"];
    
    [[self persistenceDelegate] findAllAsync:entityName predicate:predicate options:nil completionHandler:^(BOOL success, NSArray<NSDictionary *> *result, NSError *error) {
            
        NSDictionary *availableVersionSetting = result.lastObject;
        
        if (!availableVersionSetting) {
            return;
        }
            
        NSNumber *availableVersion = @([availableVersionSetting[@"value"] integerValue]);
        NSNumber *currentVersion = @([clientData[@"appVersion"] integerValue]);
        
        [self compareAvailableVersion:availableVersion withCurrentVersion:currentVersion];
        
    }];

    
}

+ (void)compareAvailableVersion:(NSNumber *)availableVersion withCurrentVersion:(NSNumber *)currentVersion {
    
    if ([availableVersion compare:currentVersion] == NSOrderedDescending) {
        
        NSString *entityName = NSStringFromClass([STMSetting class]);
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"appDownloadUrl"];
        
        [[self persistenceDelegate] findAllAsync:entityName predicate:predicate options:nil completionHandler:^(BOOL success, NSArray<NSDictionary *> *result, NSError *error) {
           
            NSDictionary *appDownloadUrlSetting = result.lastObject;
            
            if (appDownloadUrlSetting) {
                
                [self.userDefaults setObject:@YES forKey:@"newAppVersionAvailable"];
                [self.userDefaults setObject:availableVersion forKey:@"availableVersion"];
                [self.userDefaults setObject:appDownloadUrlSetting[@"value"] forKey:@"appDownloadUrl"];
                [self.userDefaults synchronize];
                
                NSDictionary *userInfo = @{@"availableVersion"  : availableVersion,
                                           @"appDownloadUrl"    : appDownloadUrlSetting[@"value"]};
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NEW_VERSION_AVAILABLE
                                                                    object:nil
                                                                  userInfo:userInfo];
                
            }
            
        }];
        
    } else {
        
        [self.userDefaults setObject:@NO forKey:@"newAppVersionAvailable"];
        [self.userDefaults removeObjectForKey:@"availableVersion"];
        [self.userDefaults removeObjectForKey:@"appDownloadUrl"];
        [self.userDefaults synchronize];
        
    }

}


@end
