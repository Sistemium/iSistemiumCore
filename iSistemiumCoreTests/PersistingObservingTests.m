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

@end

@implementation PersistingObservingTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testObserveEntity {
    
    STMCoreSessionManager *manager = STMCoreSessionManager.sharedManager;
    
    XCTAssertNotNil(manager);
    
    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession != nil"];
    
    XCTestExpectation *subscriptionExpectation = [self expectationWithDescription:@"Waiting for LogMessage"];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:manager
                          handler:^BOOL
     {
         
         id <STMPersistingObserving, STMPersistingSync> persister = [manager.currentSession persistenceDelegate];
         
         STMPersistingObservingSubscriptionID subscriptionId;
         
         subscriptionId = [persister observeEntity:PersistingObservingTestEntity
                                       predicate:nil
                                        callback:^(NSArray *data) {
                                            NSLog(@"testObserveEntity called back with: %@", data);
                                            [subscriptionExpectation fulfill];
                                        }];
         
         XCTAssertNotNil(subscriptionId);
         
         NSError *error;
         
         NSDictionary *item = [persister mergeSync:PersistingObservingTestEntity
                                        attributes:@{@"type": @"debug"}
                                           options:nil
                                             error:&error];

         XCTAssertNil(error);
         
         XCTAssertTrue([persister cancelSubscription:subscriptionId]);
         XCTAssertFalse([persister cancelSubscription:subscriptionId]);
         
         NSUInteger count = [persister destroySync:PersistingObservingTestEntity
                                        identifier:item[@"id"]
                                           options:@{@"createRecordStatuses": @NO}
                                             error:&error];
         XCTAssertNil(error);
         XCTAssertEqual(count, 1);

         return YES;
         
     }];
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:nil];
}

@end
