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
#import "STMModelMapper.h"

#import <sqlite3.h>


@interface STMFmdb()

@property (nonatomic, weak) id <STMFiling>filing;


@end


@implementation STMFmdb

- (instancetype)initWithModelling:(id <STMModelling>)modelling filing:(id <STMFiling>)filing modelName:(nonnull NSString *)modelName {
    
    self = [self init];
    
    self.filing = filing;
    
    NSString *fmdbPath = [filing persistencePath:@"fmdb"];
    
    NSString *dbPath = [fmdbPath stringByAppendingPathComponent:@"fmdb.db"];
    
    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    self.dbPath = dbPath;
    
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;
    
    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath flags:flags];
    self.pool = [FMDatabasePool databasePoolWithPath:dbPath flags:SQLITE_OPEN_READONLY];

    [self.queue inDatabase:^(FMDatabase *database){
        
        STMFmdbSchema *fmdbSchema = [STMFmdbSchema fmdbSchemaForDatabase:database];
        
        NSError *error = nil;
        STMModelMapper *modelMapper = [[STMModelMapper alloc] initWithModelName:modelName
                                                                         filing:filing
                                                                          error:&error];

        self.columnsByTable = (modelMapper.needToMigrate) ? [fmdbSchema createTablesWithModelMapping:modelMapper] : [fmdbSchema currentDBScheme];
        
    }];
    
    return self;
    
}

- (void)deleteFile {
    
    [self.filing removeItemAtPath:[self.filing persistenceBasePath]
                            error:nil];
    
}


- (BOOL) hasTable:(NSString * _Nonnull)name {
    name = [STMFunctions removePrefixFromEntityName:name];
    if ([self.columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

@end
