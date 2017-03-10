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
#import "STMFmdbSchema.h"

#import <sqlite3.h>

@implementation STMFmdb

- (instancetype)initWithModelMapping:(id <STMModelMapping>)modelMapping filing:(id <STMFiling>)filing fileName:(NSString *)fileName {
    
    self = [self init];
    
    NSString *fmdbPath = [filing persistencePath:@"fmdb"];
    
    NSString *dbPath = [fmdbPath stringByAppendingPathComponent:fileName];
    
// should we use modelMapping.sourceModelling or destinationModeling here ???
    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelMapping.destinationModeling];
    self.dbPath = dbPath;
    
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;
    
    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath flags:flags];
    self.pool = [FMDatabasePool databasePoolWithPath:dbPath flags:SQLITE_OPEN_READONLY];
    
    [self.queue inDatabase:^(FMDatabase *database){
        self.columnsByTable = [[STMFmdbSchema fmdbSchemaForDatabase:database] createTablesWithModelMapping:modelMapping];
    }];
    
    return self;
    
}

//- (instancetype)initWithModelling:(id <STMModelling>)modelling filing:(id <STMFiling>)filing fileName:(NSString *)fileName{
//    
//    self = [self init];
//    
//    NSString *fmdbPath = [filing persistencePath:@"fmdb"];
//    
//    NSString *dbPath = [fmdbPath stringByAppendingPathComponent:fileName];
//    
//    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
//    self.dbPath = dbPath;
//    
//    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;
//    
//    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath flags:flags];
//    self.pool = [FMDatabasePool databasePoolWithPath:dbPath flags:SQLITE_OPEN_READONLY];
//
//    [self.queue inDatabase:^(FMDatabase *database){
//        self.columnsByTable = [[STMFmdbSchema fmdbSchemaForDatabase:database] createTablesWithModelling:modelling];
//    }];
//    
//    return self;
//    
//}


- (void)deleteFile {
    // TODO: remove the method or rewrite with filing
    [[NSFileManager defaultManager] removeItemAtPath:self.dbPath error:nil];
}


- (BOOL) hasTable:(NSString * _Nonnull)name {
    name = [STMFunctions removePrefixFromEntityName:name];
    if ([self.columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

@end
