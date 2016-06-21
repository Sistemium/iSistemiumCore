//
//  STMDatum.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/01/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMDatum.h"

#import "STMCoreDataModel.h"
#import "STMFunctions.h"
#import "STMCoreObjectsController.h"


@implementation STMDatum

+ (void)load {
    
    @autoreleasepool {
        
        [[NSNotificationCenter defaultCenter] addObserver:(id)[self class]
                                                 selector:@selector(objectContextWillSave:)
                                                     name:NSManagedObjectContextWillSaveNotification
                                                   object:nil];
        
        //        [[NSNotificationCenter defaultCenter] addObserver:(id)[self class]
        //                                                 selector:@selector(objectContextObjectsDidChange:)
        //                                                     name:NSManagedObjectContextObjectsDidChangeNotification
        //                                                   object:nil];
        
    }
    
}

+ (void)objectContextWillSave:(NSNotification*)notification {
    
    NSManagedObjectContext *context = [notification object];
    
    if (context.parentContext) {
        
        NSSet *modifiedObjects = [context.insertedObjects setByAddingObjectsFromSet:context.updatedObjects];
        [modifiedObjects makeObjectsPerformSelector:@selector(setLastModifiedTimestamp)];
        
    }
    
}

//+ (void)objectContextObjectsDidChange:(NSNotification *)notification {
//
//    NSManagedObjectContext *context = [notification object];
//
//    if (context.parentContext) {
//
//        NSSet *modifiedObjects = [context.insertedObjects setByAddingObjectsFromSet:context.updatedObjects];
//        [modifiedObjects makeObjectsPerformSelector:@selector(setLastModifiedTimestamp)];
//
//    }
//
//}

- (void)setLastModifiedTimestamp{
    
//    if ([self isKindOfClass:[STMShipmentRoutePoint class]] || [self isKindOfClass:[STMShippingLocation class]]) {
//        
//        NSLog(@"%@", NSStringFromClass([self class]));
//        NSLog(@"%@", self.xid);
//        NSLog(@"changedValues %@", self.changedValues);
//        NSLog(@"changedValuesForCurrentEvent %@", self.changedValuesForCurrentEvent);
//        NSLog(@"------------------------");
//        
//    }
    
    NSDictionary *changedValues = self.changedValues;
    
    BOOL ltsIsChanged = [changedValues.allKeys containsObject:@"lts"];

    if (ltsIsChanged) return;

    NSArray *excludeProperties = [self excludeProperties];
    
    NSMutableArray *changedKeysArray = changedValues.allKeys.mutableCopy;
    [changedKeysArray removeObjectsInArray:excludeProperties];
    
    NSMutableArray *relationshipsToMany = [NSMutableArray array];
    
    for (NSRelationshipDescription *relationship in self.entity.relationshipsByName.allValues) {
        if (relationship.isToMany) [relationshipsToMany addObject:relationship.name];
    }
    
    [changedKeysArray removeObjectsInArray:relationshipsToMany];
    
    if (changedKeysArray.count > 0) {
        
        if (self.isFantom.boolValue) [self setPrimitiveValue:@(NO) forKey:@"isFantom"];
        
        NSDate *currentDate = [NSDate date];
        self.deviceTs = currentDate;
        [self setPrimitiveValue:currentDate forKey:@"deviceTs"];
        
    }

    
}

- (NSData *)newXid {
    
    CFUUIDRef xid = CFUUIDCreate(nil);
    CFUUIDBytes xidBytes = CFUUIDGetUUIDBytes(xid);
    CFRelease(xid);
    return [NSData dataWithBytes:&xidBytes length:sizeof(xidBytes)];
    
}

- (void)awakeFromInsert {
    
    //    NSLog(@"awakeFromInsert");
    
    [super awakeFromInsert];
    
    if (self.managedObjectContext.parentContext) {
        
        [self setPrimitiveValue:[self newXid] forKey:@"xid"];
        
        NSDate *ts = [NSDate date];
        [self setPrimitiveValue:ts forKey:@"deviceCts"];
        [self setPrimitiveValue:ts forKey:@"deviceTs"];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *largestId = [defaults objectForKey:@"largestId"];
        
        if (!largestId) {
            largestId = @1;
        } else {
            largestId = @((long long)[largestId longLongValue]+1);
        }
        
        //        NSLog(@"largestId %@", largestId);
        
        [self setPrimitiveValue:largestId forKey:@"id"];
        
        [defaults setObject:largestId forKey:@"largestId"];
        [defaults synchronize];
        
    }
    
}

- (void)willSave {
    
    [super willSave];
    
}

