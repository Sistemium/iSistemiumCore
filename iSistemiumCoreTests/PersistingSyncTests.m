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

- (NSArray *)createTestDataOwnerXid:(NSString *)xid type:(NSString *)type {
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    // create test data
    
    NSDictionary *testDataA= @{@"type": type,
                               @"ownerXid": xid,
                               @"text": @"a"};
    
    NSDictionary *testDataZ= @{@"type": type,
                               @"ownerXid": xid,
                               @"text": @"z"};
    
    NSArray *result = [self.persister mergeManySync:entityName
                                     attributeArray:@[testDataA, testDataZ]
                                            options:nil
                                              error:&error];
    
    XCTAssertNil(error);
    
    return result;
}

- (NSUInteger)destroyTestDataOwnerXid:(NSString *)xid {
    
    NSString *entityName = @"STMLogMessage";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ownerXid == %@", xid];
    NSError *error;
    
    NSUInteger result = [self.persister destroyAllSync:entityName
                                             predicate:predicate
                                               options:@{STMPersistingOptionRecordstatuses:@NO}
                                                 error:&error];
    
    XCTAssertNil(error);
    
    return result;
    
}

- (void)testOrderBy {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    // create test data
    
    NSString *xid = [NSUUID UUID].UUIDString;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ownerXid == %@", xid];
    
    NSArray *testData = [self createTestDataOwnerXid:xid type:@"debug"];
    NSDictionary *testDataA = testData.firstObject;
    NSDictionary *testDataZ = testData.lastObject;
    
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
    
    XCTAssertEqual([self destroyTestDataOwnerXid:xid], 2);
    
}

- (void)testCountSync {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    NSString *xid = [NSUUID UUID].UUIDString;
    
    NSPredicate *predicate;
    
    NSDictionary *testData = @{@"type": @"debug",
                               @"text": @"testCountSync",
                               @"ownerXid": xid};
    
    NSDictionary *testObject =
    [self.persister mergeSync:entityName attributes:testData options:nil error:&error];
    
    [self createTestDataOwnerXid:xid type:@"important"];
    
    NSUInteger countAll = [self.persister countSync:entityName
                                          predicate:predicate
                                            options:nil
                                              error:&error];
    XCTAssertTrue(countAll > 0);
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", @[@"important"]];
    
    NSUInteger count = [self.persister countSync:entityName
                                       predicate:predicate
                                         options:nil
                                           error:&error];
    
    XCTAssertTrue(count > 0);
    XCTAssertTrue(count != countAll);
    
    NSLog(@"testCountSync result: %lu %@ records of %lu total", (unsigned long)count, entityName, (unsigned long)countAll);

    // cleanup
    
    [self.persister destroySync:entityName
                     identifier:testObject[@"id"]
                        options:@{STMPersistingOptionRecordstatuses:@NO}
                          error:&error];
    
    XCTAssertNil(error);
    
    XCTAssertEqual([self destroyTestDataOwnerXid:xid], 2);

}

- (void)testCountSyncWithOptions {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSPredicate *predicate;
    NSDictionary *options;
    
    NSString *xid = [NSUUID UUID].UUIDString;
    
    [self createTestDataOwnerXid:xid type:@"important"];
    
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
    
    // cleanup
    
    XCTAssertEqual([self destroyTestDataOwnerXid:xid], 2);
    
}

@end
