//
//  PersistingObservingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STMPersistingObserving.h"
#import "STMPersistingSync.h"
#import "STMCoreSessionManager.h"
#import "STMConstants.h"
#import "STMFunctions.h"

#define PersistingObservingTestsTimeOut 10
#define PersistingObservingTestEntity @"STMLogMessage"

@interface PersistingObservingTests : XCTestCase

@property (nonatomic, strong) id <STMPersistingObserving, STMPersistingSync> persister;
@property (nonatomic, strong) NSString *testType;
@property (nonatomic, strong) NSPredicate *typePredicate;

@end

@implementation PersistingObservingTests

- (void)setUp {
    [super setUp];
    
    if (self.persister) return;
    
    self.testType = @"debug";
    self.typePredicate = [NSPredicate predicateWithFormat:@"type == %@", self.testType];

    STMCoreSessionManager *manager = STMCoreSessionManager.sharedManager;
    
    XCTAssertNotNil(manager);
    
    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession != nil"];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:manager
                          handler:^BOOL{
                              self.persister = [manager.currentSession persistenceDelegate];
                              return YES;
                          }];
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:nil];
    
}

- (void)tearDown {
    [super tearDown];
}

- (void)testObserveLts {

    XCTestExpectation *subscriptionExpectation = [self expectationWithDescription:@"Check subscriptions while creating a LogMessage then updating it with lts"];
    
    NSPredicate *ltsPredicate = [NSPredicate predicateWithFormat:@"deviceTs > lts OR lts == nil"];
    
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[self.typePredicate, ltsPredicate]];
    
    STMPersistingObservingSubscriptionID subscriptionId;
    
    subscriptionId = [self.persister observeEntity:PersistingObservingTestEntity
                                         predicate:predicate
                                          callback:^(NSArray *data)
                      {
                          
                          // This should be not called twice
                          // Called twice means merging with lts doesn't set item uploaded
                          
                          [subscriptionExpectation fulfill];

                          XCTAssertEqual(data.count, 1);
                          
                          NSError *error;
                          NSMutableDictionary *toUploadItem = [[data firstObject] mutableCopy];
                          NSString *itemVersion = toUploadItem[@"deviceTs"];
                          
                          toUploadItem[@"ts"] = [STMFunctions stringFromNow];
                          toUploadItem[@"text"] = @"Modify some of the item fields as if it was updated by server";
                          
                          [self.persister mergeSync:PersistingObservingTestEntity
                                         attributes:toUploadItem
                                            options:@{STMPersistingOptionLts:itemVersion,
                                                      STMPersistingOptionReturnSaved:@YES}
                                              error:&error];
                          
                          XCTAssertNil(error);
                          
                      }];
    
    NSError *error;
    
    NSDictionary *item =
    [self.persister mergeSync:PersistingObservingTestEntity
                   attributes:@{@"type": self.testType}
                      options:nil
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
                             options:@{STMPersistingOptionRecordstatuses: @NO}
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
    
    XCTAssertTrue([persister cancelSubscription:subscriptionId]);
    XCTAssertFalse([persister cancelSubscription:subscriptionId]);
    
    NSUInteger count = [persister destroySync:PersistingObservingTestEntity
                                   identifier:item[@"id"]
                                      options:@{STMPersistingOptionRecordstatuses: @NO}
                                        error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(count, 1);
    
    XCTAssertTrue([persister cancelSubscription:subscriptionNotCalledBackId]);
    
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:nil];
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
