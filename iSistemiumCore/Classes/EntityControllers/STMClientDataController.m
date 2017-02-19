//
//  STMClientDataController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <AdSupport/AdSupport.h>

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
    return BUILD_VERSION;
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
    return [[UIDevice currentDevice] name];
}

+ (NSData *)deviceToken {
    return [self appDelegate].deviceToken;
}

+(NSString *)deviceTokenError {
    return [self appDelegate].deviceTokenError;
}

+ (NSDate *)lastAuth {
    return [STMCoreAuthController authController].lastAuth;
}

+ (NSString *)locationServiceStatus {
    return [(STMCoreSession *)self.session locationTracker].locationServiceStatus;
}

+ (NSString *)tokenHash {
    return [STMCoreAuthController authController].tokenHash;
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

+ (NSData *)deviceUUID {
    
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
    
    return deviceUUID;

}

+ (NSString *)deviceUUIDString {
    return [STMFunctions UUIDStringFromUUIDData:[self deviceUUID]].uppercaseString;
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


#pragma mark - checking client state

+ (void)checkClientData {

    STMClientData *clientData = [self clientData];
    
    if (clientData) {
        
        NSSet *keys = [STMCoreObjectsController ownObjectKeysForEntityName:NSStringFromClass([STMClientData class])];
        
        for (NSString *key in keys) {
            
            SEL selector = NSSelectorFromString(key);
            
            if ([self respondsToSelector:selector]) {
                
// next 3 lines — implementation of id value = [self performSelector:selector] w/o warning
                IMP imp = [self methodForSelector:selector];
                id (*func)(id, SEL) = (void *)imp;
                id value = func(self, selector);
                
                if (![value isEqual:[clientData valueForKey:key]]) {

//                    NSLog(@"%@ was changed", key);
//                    NSLog(@"client value %@", [clientData valueForKey:key]);
//                    NSLog(@"value %@", value);
                    
                    [clientData setValue:value forKey:key];
                    
                }
                
            }
            
        }

    }
    
//    NSLog(@"clientData %@", clientData);

}

+ (STMClientData *)clientData {
    
    if ([self document].managedObjectContext) {
        
        NSString *entityName = NSStringFromClass([STMClientData class]);
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"deviceCts" ascending:YES selector:@selector(compare:)]];
        
        NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
        STMClientData *clientData = [fetchResult lastObject];
        
        if (!clientData) {
            clientData = (STMClientData *)[STMCoreObjectsController newObjectForEntityName:entityName isFantom:NO];
        }
        
        return clientData;
        
    } else {
        
        return nil;
        
    }
    
}

+ (NSDictionary *)clientDataDictionary {
    return [[self persistenceDelegate] dictionaryFromManagedObject:[self clientData]];
}

+ (void)checkAppVersion {
    
    if ([self document].managedObjectContext) {
        
        STMClientData *clientData = [self clientData];
        
        if (clientData) {
            
            NSString *buildVersion = BUILD_VERSION;
            if (![clientData.appVersion isEqualToString:buildVersion]) {
                clientData.appVersion = buildVersion;
            }
            
            NSString *entityName = NSStringFromClass([STMSetting class]);
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"availableVersion"];
            
            [[self persistenceDelegate] findAllAsync:entityName predicate:predicate options:nil completionHandler:^(BOOL success, NSArray<NSDictionary *> *result, NSError *error) {
            
                NSDictionary *availableVersionSetting = result.lastObject;
                
                if (availableVersionSetting) {
                    
                    NSNumber *availableVersion = @([availableVersionSetting[@"value"] integerValue]);
                    NSNumber *currentVersion = @([clientData.appVersion integerValue]);
                    
                    [self compareAvailableVersion:availableVersion withCurrentVersion:currentVersion];
                    
                }

                
            }];
            
        }
        
    }
    
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
