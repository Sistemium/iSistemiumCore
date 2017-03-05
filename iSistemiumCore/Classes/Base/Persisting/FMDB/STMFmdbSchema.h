//
//  STMFmdbSchema.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 05/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "FMDatabase.h"
#import "STMModelling.h"

@interface STMFmdbSchema : NSObject

+ (instancetype)fmdbSchemaForDatabase:(FMDatabase *)database;

- (NSDictionary*)createTablesWithModelling:(id <STMModelling>)modelling;

@end
