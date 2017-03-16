//
//  NSManagedObjectModel+Serialization.h
//  iSisSales
//
//  Created by Alexander Levin on 16/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectModel (Serialization)

+ (instancetype)managedObjectModelFromFile:(NSString *)path;

- (BOOL)saveToFile:(NSString *)path;

@end
