//
//  PersistingSyncTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMCoreObjectsController.h"

@interface PersistingSyncTests : STMPersistingTests

@end

@implementation PersistingSyncTests

- (void)testTotalNumberOfObjectsInStorages {
    [STMCoreObjectsController logTotalNumberOfObjectsInStorages];
}

- (void)testOrderBy {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;

    // create test data
    
    NSString *xid = [NSUUID UUID].UUIDString;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ownerXid == %@", xid];
    
    NSDictionary *testDataA= @{@"type": @"debug",
                               @"ownerXid": xid,
                               @"text": @"a"};
    
    NSDictionary *testDataZ= @{@"type": @"debug",
                               @"ownerXid": xid,
                               @"text": @"z"};
    
    [self.persister mergeManySync:entityName
                   attributeArray:@[testDataA, testDataZ]
                          options:nil
                            error:&error];

    XCTAssertNil(error);
    
    // the test itself
    
    NSString *key = @"text";
    
    NSArray *result =
    [self.persister findAllSync:entityName
                      predicate:predicate
                        options:@{STMPersistingOptionOrderDirectionAsc,
                                  STMPersistingOptionOrder:@"type,text"}
                          error:&error];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result.firstObject[key], testDataA[key]);
    
    result =
    [self.persister findAllSync:entityName
                      predicate:predicate
                        options:@{STMPersistingOptionOrderDirectionDesc,
                                  STMPersistingOptionOrder:@"text,type"}
                          error:&error];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result.firstObject[key], testDataZ[key]);

    // now the same but the order option
    
    result =
    [self.persister findAllSync:entityName
                      predicate:predicate
                        options:@{STMPersistingOptionOrderDirectionAsc,
                                  STMPersistingOptionOrder:@"text"}
                          error:&error];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result.firstObject[key], testDataA[key]);
    
    result =
    [self.persister findAllSync:entityName
                      predicate:predicate
                        options:@{STMPersistingOptionOrderDirectionDesc,
                                  STMPersistingOptionOrder:@"type,text"}
                          error:&error];
    
    XCTAssertEqual(result.count, 2);
    XCTAssertEqualObjects(result.firstObject[key], testDataZ[key]);

    // cleanup
    
    NSUInteger count =
    [self.persister destroyAllSync:entityName
                     predicate:predicate
                       options:@{STMPersistingOptionRecordstatuses:@NO}
                         error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(count, 2);
    
}

- (void)testCountSync {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSPredicate *predicate;
    
    NSDictionary *testData = @{@"type": @"debug",
                               @"text": @"testCountSync"};
    
    NSDictionary *testObject =
    [self.persister mergeSync:entityName attributes:testData options:nil error:&error];

    NSUInteger countAll = [self.persister countSync:entityName
                                          predicate:predicate
                                            options:nil
                                              error:&error];
    XCTAssertTrue(countAll > 0);

    predicate = [NSPredicate predicateWithFormat:@"type in (%@)", @[@"important"]];
    
    NSUInteger count = [self.persister countSync:entityName
                                       predicate:predicate
                                         options:nil
                                           error:&error];
    
    XCTAssertTrue(count > 0);
    XCTAssertTrue(count != countAll);
    
    NSLog(@"testCountSync result: %lu %@ records of %lu total", (unsigned long)count, entityName, (unsigned long)countAll);
    
    [self.persister destroySync:entityName
                     identifier:testObject[@"id"]
                        options:@{STMPersistingOptionRecordstatuses:@NO}
                          error:&error];
    
    XCTAssertNil(error);
}

- (void)testCountSyncWithOptions {

    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSPredicate *predicate;
    
    NSDictionary *options;

    NSUInteger count = [self.persister countSync:entityName
                                          predicate:predicate
                                            options:options
                                              error:&error];
    
    
    XCTAssertTrue(count > 0, @"There should be some data");
    
    options = @{STMPersistingOptionFantoms:@YES};
    
    count = [self.persister countSync:entityName
                            predicate:predicate
                              options:options
                                error:&error];
    
    XCTAssertTrue(count == 0, @"There should be no fantoms");
    
    options = @{STMPersistingOptionForceStorageCoreData};
    
    count = [self.persister countSync:entityName
                            predicate:predicate
                              options:options
                                error:&error];
    
    XCTAssertTrue(count == 0, @"There should be no data in CoreData");
    
}

- (void)testUpdate {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSDictionary *testData = @{@"id" : @"non nexisting",@"text": @"updated test data",@"type": @"should not be updated"};
    
    NSDictionary *testOptions = @{@"fieldsToUpdate" : @[@"text"]};
    
    NSDictionary *updatedData = [self.persister updateSync:entityName attributes:testData options:testOptions error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertNil(updatedData);
    
    testData = @{@"type": @"debug",
                 @"text": @"testUpdate"};
    
    NSDictionary *testObject = [self.persister mergeSync:entityName attributes:testData options:nil error:&error];
    
    XCTAssertNotNil(testObject);
    XCTAssertNil(error);
    
    testData = @{@"id" : testObject[@"id"] ,@"text": @"updated test data",@"type": @"should not be updated"};
    
    updatedData = [self.persister updateSync:entityName attributes:testData options:testOptions error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(testData[@"text"], updatedData[@"text"]);
    XCTAssertNotEqual(testData[@"type"], updatedData[@"type"]);
}

@end
