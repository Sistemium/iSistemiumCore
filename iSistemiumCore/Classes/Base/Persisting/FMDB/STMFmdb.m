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
#import "STMFmdbOperation.h"
#import "STMUserDefaults.h"
#import "STMKeychain.h"
#import <sqlite3.h>
#import <Foundation/Foundation.h>


@interface STMFmdb ()
@property (nonatomic, strong) NSDate *lastVacuumStart;
@property (nonatomic, strong) NSDate *lastVacuumFinish;
@end



@implementation STMFmdb

@synthesize lastVacuumStart = _lastVacuumStart;
@synthesize lastVacuumFinish = _lastVacuumFinish;

- (NSDate *)lastVacuumStart {

    if (!_lastVacuumStart) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        _lastVacuumStart = [defaults objectForKey:@"lastVacuumStart"];

    }

    return _lastVacuumStart;

}

- (NSDate *)lastVacuumFinish {

    if (!_lastVacuumFinish) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        _lastVacuumFinish = [defaults objectForKey:@"lastVacuumFinish"];

    }

    return _lastVacuumFinish;

}

- (instancetype)initWithModelling:(id <STMModelling>)modelling dbPath:(NSString *)dbPath {

    self = [self init];

    self.modellingDelegate = modelling;

    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    self.dbPath = dbPath;

    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;

    self.database = [FMDatabase databaseWithPath:self.dbPath];

    [self.database openWithFlags:flags];

    [self.database executeUpdate:@"PRAGMA journal_mode=WAL;"];

    if (self.lastVacuumStart == nil || [self.lastVacuumFinish compare:self.lastVacuumStart] == NSOrderedDescending){
        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:[NSDate date] forKey:@"lastVacuumStart"];
        [defaults synchronize];
        BOOL vacuum = [self.database executeUpdate:@"VACUUM;"];
        if (vacuum){
            [defaults setObject:[NSDate date] forKey:@"lastVacuumFinish"];
            [defaults synchronize];
        }
    }

//    [self.database executeUpdate:@"PRAGMA TEMP_STORE=MEMORY;"];

    if (![self checkModelMappingForDatabase:self.database model:modelling.managedObjectModel]) return nil;

    self.poolDatabases = @[].mutableCopy;

    NSUInteger poolSize = [NSProcessInfo processInfo].processorCount;

    poolSize = poolSize > 3 ? 3 : poolSize;

    NSLog(@"Pool size: %@", @(poolSize));

    for (int i = 0; i < poolSize; i++) {

        FMDatabase *poolDb = [FMDatabase databaseWithPath:self.dbPath];

        [poolDb openWithFlags:SQLITE_OPEN_READONLY];

        [self.poolDatabases addObject:poolDb];

    }

    // FIXME: concurrent queue will deadlock under heavy load (try shipmentList)

    dispatch_queue_t oq = dispatch_queue_create(
            "com.sistemium.STMFmdbMainDispatchQueue",
            DISPATCH_QUEUE_SERIAL
    );

    self.operationQueue = [STMOperationQueue queueWithDispatchQueue:oq
                                                      maxConcurrent:1];

    self.operationPoolQueue = [STMOperationQueue queueWithDispatchQueue:oq
                                                          maxConcurrent:poolSize];

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

    NSString *versionPath = [self.dbPath stringByAppendingString:@".version"];

    NSData *versionData = [NSData dataWithContentsOfFile:versionPath];

    NSString *savedVersion = versionData ? [NSString stringWithUTF8String:versionData.bytes] : nil;
    NSString *bundleVersion = [model.versionIdentifiers anyObject];

    BOOL needToMigrate = !savedVersion || [savedVersion compare:bundleVersion] != NSOrderedDescending;

    NSLog(@"Saved model version: %@, bundle version: %@, maybe need to migrate: %@",
            savedVersion, bundleVersion, needToMigrate ? @"yes" : @"no");

    NSError *error = nil;
    STMModelMapper *modelMapper;

    if (needToMigrate) {

        modelMapper = [[STMModelMapper alloc] initWithSourceModel:savedModel
                                                 destinationModel:model
                                                            error:&error];

        needToMigrate = modelMapper.needToMigrate;
    }

    if (needToMigrate) {

        if (error) {

            NSString *errorMessage =
                    [NSString stringWithFormat:@"can't create modelMapping: %@", error.localizedDescription];
            [[STMLogger sharedLogger] errorMessage:errorMessage];

            // TODO: maybe need to start with savedModel
            return NO;

        }

        self.columnsByTable = [fmdbSchema createTablesWithModelMapping:modelMapper];

        if (self.columnsByTable) {
            [[modelMapper destinationModel] saveToFile:savedModelPath];
            [bundleVersion writeToFile:versionPath atomically:YES];
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

    STMFmdbOperation *operation = [[STMFmdbOperation asynchronousOperation]
            initWithReadOnly:readOnly stmFMDB:self];

    if (readOnly) {

        [self.operationPoolQueue addOperation:operation];


    } else {

        [self.operationQueue addOperation:operation];

    }

    [operation waitUntilTransactionIsReady];

    return operation.transaction;

}

- (void)endTransaction:(STMFmdbTransaction *)transaction withSuccess:(BOOL)success {

    STMFmdbOperation *operation = (STMFmdbOperation *) transaction.operation;

    operation.success = success;

    [operation finish];

}

@end
