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
    NSManagedObjectModel *sourceModel = [self modelWithName:nil];
    NSManagedObjectModel *destinationModel = [self modelWithName:@"testModel"];
    
    NSError *error = nil;
    STMModelMapper *mapper = [[STMModelMapper alloc] initWithSourceModel:sourceModel
                                                        destinationModel:destinationModel
                                                                   error:&error];
    
    self.stmFMDB = [self fmdbWithModelMapping:mapper];
    
    [self.stmFMDB.queue inDatabase:^(FMDatabase *db) {
        [self checkDb:db withModelMapping:mapper];
    }];
    
    // Create a database as if it is have new version of data model
    sourceModel = [self modelWithName:@"testModel"];
    destinationModel = [self modelWithName:@"testModelChanged"];
    
    mapper = [[STMModelMapper alloc] initWithSourceModel:sourceModel
                                        destinationModel:destinationModel
                                                   error:&error];

    self.stmFMDB = [self fmdbWithModelMapping:mapper];
    
    [self.stmFMDB.queue inDatabase:^(FMDatabase *db) {
        [self checkDb:db withModelMapping:mapper];
    }];
    
}

- (void)checkDb:(FMDatabase *)db withModelMapping:(id <STMModelMapping>)modelMapping {
    
// check all entities and properties in model have corresponding tables and columns in fmdb

    NSLog(@"check all entities and properties in model have corresponding tables and columns in fmdb");
    
    NSArray <NSString *> *entitiesNames = modelMapping.destinationModeling.entitiesByName.allKeys;
    
    for (NSString *entityName in entitiesNames) {
        
        NSString *tableName = [STMFunctions removePrefixFromEntityName:entityName];
        
        BOOL result = [db tableExists:tableName];

        if (!result) {
            NSLog(@"FMDB have no table %@", tableName);
        } else {
            NSLog(@"FMDB %@ OK", tableName);
        }
        
        XCTAssertTrue(result);

        if (!result) continue;
        
        NSArray <NSString *> *fields = [modelMapping.destinationModeling fieldsForEntityName:entityName].allKeys;
        
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

    [columnsByTable enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray <NSString *> * _Nonnull obj, BOOL * _Nonnull stop) {
        
        NSString *entityName = [STMFunctions addPrefixToEntityName:key];
        
        NSEntityDescription *entityDescription = modelMapping.destinationModeling.entitiesByName[entityName];
        
        BOOL result = (entityDescription != nil);
        
        if (!result) {
            NSLog(@"FMDB have unused table %@", key);
        } else {
            NSLog(@"FMDB %@ OK", key);
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
                NSLog(@"FMDB have unused column %@ in table %@", column, key);
            } else {
                NSLog(@"FMDB column %@ in %@ OK", column, key);
            }

            XCTAssertTrue(result);

        }
        
    }];
    
}

- (STMFmdb *)fmdbWithModelMapping:(id <STMModelMapping>)modelMapping {
    
    return [[STMFmdb alloc] initWithModelMapping:modelMapping
                                          filing:self.filing
                                        fileName:@"fmdb.db"];
    
}

- (STMFmdb *)fmdbWithModelName:(NSString *)modelName {
    
    return [[STMFmdb alloc] initWithModelling:[self modelerWithModelName:modelName]
                                       filing:self.filing
                                     fileName:@"fmdb.db"];
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
