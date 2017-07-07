//
//  ModelMappingFMDBTests.m
//  iSistemiumCore
//
//  Created by Alexander Levin on 05/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMCoreSessionFiler.h"
#import "STMFmdb+Private.h"
#import "STMFmdbSchema.h"

#import "STMModeller.h"
#import "STMTestDirectoring.h"
#import "STMModelMapper.h"

#import "STMFunctions.h"


@interface ModelMappingFMDBTests : XCTestCase

@property (nonatomic, strong) STMFmdb *stmFMDB;
@property (nonatomic, strong) id <STMFiling> filing;
@property (nonatomic, strong) NSString *basePath;


@end


@implementation ModelMappingFMDBTests

- (void)setUp {
    [super setUp];
    
    if (!self.filing) {
        self.filing = [STMCoreSessionFiler coreSessionFilerWithDirectoring:[[STMTestDirectoring alloc] init]];
    }
}

- (void)tearDown {
    [self.filing removeItemAtPath:self.basePath error:nil];
    [super tearDown];
}

- (NSString *)basePath {
    
    if (!_basePath) {
        _basePath = [self.filing persistencePath:NSStringFromClass(self.class)];
    }
    return _basePath;
    
}

- (void)testCreateAndMigrateFMDB {
    
    // Create a database as if it is first user's login using first test bundle
    
    NSManagedObjectModel *emptyModel = [self modelWithName:nil];
    NSManagedObjectModel *testModel = [self modelWithName:@"testModel"];
    
    NSError *error = nil;
    STMModelMapper *mapper = [[STMModelMapper alloc] initWithSourceModel:emptyModel
                                                        destinationModel:testModel
                                                                   error:&error];
    
    XCTAssertEqualObjects(emptyModel, mapper.sourceModel);
    XCTAssertEqualObjects(testModel, mapper.destinationModel);

    XCTAssertNotNil(mapper);
    XCTAssertNil(error);
    XCTAssertTrue(mapper.needToMigrate);
    
    // Need to hold the reference to the modeller because stmFMDB's weak
    STMModeller *modeller = [STMModeller modellerWithModel:testModel];
    self.stmFMDB = [self fmdbWithModel:modeller];

    [self checkDb:self.stmFMDB.database withModelMapping:mapper];
    
    NSManagedObjectModel *fmdbModel = self.stmFMDB.modellingDelegate.managedObjectModel;
    
    XCTAssertNotNil(fmdbModel);
    
    mapper = [[STMModelMapper alloc] initWithSourceModel:fmdbModel
                                        destinationModel:testModel
                                                   error:&error];

    XCTAssertNotNil(mapper);
    XCTAssertNil(error);
    XCTAssertFalse(mapper.needToMigrate);

    // Create a database as if it is have new version of data model
    
    NSManagedObjectModel *testModelChanged = [self modelWithName:@"testModelChanged"];
    
    mapper = [[STMModelMapper alloc] initWithSourceModel:testModel
                                        destinationModel:testModelChanged
                                                   error:&error];

    XCTAssertNotNil(mapper);
    XCTAssertNil(error);
    XCTAssertTrue(mapper.needToMigrate);
    
    FMDatabase *db = self.stmFMDB.database;
        
    STMFmdbSchema *fmdbSchema = [STMFmdbSchema fmdbSchemaForDatabase:db];
        
    self.stmFMDB.columnsByTable = (mapper.needToMigrate) ? [fmdbSchema createTablesWithModelMapping:mapper] : [fmdbSchema currentDBScheme];

    [self checkDb:db withModelMapping:mapper];
    
}

- (void)checkDb:(FMDatabase *)db withModelMapping:(id <STMModelMapping>)modelMapping {
    
// check all entities and properties in model have corresponding tables and columns in fmdb

    NSLog(@"check all entities and properties in model have corresponding tables and columns in fmdb");
    
    NSArray <NSEntityDescription *> *entities = modelMapping.destinationModel.entitiesByName.allValues;
    
    for (NSEntityDescription *entity in entities) {
        
        NSString *tableName = [STMFunctions removePrefixFromEntityName:entity.name];
        
        BOOL result = [db tableExists:tableName];

        if (!result) {
            NSLog(@"FMDB have no table %@", tableName);
        } else {
            NSLog(@"FMDB %@ OK", tableName);
        }
        
        XCTAssertTrue(result);

        if (!result) continue;
        
        NSArray <NSString *> *fields = entity.attributesByName.allKeys;
        
        for (NSString *column in fields) {
            
            result = [db columnExists:column inTableWithName:tableName];
            
            if (!result) {
                NSLog(@"FMDB %@ have no column %@", tableName, column);
            } else {
                NSLog(@"FMDB %@ %@ OK", tableName, column);
            }
            
            XCTAssertTrue(result);
            
        }
        
    }
    
// check fmdb have no tables and columns which not exists in model
    
    NSLog(@"check fmdb have no tables and columns which not exists in model");

    NSDictionary <NSString *, NSArray <NSString *> *> *columnsByTable = self.stmFMDB.columnsByTable;

    [columnsByTable enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray <NSString *> * _Nonnull obj, BOOL * _Nonnull stop) {
        
        entityName = [STMFunctions addPrefixToEntityName:entityName];
        
        NSEntityDescription *entityDescription = modelMapping.destinationModel.entitiesByName[entityName];
        
        BOOL result = (entityDescription != nil);
        
        if (!result) {
            NSLog(@"FMDB have unused table %@", entityName);
        } else {
            NSLog(@"FMDB %@ OK", entityName);
        }
        
        XCTAssertTrue(result);

        for (NSString *column in obj) {
            
            if ([[STMFmdbSchema builtInAttributes] containsObject:column]) {
                continue;
            }
            
            NSString *propertyName = column;
            
            if ([column hasSuffix:RELATIONSHIP_SUFFIX]) {
                
                NSRange range = NSMakeRange(column.length - RELATIONSHIP_SUFFIX.length, RELATIONSHIP_SUFFIX.length);
                propertyName = [column stringByReplacingCharactersInRange:range withString:@""];
                
            }
            
            NSPropertyDescription *propertyDescription = entityDescription.propertiesByName[propertyName];
            result = (propertyDescription != nil);
            
            if (!result) {
                NSLog(@"FMDB have unused column %@ in table %@", column, entityName);
            } else {
                NSLog(@"FMDB column %@ in %@ OK", column, entityName);
            }

            XCTAssertTrue(result);

        }
        
    }];
    
}

- (STMFmdb *)fmdbWithModel:(id <STMModelling>)modelling {
    
    return [[STMFmdb alloc] initWithModelling:modelling
                                       dbPath:[self.basePath stringByAppendingPathComponent:@"fmdb"]];
    
}

- (NSManagedObjectModel *)modelWithName:(NSString *)name {
    
    NSManagedObjectModel *model = nil;
    
    if (!name) {
        
        model = [[NSManagedObjectModel alloc] init];
        
    } else {
        
        NSURL *url = [NSURL fileURLWithPath:[self.filing bundledModelFile:name]];
        model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        
    }

    return model;
    
}

@end
