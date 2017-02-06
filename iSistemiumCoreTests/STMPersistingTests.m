//
//  STMPersistingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFunctions.h"
#import "STMPersistingTests.h"
#import "STMCoreSessionManager.h"
#import "STMCoreAuthController.h"

@implementation STMPersistingTests

+ (BOOL)needWaitSession {
    return NO;
}

- (void)setUp {

    [super setUp];
    
    if ([STMFunctions.currentTestTarget hasSuffix:@"InMemory"]) {
        NSLog(@"STMPersistingTests will persist to memory!");
        self.fakePersistingOptions = @{STMFakePersistingOptionInMemoryDB};
        self.waitForSession = [self.class needWaitSession] && !self.persister;
    }
    
    // Create an empty FakePersister if there are options
    
    if (self.fakePersistingOptions) {
        [self fakePersistingWithOptions:self.fakePersistingOptions];
    }

    if (self.persister && !self.waitForSession) return;
    
    // Otherwise wait for the session to start and get it's persister if needed
    
    STMCoreSessionManager *manager = STMCoreSessionManager.sharedManager;
    
    XCTAssertNotNil(manager);
    
    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession.logger != nil"];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:manager
                          handler:^BOOL{
                              if (!self.persister) {
                                  self.persister = [manager.currentSession persistenceDelegate];
                              }
                              self.waitForSession = NO;
                              return YES;
                          }];
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut
                                 handler:nil];
    
}

- (void)tearDown {
    [super tearDown];
}

- (STMFakePersisting *)fakePersistingWithOptions:(STMFakePersistingOptions)options {
    
    NSString *modelName = [STMCoreAuthController.authController dataModelName];
    
    self.fakePersiser = [STMFakePersisting fakePersistingWithModelName:modelName options:options];
    self.persister = self.fakePersiser;
    return self.fakePersiser;
}

- (STMFakePersisting *)inMemoryPersisting {
    return [self fakePersistingWithOptions:@{STMFakePersistingOptionInMemoryDB}];
}

@end
