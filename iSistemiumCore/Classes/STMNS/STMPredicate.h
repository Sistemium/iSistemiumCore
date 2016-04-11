//
//  STMPredicate.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 25/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMPredicate : NSPredicate

+ (NSPredicate *)predicateWithNoFantoms;
+ (NSPredicate *)predicateWithNoFantomsFromPredicate:(NSPredicate *)predicate;


@end
