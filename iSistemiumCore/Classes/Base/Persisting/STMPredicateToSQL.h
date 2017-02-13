//
//  STMPredicateToSQL.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 27/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMModelling.h"

@interface STMPredicateToSQL : NSObject

@property (nonatomic, weak) id <STMModelling> modellingDelegate;

- (NSString *)SQLFilterForPredicate:(NSPredicate *)predicate;

+ (instancetype)predicateToSQLWithModelling:(id <STMModelling>)modelling;

+ (NSString *)quotedName:(NSString*)name;


@end
