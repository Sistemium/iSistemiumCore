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
#import "STMModelMapper.h"

#import "STMFunctions.h"


@interface ModelMappingFMDBTests : XCTestCase <STMDirectoring>

@property (nonatomic, strong) STMFmdb *stmFMDB;
@property (nonatomic, strong) id <STMFiling> filing;

@end


@implementation ModelMappingFMDBTests

- (void)setUp {
    [super setUp];
    
    if (!self.filing) {
        self.filing = [STMCoreSessionFiler coreSessionFilerWithDirectoring:self];
    }
}

- (void)tearDown {
    [self.stmFMDB deleteFile];
    [super tearDown];
}


- (void)testCreateAndMigrateFMDB {
    
    // Create a database as if it is first user's login using first test bundle
    
    NSString *modelName = @"testModel";
    
    NSManagedObjectModel *sourceModel = [self modelWithName:nil];
    NSManagedObjectModel *destinationModel = [self modelWithName:modelName];
    
    NSError *error = nil;
    STMModelMapper *mapper = [[STMModelMapper alloc] initWithModelName:modelName
                                                                filing:self.filing
                                                                 error:&error];
    
    XCTAssertEqualObjects(sourceModel, mapper.sourceModel);
    XCTAssertEqualObjects(destinationModel, mapper.destinationModel);

    XCTAssertNotNil(mapper);
    XCTAssertNil(error);
    XCTAssertTrue(mapper.needToMigrate);
    
    self.stmFMDB = [self fmdbWithModelName:modelName];
    
    [self.stmFMDB.queue inDatabase:^(FMDatabase *db) {
        [self checkDb:db withModelMapping:mapper];
    }];
    
    mapper = [[STMModelMapper alloc] initWithModelName:modelName
                                                filing:self.filing
                                                 error:&error];

    XCTAssertNotNil(mapper);
    XCTAssertNil(error);
    XCTAssertFalse(mapper.needToMigrate);

    // Create a database as if it is have new version of data model
    sourceModel = [self modelWithName:@"testModel"];
    
    modelName = @"testModelChanged";
    destinationModel = [self modelWithName:modelName];
    
    mapper = [[STMModelMapper alloc] initWithSourceModelName:@"testModel"
                                        destinationModelName:modelName
                                                      filing:self.filing
                                                       error:&error];

    XCTAssertNotNil(mapper);
    XCTAssertNil(error);
    XCTAssertTrue(mapper.needToMigrate);
    
    [self.stmFMDB.queue inDatabase:^(FMDatabase *db) {
        
        STMFmdbSchema *fmdbSchema = [STMFmdbSchema fmdbSchemaForDatabase:db];
        
        self.stmFMDB.columnsByTable = (mapper.needToMigrate) ? [fmdbSchema createTablesWithModelMapping:mapper] : [fmdbSchema currentDBScheme];

        [self checkDb:db withModelMapping:mapper];
        
    }];
    
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

- (STMFmdb *)fmdbWithModelName:(NSString *)modelName {
    
    return [[STMFmdb alloc] initWithModelling:[self modelerWithModelName:modelName]
                                       filing:self.filing
                                    modelName:modelName];
}

- (id <STMModelling>)modelerWithModelName:(NSString *)modelName {
    return [STMModeller modellerWithModel:[self modelWithName:modelName]];
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


#pragma mark - STMDirectoring

- (NSString *)userDocuments {
    return NSTemporaryDirectory();
}

- (NSString *)sharedDocuments {
    return NSTemporaryDirectory();
}

- (NSBundle *)bundle {
    // TODO: For fun in the future create a pair of separate test bundles and use it here
    // these bundles will contain test models
    return [NSBundle bundleForClass:[self class]];
}

@end
