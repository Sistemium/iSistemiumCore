//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//


#import "STMFmdb+Transactions.h"

#import "STMFunctions.h"
#import "STMFmdbSchema.h"
#import "STMModelMapper.h"

#import "STMLogger.h"
#import "NSManagedObjectModel+Serialization.h"

#import <sqlite3.h>

@interface STMFmdbOperation : STMOperation

@property (nonatomic, strong) STMFmdbTransaction *transaction;
@property (nonatomic, weak) STMFmdb *stmFMDB;
@property (nonatomic, strong) FMDatabase *database;
@property BOOL readOnly;
@property BOOL success;
@property dispatch_semaphore_t sem;

@end

@implementation STMFmdbOperation

- (instancetype)initWithReadOnly:(BOOL)readOnly stmFMDB:(STMFmdb *)stmFMDB {

    self.readOnly = readOnly;

    self.stmFMDB = stmFMDB;

    self.sem = dispatch_semaphore_create(0);

    return self;

}

- (void)main {

    if (self.readOnly) {

        self.database = [STMFunctions popArray:self.stmFMDB.poolDatabases];


    } else {

        self.database = self.stmFMDB.database;

        [self.database beginTransaction];

    }

    self.transaction = [[STMFmdbTransaction alloc] initWithFMDatabase:self.database stmFMDB:self.stmFMDB];

    self.transaction.operation = self;

    dispatch_semaphore_signal(self.sem);

}

- (void)finish {

    if (!self.readOnly) {

        if (self.success) {

            [self.database commit];

        } else {

            [self.database rollback];

        }

    }

    if (self.readOnly) {

        [STMFunctions pushArray:self.stmFMDB.poolDatabases object:self.database];

    }

    [super finish];

    self.transaction.operation = nil;
    self.transaction = nil;
    self.sem = nil;
    self.database = nil;

}

- (void)waitUntilTransactionIsReady {

    dispatch_semaphore_wait(self.sem, DISPATCH_TIME_FOREVER);

}

@end

@interface STMFmdb ()

@end


@implementation STMFmdb

- (instancetype)initWithModelling:(id <STMModelling>)modelling dbPath:(NSString *)dbPath {

    self = [self init];

    self.modellingDelegate = modelling;

    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    self.dbPath = dbPath;

    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;

    self.database = [FMDatabase databaseWithPath:self.dbPath];

    [self.database openWithFlags:flags];

    [self.database executeUpdate:@"PRAGMA journal_mode=WAL;"];

    [self.database executeUpdate:@"PRAGMA TEMP_STORE=MEMORY;"];

    if (![self checkModelMappingForDatabase:self.database model:modelling.managedObjectModel]) return nil;

    self.poolDatabases = @[].mutableCopy;

    NSUInteger poolSize = [NSProcessInfo processInfo].processorCount;

    poolSize = poolSize > 2 ? 2 : poolSize;

    NSLog(@"Pool size: %@", @(poolSize));

    for (int i = 0; i <= poolSize; i++) {

        FMDatabase *poolDb = [FMDatabase databaseWithPath:self.dbPath];

        [poolDb openWithFlags:SQLITE_OPEN_READONLY];

        [self.poolDatabases addObject:poolDb];

    }

    self.dispatchQueue = dispatch_queue_create("com.sistemium.STMFmdbDispatchQueue", DISPATCH_QUEUE_SERIAL);
    self.operationQueue = [STMOperationQueue queueWithDispatchQueue:self.dispatchQueue maxConcurrent:1];
    self.operationPoolQueue = [STMOperationQueue queueWithDispatchQueue:self.dispatchQueue maxConcurrent:poolSize];

    return self;

}

- (BOOL)checkModelMappingForDatabase:(FMDatabase *)database model:(NSManagedObjectModel *)model {

    NSLogMethodName;

    STMFmdbSchema *fmdbSchema = [STMFmdbSchema fmdbSchemaForDatabase:database];

    self.builtInAttributes = [STMFmdbSchema builtInAttributes];
    self.ignoredAttributes = [STMFmdbSchema ignoredAttributes];
    self.numericAttributes = [STMFmdbSchema numericAttributes];
    self.minMaxAttributes = [STMFmdbSchema minMaxAttributes];

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

    NSMutableDictionary *columnsByTableWithTypes = @{}.mutableCopy;

    for (NSString *tableName in self.columnsByTable.allKeys) {

        NSMutableDictionary *columns = @{}.mutableCopy;
        NSString *entityName = [STMFunctions addPrefixToEntityName:tableName];
        NSEntityDescription *entity = self.modellingDelegate.entitiesByName[entityName];

        for (NSString *columnName in self.columnsByTable[tableName]) {

            NSAttributeType attributeType = entity.attributesByName[columnName].attributeType;

            [columns addEntriesFromDictionary:@{columnName: @(attributeType)}];

        }

        columnsByTableWithTypes[tableName] = columns.copy;

    }

    self.columnsByTable = columnsByTableWithTypes.copy;

    return YES;

}

- (BOOL)hasTable:(NSString *_Nonnull)name {

    name = [STMFunctions removePrefixFromEntityName:name];
    return [self.columnsByTable.allKeys containsObject:name];

}

- (NSString *)executePatchForCondition:(NSString *)condition patch:(NSString *)patch {

    FMResultSet *result = [self.database executeQuery:condition];

    if (![result next]) {
        return [@"Successfully skipped unnecessary patch: " stringByAppendingString:patch];
    }

    [result close];

    if (![self.database executeStatements:patch]) {

        return @"Error while executing patch";

    }

    return [@"Successfully executed patch: " stringByAppendingString:patch];

}


#pragma mark - Adapting protocol

- (STMFmdbTransaction *)beginTransactionReadOnly:(BOOL)readOnly {

    STMFmdbOperation *operation = [[STMFmdbOperation asynchronousOperation] initWithReadOnly:readOnly stmFMDB:self];

    if (readOnly) {

        [self.operationPoolQueue addOperation:operation];

        [operation waitUntilTransactionIsReady];

    } else {

        [self.operationQueue addOperation:operation];

        [operation waitUntilTransactionIsReady];

    }

    return operation.transaction;

}

- (void)endTransaction:(STMFmdbTransaction *)transaction withSuccess:(BOOL)success {

    STMFmdbOperation *operation = (STMFmdbOperation *) transaction.operation;

    operation.success = success;

    [operation finish];

}

@end
