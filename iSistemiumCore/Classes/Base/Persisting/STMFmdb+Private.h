//
//  STMFmdb+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb.h"
#import "FMDB.h"

@interface STMFmdb (Private)

- (NSString *)sqliteTypeForAttribute:(NSAttributeDescription *)attribute;
- (NSDictionary*)createTablesWithModelling:(id <STMModelling>)modelling inDatabase:(FMDatabase *)database;

@end
