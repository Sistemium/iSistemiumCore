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

#import <sqlite3.h>

@implementation STMFmdb

- (instancetype)initWithModelling:(id <STMModelling>)modelling fileName:(NSString *)fileName{
    
    self = [self init];
    
    NSString *documentDirectory = [STMFunctions documentsDirectory];
    
    NSString *fmdbFolderPath = [documentDirectory stringByAppendingPathComponent:@"fmdb"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:fmdbFolderPath]) {
        
        NSDictionary *attributes = @{NSFileProtectionKey : NSFileProtectionNone};
        
        NSError *error = nil;
        BOOL result = [fm createDirectoryAtPath:fmdbFolderPath
                    withIntermediateDirectories:NO
                                     attributes:attributes
                                          error:&error];
        
        if (!result) {
            
            NSLog(@"create fmdb folder error: %@", error.localizedDescription);
            return nil;

        }

    }
    
    NSString *dbPath = [fmdbFolderPath stringByAppendingPathComponent:fileName];
    
    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;
    
    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath flags:flags];
    self.pool = [FMDatabasePool databasePoolWithPath:dbPath flags:SQLITE_OPEN_READONLY];

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
