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

- (STMFmdb *)fmdbWithModelName:(NSString *)modelName {
    
    return [[STMFmdb alloc] initWithModelling:[self modelerWithModelName:modelName]
                                       filing:self.filing
                                     fileName:@"fmdb.db"];
}

- (id <STMModelling>)modelerWithModelName:(NSString *)modelName {
    
    NSURL *url = [NSURL fileURLWithPath:[self.filing bundledModelFile:modelName]];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    return [STMModeller modellerWithModel:model];
    
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
