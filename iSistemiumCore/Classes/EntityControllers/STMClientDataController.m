//
//  STMClientDataController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <AdSupport/AdSupport.h>

#import "STMAppDelegate.h"
#import "STMClientDataController.h"
#import "STMClientData.h"
#import "STMAuthController.h"
#import "STMSetting.h"
#import "STMFunctions.h"
#import "STMObjectsController.h"

@implementation STMClientDataController


+ (STMAppDelegate *)appDelegate {
    return (STMAppDelegate *)[UIApplication sharedApplication].delegate;
}

#pragma mark - clientData properties

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
    return [STMAuthController authController].lastAuth;
}

+ (NSString *)locationServiceStatus {
    return [[self session].locationTracker locationServiceStatus];
}

+ (NSString *)tokenHash {
    return [STMAuthController authController].tokenHash;
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
    
//    NSUUID *identifierForVendor = [UIDevice currentDevice].identifierForVendor;
//    uuid_t uuid;
//    [identifierForVendor getUUIDBytes:uuid];
//    
//    NSLog(@"identifierForVendor %@", identifierForVendor);
    
    NSUUID *advertisingIdentifier = [ASIdentifierManager sharedManager].advertisingIdentifier;
    uuid_t uuid;
    [advertisingIdentifier getUUIDBytes:uuid];
    
//    NSLog(@"advertisingIdentifier %@", advertisingIdentifier);

    NSData *deviceUUID = [NSData dataWithBytes:uuid length:16];
    
    return deviceUUID;
    
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
        
        NSSet *keys = [STMObjectsController ownObjectKeysForEntityName:NSStringFromClass([STMClientData class])];
        
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
    
    [[self document] saveDocument:^(BOOL success) {}];
    
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
            clientData = (STMClientData *)[STMObjectsController newObjectForEntityName:entityName isFantom:NO];
        }
        
        return clientData;
        
    } else {
        
        return nil;
        
    }
    
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
            
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
            request.predicate = [NSPredicate predicateWithFormat:@"name == %@", @"availableVersion"];
            
            NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
            STMSetting *availableVersionSetting = [fetchResult lastObject];
            
            if (availableVersionSetting) {
                
                NSNumber *availableVersion = @([availableVersionSetting.value integerValue]);
                NSNumber *currentVersion = @([clientData.appVersion integerValue]);
                
                [self compareAvailableVersion:availableVersion withCurrentVersion:currentVersion];
                
            }
            
        }
        
    }
    
}

+ (void)compareAvailableVersion:(NSNumber *)availableVersion withCurrentVersion:(NSNumber *)currentVersion {
    
    if ([availableVersion compare:currentVersion] == NSOrderedDescending) {
        
        NSString *entityName = NSStringFromClass([STMSetting class]);

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.predicate = [NSPredicate predicateWithFormat:@"name == %@", @"appDownloadUrl"];
        
        NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
        STMSetting *appDownloadUrlSetting = [fetchResult lastObject];
        
        if (appDownloadUrlSetting) {
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:@YES forKey:@"newAppVersionAvailable"];
            [defaults setObject:availableVersion forKey:@"availableVersion"];
            [defaults setObject:appDownloadUrlSetting.value forKey:@"appDownloadUrl"];
            [defaults synchronize];
            
            NSDictionary *userInfo = @{@"availableVersion": availableVersion, @"appDownloadUrl":appDownloadUrlSetting.value};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"newAppVersionAvailable"
                                                                object:nil
                                                              userInfo:userInfo];
            
        }
        
    } else {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@NO forKey:@"newAppVersionAvailable"];
        [defaults removeObjectForKey:@"availableVersion"];
        [defaults removeObjectForKey:@"appDownloadUrl"];
        [defaults synchronize];
        
    }

}


@end
