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
    self.stmFMDB = [[STMFmdb alloc] initWithModelling:[self modelerWithModelName:@"testModel"]
                                               filing:self.filing
                                             fileName:@"fmdb.db"];
    
    [self.stmFMDB.queue inDatabase:^(FMDatabase *db) {
        // Assert the tables are properly created with [db columnExists:inTableWithName:] declared in FMDatabaseAdditions.h
    }];
    
    // TODO: some new STMFmdb's method that gets and applies modelMapping between the test models
    
    self.stmFMDB = [[STMFmdb alloc] initWithModelling:[self modelerWithModelName:@"testModelChanged"]
                                               filing:self.filing
                                             fileName:@"fmdb.db"];
    
    [self.stmFMDB.queue inDatabase:^(FMDatabase *db) {
        // Assert the tables are properly migrated
    }];
    
}

- (void)checkDb:(FMDatabase *)db withModelMapping:(id <STMModelMapping>)modelMapping {
    
    NSArray <NSString *> *entitiesNames = modelMapping.destinationModeling.entitiesByName.allKeys;
    
    for (NSString *entityName in entitiesNames) {
        
        NSArray <NSString *> *fields = [modelMapping.destinationModeling fieldsForEntityName:entityName].allKeys;
        
        for (NSString *column in fields) {
            
            NSString *tableName = [STMFunctions removePrefixFromEntityName:entityName];
            
            BOOL result = [db columnExists:column inTableWithName:tableName];
            
            if (!result) {
                NSLog(@"%@ have no column %@", column, tableName);
            } else {
                NSLog(@"%@ %@ OK", tableName, column);
            }
            
            XCTAssertTrue(result);
            
        }
        
    }

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
