//
//  STMPredicateToSQL.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 27/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//


@interface STMPredicateToSQL : NSObject

+ (STMPredicateToSQL *) sharedInstance;
- (NSString *) SQLFilterForPredicate:(NSPredicate *)predicate;

@end
