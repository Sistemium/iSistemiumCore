//
//  STMPredicate.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 25/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMPredicate.h"

@implementation STMPredicate

+ (NSPredicate *)predicateWithNoFantoms {

    NSPredicate *notFantom = [NSPredicate predicateWithFormat:@"isFantom == NO"];

    return notFantom;
    
}

+ (NSPredicate *)predicateWithNoFantomsFromPredicate:(NSPredicate *)predicate {

    NSPredicate *notFantom = [self predicateWithNoFantoms];

    if (predicate) {
    
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, notFantom]];
        
        return predicate;

    } else {
        
        return notFantom;
        
    }
    
}


@end
