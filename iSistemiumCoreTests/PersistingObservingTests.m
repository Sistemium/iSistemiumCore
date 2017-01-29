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

    XCTestExpectation *subscriptionExpectation = [self expectationWithDescription:@"Waiting for callBack"];
    NSArray *testData = @[@{@"type": self.testType}, @{@"type": @"error"}];
    
    __block STMPersistingObservingSubscriptionID subscriptionId;
    
    subscriptionId = [self.persister observeEntity:PersistingObservingTestEntity
                                         predicate:self.typePredicate
                                          callback:^(NSArray * _Nullable data) {
                                              XCTAssertEqual(data.count, 1);
                                              [subscriptionExpectation fulfill];
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
                                 }];
}

@end
