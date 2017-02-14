//
//  STMIndexedArrayPersisting.m
//  iSisSales
//
//  Created by Alexander Levin on 06/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMIndexedArrayPersisting.h"
#import "STMFunctions.h"

@implementation STMIndexedArrayPersisting

- (NSDictionary *)addObject:(NSDictionary *)anObject options:(STMPersistingOptions)options {
@synchronized (self) {
        
    NSString *lts = options[STMPersistingOptionLts];
    NSString *now = [STMFunctions stringFromNow];
    NSMutableDictionary *theObjectCopy = anObject.mutableCopy;
    
    NSDictionary *existing = [self objectWithKey:anObject[self.primaryKey]];
    NSNumber *isFantom = [NSNumber numberWithBool:options[STMPersistingOptionFantoms] && [options[STMPersistingOptionFantoms] boolValue]];
    
    theObjectCopy[STMPersistingKeyPhantom] = isFantom;
    theObjectCopy[STMPersistingOptionLts] = existing[STMPersistingOptionLts];
    theObjectCopy[STMPersistingKeyCreationTimestamp] = existing[STMPersistingKeyCreationTimestamp];
    
    if (lts) {
        
        if (existing) {
            
            NSString *version = existing[STMPersistingKeyVersion];
            NSString *objectLts = anObject[STMPersistingOptionLts];
            BOOL isModified = version && (!objectLts || [version compare:objectLts] == NSOrderedAscending);
            
            if (isModified && ![existing[STMPersistingKeyVersion] isEqualToString:lts]) {
                return existing;
            }
            
        }
        
        theObjectCopy[STMPersistingOptionLts] = lts;
    
    } else if (!isFantom.boolValue && ![options[STMPersistingOptionSetTs] isEqual:@NO]) {
        theObjectCopy[STMPersistingKeyVersion] = now;
    }
    
    if (!theObjectCopy[STMPersistingOptionLts]) {
        theObjectCopy[STMPersistingOptionLts] = @"";
    }
    
    if (!theObjectCopy[STMPersistingKeyCreationTimestamp]) {
        theObjectCopy[STMPersistingKeyCreationTimestamp] = now;
    }
    
    return [self addObject:theObjectCopy];
    
}}

- (NSArray <NSDictionary*> *)addObjectsFromArray:(NSArray <NSDictionary*> *)array options:(STMPersistingOptions)options {
@synchronized (self) {
    
    return [STMFunctions mapArray:array withBlock:^id _Nonnull(NSDictionary * _Nonnull item) {
        return [self addObject:item options:options];
    }];
    
}}

@end
