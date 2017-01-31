//
//  STMPersistingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMCoreSessionManager.h"

@implementation STMPersistingTests

- (void)setUp {
    
    [super setUp];
    
    if (self.persister) return;
    
    STMCoreSessionManager *manager = STMCoreSessionManager.sharedManager;
    
    XCTAssertNotNil(manager);
    
    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession.logger != nil"];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:manager
                          handler:^BOOL{
                              self.persister = [manager.currentSession persistenceDelegate];
                              return YES;
                          }];
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut
                                 handler:nil];
    
}

- (void)tearDown {
    [super tearDown];
}


@end
