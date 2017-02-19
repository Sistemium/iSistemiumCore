//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

//Note: The calls to FMDatabaseQueue's methods are blocking. So even though you are passing along blocks, they will not be run on another thread.

#import "STMFmdb+Transactions.h"
#import "STMFunctions.h"
#import "STMPredicateToSQL.h"


@implementation STMFmdb

- (instancetype)initWithModelling:(id <STMModelling>)modelling fileName:(NSString *)fileName{
    
    self = [super init];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    
    NSString *dbPath = [documentDirectory stringByAppendingPathComponent:fileName];
    
    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    self.pool = [FMDatabasePool databasePoolWithPath:dbPath];

    [self.queue inDatabase:^(FMDatabase *database){
        self.columnsByTable = [self createTablesWithModelling:modelling inDatabase:database];
    }];
    
    return self;
    
}


- (BOOL) hasTable:(NSString * _Nonnull)name {
    name = [STMFunctions removePrefixFromEntityName:name];
    if ([self.columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

@end
