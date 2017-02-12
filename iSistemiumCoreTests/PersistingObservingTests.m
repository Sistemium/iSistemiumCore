//
//  PersistingObservingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

#define PersistingObservingTestsTimeOut 1
#define PersistingObservingTestEntity @"STMLogMessage"

@interface PersistingObservingTests : STMPersistingTests

@property (nonatomic, strong) NSString *testType;
@property (nonatomic, strong) NSPredicate *typePredicate;

@end

@implementation PersistingObservingTests

- (void)setUp {
    
    if (self.persister) return;
    
    self.testType = @"debug";
    self.typePredicate = [NSPredicate predicateWithFormat:@"type == %@", self.testType];

    [super setUp];
    
}

- (void)tearDown {
    [super tearDown];
}


- (void)testObservingWithOptions {
    
    XCTestExpectation *not2BCalledTwiceExpectation = [self expectationWithDescription:@"Expect not to be called twice"];
    
    XCTestExpectation *not2BCalledTwiceExpectation2 = [self expectationWithDescription:@"Also expect not to be called twice"];
    
    NSError *error;
    NSString *xid = [STMFunctions uuidString];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"source == %@", xid];
    
    STMPersistingObservingSubscriptionID subscriptionIdLts =
    [self.persister observeEntity:PersistingObservingTestEntity
                        predicate:predicate
                          options:@{STMPersistingOptionLts:@YES}
                         callback:^(NSArray *data)
     {
         NSDictionary *item = data.firstObject;
         
         XCTAssertEqualObjects(xid, item[@"ownerXid"]);
         
         [not2BCalledTwiceExpectation fulfill];
         
     }];

    STMPersistingObservingSubscriptionID subscriptionIdLtsNo =
    [self.persister observeEntity:PersistingObservingTestEntity
                        predicate:predicate
                          options:@{STMPersistingOptionLts:@NO}
                         callback:^(NSArray *data)
     {
         NSDictionary *item = data.firstObject;
         NSString *ownerXid = item[@"ownerXid"];
         
         XCTAssertTrue([[NSNull null] isEqual:ownerXid] || ownerXid == nil);
         
         [not2BCalledTwiceExpectation2 fulfill];
         
     }];

    NSDictionary *item =
    [self.persister mergeSync:PersistingObservingTestEntity
                   attributes:@{@"type": self.testType, @"source": xid}
                      options:nil
                        error:&error];
    
    XCTAssertNil(error);
    
    XCTAssertTrue([predicate evaluateWithObject:item substitutionVariables:nil]);
    
    NSString *itemVersion = item[STMPersistingKeyVersion];
    
    XCTAssertNotNil(itemVersion);
    
    item = [STMFunctions setValue:xid forKey:@"ownerXid" inDictionary:item];
    
    [self.persister mergeSync:PersistingObservingTestEntity
                   attributes:item
                      options:@{STMPersistingOptionLts:itemVersion}
                        error:&error];
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut handler:^(NSError *err) {
        
        NSError *error;
        
        [self.persister cancelSubscription:subscriptionIdLts];
        [self.persister cancelSubscription:subscriptionIdLtsNo];
        
        [self.persister destroySync:PersistingObservingTestEntity identifier:item[@"id"] options:@{STMPersistingOptionRecordstatuses:@NO} error:&error];
        
    }];
    
}


- (void)testObserveLtsFmdb {
    if (self.fakePersistingOptions) return;
    [self observeLtsTestStorageType:STMStorageTypeFMDB];
}

- (void)testObserveLtsCoreData {
    if (self.fakePersistingOptions) return;
    [self observeLtsTestStorageType:STMStorageTypeCoreData];
}

- (void)testObserveLtsInMemory {
    id oldPersister = self.persister;
    if (!self.fakePersistingOptions) [self inMemoryPersisting];
    [self observeLtsTestStorageType:STMStorageTypeInMemory];
    if (!self.fakePersistingOptions) self.persister = oldPersister;
}

- (void)observeLtsTestStorageType:(STMStorageType)storageType {

    XCTestExpectation *subscriptionExpectation = [self expectationWithDescription:@"Check subscriptions while creating a LogMessage then updating it with lts"];
    
    NSPredicate *ltsPredicate = [NSPredicate predicateWithFormat:@"deviceTs > lts OR lts == nil"];
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[self.typePredicate, ltsPredicate]];
    
    STMPersistingObservingSubscriptionID subscriptionId =
    [self.persister observeEntity:PersistingObservingTestEntity
                        predicate:predicate
                         callback:^(NSArray *data)
     {
         
         // This should be not called twice
         // Called twice means merging with lts doesn't set item uploaded
         
         XCTAssertEqual(data.count, 1);
         
         NSError *error;
         NSMutableDictionary *toUploadItem = [[data firstObject] mutableCopy];
         NSString *itemVersion = toUploadItem[@"deviceTs"];
         
         if (storageType == STMStorageTypeCoreData) {
             itemVersion = toUploadItem[@"ts"];
         }
         
         XCTAssertNotNil(itemVersion);
         
         [subscriptionExpectation fulfill];
         
         toUploadItem[@"ts"] = [STMFunctions stringFromNow];
         toUploadItem[@"text"] = @"Modify some of the item fields as if it was updated by server";
         
         [self.persister mergeSync:PersistingObservingTestEntity
                        attributes:toUploadItem
                           options:@{
                                     // Comment out the next line to see test failed
                                     STMPersistingOptionLts:itemVersion,
                                     STMPersistingOptionReturnSaved:@YES,
                                     STMPersistingOptionForceStorage:@(storageType)
                                     }
                             error:&error];
         
         XCTAssertNil(error);
         
     }];
    
    NSError *error;
    
    NSDictionary *item =
    [self.persister mergeSync:PersistingObservingTestEntity
                   attributes:@{@"type": self.testType}
                      options:@{STMPersistingOptionForceStorage:@(storageType)}
                        error:&error];
    
    XCTAssertNil(error);
    
    __block NSString *pk = item[@"id"];
    
    XCTAssertNotNil(pk);
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
         
         NSUInteger count =
         [self.persister destroySync:PersistingObservingTestEntity
                          identifier:pk
                             options:@{STMPersistingOptionRecordstatuses: @NO,
                                       STMPersistingOptionForceStorage:@(storageType)}
                               error:&error];
         
         XCTAssertNil(error);
         XCTAssertEqual(count, 1);
         XCTAssertTrue([self.persister cancelSubscription:subscriptionId]);
         
     }];
    
}

