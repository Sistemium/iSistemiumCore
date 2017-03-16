//
//  STMFmdb+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb.h"
#import "FMDB.h"
#import "STMPredicateToSQL.h"

#define FMDB_PATH @"fmdb"

@interface STMFmdb()

@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, strong) FMDatabasePool *pool;
@property (nonatomic, strong) NSDictionary *columnsByTable;
@property (nonatomic, strong) STMPredicateToSQL *predicateToSQL;
@property (nonatomic, weak) id <STMModelling> modellingDelegate;
@property (nonatomic,strong) NSString *dbPath;

@end

