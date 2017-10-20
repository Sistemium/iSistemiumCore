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

@property (nonatomic) BOOL migrationSuccessful;

+ (instancetype)fmdbSchemaForDatabase:(FMDatabase *)database;

+ (NSArray *)builtInAttributes;
+ (NSArray *)ignoredAttributes;

- (NSDictionary *)createTablesWithModelMapping:(id <STMModelMapping>)modelMapping;

- (NSDictionary *)currentDBScheme;

- (void)addEntity:(NSEntityDescription *)entity;


@end
