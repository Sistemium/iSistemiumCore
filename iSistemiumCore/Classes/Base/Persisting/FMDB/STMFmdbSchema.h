//
//  STMFmdbSchema.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 05/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "FMDatabase.h"
#import "STMModelling.h"

#import "STMModelMapping.h"


@interface STMFmdbSchema : NSObject

+ (instancetype)fmdbSchemaForDatabase:(FMDatabase *)database;

- (NSDictionary *)createTablesWithModelling:(id <STMModelling>)modelling;

- (NSDictionary *)createTablesWithModelMapping:(id <STMModelMapping>)modelMapping;


@end
