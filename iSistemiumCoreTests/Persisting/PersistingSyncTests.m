//
//  PersistingSyncTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMCoreObjectsController.h"
#import "STMCoreSessionManager.h"

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

    if (self.fakePersistingOptions) {
        NSDictionary *testData = @{@"type": @"debug",
                                   @"text": @"testCountSyncWithOptions"};
        
        NSDictionary *testObject =
        [self.persister mergeSync:entityName attributes:testData options:options error:&error];
        
        XCTAssertNil(error);
        XCTAssertNotNil(testObject);
        
        XCTAssertTrue([testObject[@"isFantom"] boolValue]);
        
        count = [self.persister countSync:entityName
                                predicate:predicate
                                  options:options
                                    error:&error];
        
        XCTAssertTrue(count == 1, @"There should be 1 fantom");
        
        NSMutableDictionary *defantomData = testObject.mutableCopy;
        [defantomData removeObjectForKey:@"isFantom"];

        testObject = [self.persister mergeSync:entityName
                                    attributes:defantomData
                                       options:nil
                                         error:&error];
        
        XCTAssertNil(error);
        XCTAssertNotNil(testObject);
        
        XCTAssertFalse([testObject[@"isFantom"] boolValue]);
        
        count = [self.persister countSync:entityName
                                predicate:predicate
                                  options:options
                                    error:&error];
        
        XCTAssertTrue(count == 0, @"There should be no fantom");

    }
    
    options = @{STMPersistingOptionForceStorageCoreData};
    
    count = [self.persister countSync:entityName
                            predicate:predicate
                              options:options
                                error:&error];
    
    XCTAssertTrue(count == 0, @"There should be no data in CoreData");
    
    // cleanup
    
    XCTAssertEqual([self destroyTestDataOwnerXid:xid], 2);
    
}

- (void)testUpdate {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSDictionary *testData = @{@"id" : self.ownerXid, @"text": @"updated test data", @"type": @"should not be updated"};
    
    NSDictionary *testOptions = @{
                                  STMPersistingOptionFieldstoUpdate : @[@"text"],
                                  STMPersistingOptionSetTs:@NO
                                  };
    
    NSDictionary *updatedData = [self.persister updateSync:entityName attributes:testData options:testOptions error:&error];

    XCTAssertNil(updatedData);
    XCTAssertNil(error);
    
    testData = @{@"type": @"debug",
                 @"text": @"testUpdate"};
    
    NSDictionary *testObject = [self.persister mergeSync:entityName attributes:testData options:nil error:&error];
    
    XCTAssertNotNil(testObject);
    XCTAssertNil(error);
    
    NSString *deviceTs = testObject[@"deviceTs"];
    
    testData = @{@"id" : testObject[@"id"] ,@"text": @"updated test data",@"type": @"should not be updated"};
    
    updatedData = [self.persister updateSync:entityName attributes:testData options:testOptions error:&error];
    
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(testData[@"text"], updatedData[@"text"]);
    XCTAssertNotEqualObjects(testData[@"type"], updatedData[@"type"]);
    
    XCTAssertEqualObjects(deviceTs, updatedData[@"deviceTs"]);
    
    [self.persister destroySync:entityName
                     identifier:testObject[@"id"]
                        options:@{STMPersistingOptionRecordstatuses:@NO}
                          error:&error];
    
    XCTAssertNil(error);
}

-(void)testGroupBy{
    
    NSString *entityName = @"STMVisit";
    
    NSArray *sample = [self sampleDataOf:entityName count:10 options:nil addArgumentsToItemAtNumber:^NSDictionary *(NSUInteger number) {
        NSDate *today = [NSDate date];
        NSDate *yesterday = [today dateByAddingTimeInterval: -86400.0];
        
        return @{@"date": number % 2 == 0 ? today : yesterday};
        
    }];
    
    NSError *error;
    
    [self.persister mergeManySync:entityName
                   attributeArray:sample
                          options:nil
                            error:&error];
    
    XCTAssertNil(error);
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ownerXid == %@", sample.firstObject[@"ownerXid"]];
    
    NSDictionary *options = @{STMPersistingOptionGroupBy:@[@"date", @"ownerXid"]};
    NSArray *result =[self.persister findAllSync:entityName predicate:predicate options:options error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(result.count, 2);
}

@end
