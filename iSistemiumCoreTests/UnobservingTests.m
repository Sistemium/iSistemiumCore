//
//  UnobservingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 09/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"


// Declare a separate class the instances of which will do persister subscriptions

@interface UnobservingTestsHelper : NSObject

@property (nonatomic, weak) id <STMPersistingObserving> persister;
@property (nonatomic, strong) XCTestExpectation *deallocExpectation;
@property (nonatomic, strong) STMPersistingObservingSubscriptionID subscriptionId;

+ (instancetype)helperWithPersistence:(id <STMPersistingObserving>)persister;

- (STMPersistingObservingSubscriptionID)subscribeExpectation:(XCTestExpectation *)expectation;

@end

@implementation UnobservingTestsHelper

+ (instancetype)helperWithPersistence:(id <STMPersistingObserving>)persister {
    UnobservingTestsHelper *instance = [[self alloc] init];
    instance.persister = persister;
    return instance;
}

- (STMPersistingObservingSubscriptionID)subscribeExpectation:(XCTestExpectation *)expectation {
    
    // Here we do not expect the callback to be called twice
    
    self.subscriptionId = [self.persister observeAllWithPredicate:nil callback:^(NSString *entityName, NSArray *data) {
        NSLog(@"subscribeExpectation entity:%@", entityName);
        [expectation fulfill];
    }];
    
    return self.subscriptionId;
}

// If we do not implement the dealloc then the test will crash

- (void)dealloc {
    if (self.deallocExpectation) {
        NSLog(@"UnobservingTestsHelper dealloc %@", self.subscriptionId);
        [self.persister cancelSubscription:self.subscriptionId];
        [self.deallocExpectation fulfill];
    }
}

@end


@interface UnobservingTests : STMPersistingTests
@end


@implementation UnobservingTests

- (void)setUp {
    self.fakePersistingOptions = @{STMFakePersistingOptionInMemoryDB};
    [super setUp];
}

- (void)testUnobserving {
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Hope this will be fulfilled only once"];
    
    UnobservingTestsHelper *helper = [UnobservingTestsHelper helperWithPersistence:self.persister];
    
    [helper subscribeExpectation:expectation];
    
    // We created an expectation and helper and helper did subscribed to all entities
    
    [self createTestData];
    
    // Now the expectation should be fulfilled
    
    // Comment the following line to see test failed with 'multiple call to fulfill'
    helper.deallocExpectation = [self expectationWithDescription:@"Successful dealloc"];

    helper = nil;
    
    // Persister has a strong ref to the deallocated helper's callback
    // If we do not unsubscribe during deallocation, merging the second bunch of the test data will crash the test
    
    [self createTestData];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
}


- (void)createTestData {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSDictionary *testDataA= @{@"type": @"debug",
                               @"ownerXid": [STMFunctions uuidString],
                               @"text": @"a"};
    
    [self.persister mergeSync:entityName attributes:testDataA options:nil error:&error];
    
    XCTAssertNil(error);
    
}

@end
