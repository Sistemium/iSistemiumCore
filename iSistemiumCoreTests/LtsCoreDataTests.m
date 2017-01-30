//
//  LtsCoreDataTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMPersistingSync.h"
#import "STMCoreSessionManager.h"
#import "STMFunctions.h"


#define LtsCoreDataTestEntity @"STMClientEntity"
#define LtsCoreDataTestEntityNameValue @"Debug"
#define LtsCoreDataTestsTimeOut 10


@interface LtsCoreDataTests : XCTestCase

@property (nonatomic, strong) id <STMPersistingSync> persister;


@end


@implementation LtsCoreDataTests

- (void)setUp {
    
    [super setUp];
    
    if (self.persister) return;
    
    STMCoreSessionManager *manager = STMCoreSessionManager.sharedManager;
    
    XCTAssertNotNil(manager);
    
    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"currentSession != nil"];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:manager
                          handler:^BOOL{
                              self.persister = [manager.currentSession persistenceDelegate];
                              return YES;
                          }];
    
    [self waitForExpectationsWithTimeout:LtsCoreDataTestsTimeOut
                                 handler:nil];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (NSDictionary *)objectForTest {
    
    NSError *error;
    NSMutableDictionary *objProperty = @{}.mutableCopy;
    //    NSString *itemVersion = toUploadItem[@"deviceTs"];
    
    //    toUploadItem[@"ts"] = [STMFunctions stringFromNow];
    objProperty[@"name"] = LtsCoreDataTestEntityNameValue;
    
    NSDictionary *testObject = [self.persister mergeSync:LtsCoreDataTestEntity
                                              attributes:objProperty
                                                 options:@{STMPersistingOptionReturnSaved: @YES}
                                                   error:&error];
    
    XCTAssertNil(error);
    
    NSLog(@"testObject %@", testObject);
    
    NSArray *clientEntities = [self.persister findAllSync:LtsCoreDataTestEntity
                                                predicate:[NSPredicate predicateWithFormat:@"name == %@", LtsCoreDataTestEntityNameValue]
                                                  options:nil
                                                    error:nil];
    
    NSLog(@"clientEntities %@", clientEntities);
    
    XCTAssertEqual(clientEntities.count, 1);
    
    testObject = clientEntities.firstObject;
    
    return testObject;

}

- (void)testMergeSyncInCoreData {
    [self objectForTest];
}

- (void)testLtsInCoreData {
    
    NSDictionary *testObject = [self objectForTest];
    
    XCTAssertNotNil(testObject);
    
    NSMutableDictionary *alteredTestObject = testObject.mutableCopy;
    alteredTestObject[@"eTag"] = [STMFunctions stringFromNow];
    
    NSError *error;

    testObject = [self.persister mergeSync:LtsCoreDataTestEntity
                                attributes:alteredTestObject
                                   options:@{STMPersistingOptionReturnSaved: @YES}
                                     error:&error];
    
    // have to check lts here somehow
    
}


@end
