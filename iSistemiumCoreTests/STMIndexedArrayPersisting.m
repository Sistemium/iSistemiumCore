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
    
    if (lts) {
        
        NSDictionary *existing = [self objectWithKey:anObject[self.primaryKey]];
       
        if (existing) {
            
            NSString *version = existing[STMPersistingKeyVersion];
            NSString *objectLts = anObject[STMPersistingOptionLts];
            BOOL isModified = version && (!objectLts || [version compare:objectLts] == NSOrderedAscending);
            
            if (isModified && ![existing[STMPersistingKeyVersion] isEqualToString:lts]) {
                return existing;
            }
            
        }
        
        anObject = [STMFunctions setValue:lts forKey:STMPersistingOptionLts inDictionary:anObject];
    
    } else {
        anObject = [STMFunctions setValue:[STMFunctions stringFromNow]
                                   forKey:STMPersistingKeyVersion
                             inDictionary:anObject];
    }
    
    return [self addObject:anObject];
    
}}

- (NSArray <NSDictionary*> *)addObjectsFromArray:(NSArray <NSDictionary*> *)array options:(STMPersistingOptions)options {
@synchronized (self) {
    
    return [STMFunctions mapArray:array withBlock:^id _Nonnull(NSDictionary * _Nonnull item) {
        return [self addObject:item options:options];
    }];
    
}}

@end
