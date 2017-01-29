//
//  PersistingObservingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STMPersistingObserving.h"
#import "STMCoreSessionManager.h"
#import "STMConstants.h"

#define PersistingObservingTestsTimeOut 10

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
    
    XCTAssertNotNil(STMCoreSessionManager.sharedManager);
    
    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession != nil"];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:STMCoreSessionManager.sharedManager
                          handler:^BOOL
     {
         
         id <STMPersistingObserving> persister = [STMCoreSessionManager.sharedManager.currentSession persistenceDelegate];
         
         STMPersistingObservingSubscriptionID subscription;
         
         subscription = [persister observeEntity:@"STMLogMessage"
                                       predicate:nil
                                        callback:^(NSArray *data) {
                                            
                                        }];
         
         XCTAssertNotNil(subscription);
         
         XCTAssertTrue([persister cancelSubscription:subscription]);
         
         return YES;
         
     }];
    
    [self waitForExpectationsWithTimeout:PersistingObservingTestsTimeOut
                                 handler:nil];
}

@end