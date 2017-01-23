//
//  STMKeychain.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 07/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMKeychain.h"


@implementation STMKeychain

// method below was overwrited to set kSecAttrAccessible to kSecAttrAccessibleAlways

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)key forAccessGroup:(NSString *)group {
    
    NSMutableDictionary *keychainQuery = [NSMutableDictionary dictionaryWithDictionary:
                                          @{(__bridge id)kSecClass            : (__bridge id)kSecClassGenericPassword,
                                            (__bridge id)kSecAttrService      : key,
                                            (__bridge id)kSecAttrAccount      : key,
                                            (__bridge id)kSecAttrAccessible   : (__bridge id)kSecAttrAccessibleAlways
                                            }];
    
    if (group != nil) {
        [keychainQuery setObject:[self getFullAppleIdentifier:group] forKey:(__bridge id)kSecAttrAccessGroup];
    }
    
    return keychainQuery;
    
}

+ (NSString *)getFullAppleIdentifier:(NSString *)bundleIdentifier {
    
    NSString *bundleSeedIdentifier = [self getBundleSeedIdentifier];
    if (bundleSeedIdentifier != nil && [bundleIdentifier rangeOfString:bundleSeedIdentifier].location == NSNotFound) {
        bundleIdentifier = [NSString stringWithFormat:@"%@.%@", bundleSeedIdentifier, bundleIdentifier];
    }
    return bundleIdentifier;
    
}


@end