- (void)testObserveEntity {
    
    XCTestExpectation *subscriptionExpectation = [self expectationWithDescription:@"Waiting for LogMessage"];
    
    id <STMPersistingObserving, STMPersistingSync> persister = self.persister;
    
    XCTAssertNotNil(persister);
    
    STMPersistingObservingSubscriptionID subscriptionId;
    
    NSPredicate *matchingPredicate = self.typePredicate;
    
    subscriptionId = [persister observeEntity:PersistingObservingTestEntity
                                    predicate:matchingPredicate
                                     callback:^(NSArray *data) {
                                         NSLog(@"testObserveEntity called back with: %@", data);
                                         [subscriptionExpectation fulfill];
                                     }];
    
    XCTAssertNotNil(subscriptionId);
    
    STMPersistingObservingSubscriptionID subscriptionNotCalledBackId;
    
    NSPredicate *notMatchingPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:matchingPredicate];
    
    subscriptionNotCalledBackId = [persister observeEntity:PersistingObservingTestEntity
                                                 predicate:notMatchingPredicate
                                                  callback:^(NSArray * _Nullable data) {
                                                      XCTFail(@"Subscriptions with 'notMatchingPredicate' should not be called back");
                                                  }];
    
    NSError *error;
    
    NSDictionary *item = [persister mergeSync:PersistingObservingTestEntity
                                   attributes:@{@"type": self.testType}
                                      options:nil
                                        error:&error];
    
    XCTAssertNil(error);
    
    NSUInteger count = [persister destroySync:PersistingObservingTestEntity
                                   identifier:item[@"id"]
                                      options:@{STMPersistingOptionRecordstatuses: @NO}
                                        error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(count, 1);
    
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:^(NSError * _Nullable error) {

                                     XCTAssertTrue([persister cancelSubscription:subscriptionId]);
                                     XCTAssertFalse([persister cancelSubscription:subscriptionId]);
                                     XCTAssertTrue([persister cancelSubscription:subscriptionNotCalledBackId]);

                                 }];
}

- (void)testObserveMergeMany {

    XCTestExpectation *subscriptionExpectation =
    [self expectationWithDescription:@"Waiting for callBack with one object after merging two items with subscription with predicate"];
    
    XCTestExpectation *subscriptionExpectation2 =
    [self expectationWithDescription:@"Second expectation is the same two items merging but fulfilled with a subscription with inverted predicate"];
    
    NSArray *testData = @[@{@"type": self.testType}, @{@"type": @"error"}];
    
    __block STMPersistingObservingSubscriptionID subscriptionId;
    
    subscriptionId = [self.persister observeEntity:PersistingObservingTestEntity
                                         predicate:self.typePredicate
                                          callback:^(NSArray * _Nullable data) {
                                              XCTAssertEqual(data.count, 1);
                                              [subscriptionExpectation fulfill];
                                          }];
    
    __block STMPersistingObservingSubscriptionID subscriptionId2;
    
    NSPredicate *notMatchingPredicate =
    [NSCompoundPredicate notPredicateWithSubpredicate:self.typePredicate];
    
    subscriptionId2 = [self.persister observeEntity:PersistingObservingTestEntity
                                          predicate:notMatchingPredicate
                                           callback:^(NSArray * _Nullable data) {
                                               XCTAssertEqual(data.count, 1);
                                               [subscriptionExpectation2 fulfill];
                                           }];
    
    NSError *error;
    NSArray *items = [self.persister mergeManySync:PersistingObservingTestEntity
                                    attributeArray:testData
                                           options:nil
                                             error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(items.count, testData.count);
    
    for (NSDictionary *item in items) {
        [self.persister destroySync:PersistingObservingTestEntity
                         identifier:item[@"id"]
                            options:@{STMPersistingOptionRecordstatuses: @NO}
                              error:&error];
        XCTAssertNil(error);
    }

    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:^(NSError * _Nullable error) {
                                     XCTAssertTrue([self.persister cancelSubscription:subscriptionId]);
                                     XCTAssertTrue([self.persister cancelSubscription:subscriptionId2]);
                                 }];
}

@end
