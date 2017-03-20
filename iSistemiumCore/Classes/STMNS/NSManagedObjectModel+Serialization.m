//
//  NSManagedObjectModel+Serialization.m
//  iSisSales
//
//  Created by Alexander Levin on 16/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "NSManagedObjectModel+Serialization.h"

@implementation NSManagedObjectModel (Serialization)

+ (instancetype)managedObjectModelFromFile:(NSString *)path {
    
    NSError *error = nil;
    
    NSData *modelData = [NSData dataWithContentsOfFile:path
                                               options:0
                                                 error:&error];
    
    if (!modelData) {
        
        if (error) {
            
            NSLog(@"error: %@", error.localizedDescription);
            NSLog(@"can't load model from path %@, return empty model", path);
            
        }
        
        return nil;
        
    }
    
    id unarchiveObject = [NSKeyedUnarchiver unarchiveObjectWithData:modelData];
    
    if (![unarchiveObject isKindOfClass:[NSManagedObjectModel class]]) {
        
        NSLog(@"loaded model from file is not NSManagedObjectModel class, return empty model");
        return nil;
        
    }
    
    return unarchiveObject;
    
}


- (BOOL)saveToFile:(NSString *)path {
    
    NSData *modelData = [NSKeyedArchiver archivedDataWithRootObject:self];
    NSError *error = nil;
    
    BOOL writeResult = [modelData writeToFile:path
                                      options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                        error:&error];
    
    if (!writeResult) {
        NSLog(@"can't write model to path %@", path);
    }
    
    return writeResult;
    
}

@end