- (NSString *)ctsDayAsString {
    
    if (self.deviceCts) {
    
        static NSDateFormatter *formatter;
        static dispatch_once_t onceToken;
        
        dispatch_once(&onceToken, ^{
            
            formatter = [STMFunctions dateMediumNoTimeFormatter];
            
        });

        NSString *dateString = [formatter stringFromDate:(NSDate * _Nonnull)self.deviceCts];
        return dateString;

    } else {
        
        return nil;
        
    }
    
}

- (NSString *)currentChecksum {
    
    NSArray *excludeProperties = [self excludeProperties];
    
    NSMutableArray *keysArray = self.entity.attributesByName.allKeys.mutableCopy;
    [keysArray removeObjectsInArray:excludeProperties];
    keysArray = [keysArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)].mutableCopy;

    NSDictionary *properties = [self propertiesForKeys:keysArray withNulls:NO];

    NSMutableArray *relationshipsToOne = [NSMutableArray array];
    
    for (NSRelationshipDescription *relationship in self.entity.relationshipsByName.allValues) {
        if (!relationship.isToMany) [relationshipsToOne addObject:relationship.name];
    }
    
    [relationshipsToOne removeObjectsInArray:excludeProperties];
    relationshipsToOne = [relationshipsToOne sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)].mutableCopy;
    
    NSDictionary *relationships = [self relationshipXidsForKeys:relationshipsToOne withNulls:NO];
    
    NSMutableArray *checkValues = @[].mutableCopy;
    
    for (NSString *key in keysArray) {
        if (properties[key]) {
            [checkValues addObject:(NSString * _Nonnull)properties[key]];
        }
    }

    for (NSString *relationName in relationshipsToOne) {
        if (relationships[relationName]) {
            [checkValues addObject:(NSString * _Nonnull)relationships[relationName]];
        }
    }
    
    NSString *stringForChecksum = [checkValues componentsJoinedByString:@"/"];
    
    return [STMFunctions MD5FromString:stringForChecksum];
    
}

- (NSArray *)excludeProperties {
    
    static NSArray *excludeProperties = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        NSArray *coreEntityKeys = [STMCoreObjectsController coreEntityKeys];
        
        excludeProperties = [coreEntityKeys arrayByAddingObjectsFromArray:@[@"imagePath",
                                                                            @"resizedImagePath",
                                                                            @"calculatedSum",
                                                                            @"imageThumbnail"]];
    });

    return excludeProperties;
    
}

- (NSDictionary *)propertiesForKeys:(NSArray *)keys withNulls:(BOOL)withNulls {
    return [self propertiesForKeys:keys withNulls:withNulls withBinaryData:YES];
}

- (NSDictionary *)propertiesForKeys:(NSArray *)keys withNulls:(BOOL)withNulls withBinaryData:(BOOL)withBinaryData {
    
    NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionary];
    
    for (NSString *key in keys) {
        
        if ([self.entity.propertiesByName.allKeys containsObject:key]) {
            
            id value = [self valueForKey:key];
            
            if (value) {
                
                if ([value isKindOfClass:[NSDate class]]) {
                    
                    value = [[STMFunctions dateFormatter] stringFromDate:value];
                    
                } else if ([value isKindOfClass:[NSData class]]) {
                    
                    if ([@[@"deviceUUID", @"deviceToken"] containsObject:key] || [key hasSuffix:@"Xid"]) {
                        
                        value = [STMFunctions UUIDStringFromUUIDData:value];
                        
                    } else {
                        
                        value = (withBinaryData) ? [STMFunctions base64HexStringFromData:value] : @"";
                        
                    }
                    
                }
                
                propertiesDictionary[key] = [NSString stringWithFormat:@"%@", value];
                
            } else {
                
                if (withNulls) {
                    propertiesDictionary[key] = [NSNull null];
                }
                
            }
            
        }
        
    }
    
    return propertiesDictionary;

}

- (NSDictionary *)relationshipXidsForKeys:(NSArray *)keys withNulls:(BOOL)withNulls {
    
    NSMutableDictionary *relationshipsDictionary = [NSMutableDictionary dictionary];

    for (NSString *key in keys) {
        
        NSRelationshipDescription *relationshipDescription = [self.entity.relationshipsByName valueForKey:key];
        
        if (![relationshipDescription isToMany]) {
            
            STMDatum *relationshipObject = [self valueForKey:key];
        
            NSString *dictKey = [key stringByAppendingString:@"Id"];

            if (relationshipObject) {
                
                NSData *xidData = relationshipObject.xid;
                
                if (xidData.length != 0) {
                    relationshipsDictionary[dictKey] = [STMFunctions UUIDStringFromUUIDData:xidData];
                }
                
            } else {
                
                if (withNulls) {
                    relationshipsDictionary[dictKey] = [NSNull null];
                }

            }
            
        }
        
    }
    
    return relationshipsDictionary;

}


@end
