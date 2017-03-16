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

#import "STMLogger.h"
#import "STMClientEntityController.h"
#import "NSManagedObjectModel+Serialization.h"

#import <sqlite3.h>


@interface STMFmdb()

@end


@implementation STMFmdb

- (instancetype)initWithModelling:(id <STMModelling>)modelling dbPath:(NSString *)dbPath {
    
    self = [self init];
    
    self.modellingDelegate = modelling;
    
    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    self.dbPath = dbPath;
    
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;
    
    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath flags:flags];
    self.pool = [FMDatabasePool databasePoolWithPath:dbPath flags:SQLITE_OPEN_READONLY];
    
    __block BOOL result = NO;

    [self.queue inDatabase:^(FMDatabase *database){
        
        result = [self checkModelMappingForDatabase:database model:modelling.managedObjectModel];
        
    }];
    
    if (!result) return nil;
    
    return self;
    
}

- (BOOL)checkModelMappingForDatabase:(FMDatabase *)database model:(NSManagedObjectModel *)model {
    
    STMFmdbSchema *fmdbSchema = [STMFmdbSchema fmdbSchemaForDatabase:database];
    
    NSString *savedModelPath = [self.dbPath stringByAppendingString:@".model"];
    
    NSManagedObjectModel *savedModel = [NSManagedObjectModel managedObjectModelFromFile:savedModelPath];
    
    if (!savedModel) {
        savedModel = [[NSManagedObjectModel alloc] init];
    }
    
    NSError *error = nil;
    STMModelMapper *modelMapper = [[STMModelMapper alloc] initWithSourceModel:savedModel
                                                             destinationModel:model
                                                                        error:&error];

    if (modelMapper.needToMigrate) {
        
        if (error) {
            
            NSString *errorMessage = [NSString stringWithFormat:@"can't create modelMapping: %@", error.localizedDescription];
            [[STMLogger sharedLogger] errorMessage:errorMessage];
            
            // TODO: maybe need to start with savedModel
            return NO;
            
        }
        
        self.columnsByTable = [fmdbSchema createTablesWithModelMapping:modelMapper];
        
        if (self.columnsByTable) {
            [[modelMapper destinationModel] saveToFile:savedModelPath];
        }
                
    } else {
    
        self.columnsByTable = [fmdbSchema currentDBScheme];

    }
    
    return YES;
    
}

- (BOOL)hasTable:(NSString * _Nonnull)name {
    
    name = [STMFunctions removePrefixFromEntityName:name];
    return [self.columnsByTable.allKeys containsObject:name];

}

@end
