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
#define LtsCoreDataTestEntityNameValue @"Debug2"
#define LtsCoreDataTestsTimeOut 10


@interface LtsCoreDataTests : XCTestCase

@property (nonatomic, strong) id <STMPersistingSync> persister;
@property (nonatomic, weak) STMDocument *document;


@end


@implementation LtsCoreDataTests

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
                              self.document = [manager.currentSession document];
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
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", LtsCoreDataTestEntityNameValue];
    
    NSArray *clientEntities = [self.persister findAllSync:LtsCoreDataTestEntity
                                                predicate:predicate
                                                  options:nil
                                                    error:nil];
    
    NSLog(@"clientEntities %@", clientEntities);

    return testObject;

}

- (void)testMergeSyncInCoreData {
    
    NSDictionary *object = [self objectForTest];
    NSError *error;
    NSUInteger result = [self.persister destroySync:LtsCoreDataTestEntity
                                         identifier:object[@"id"]
                                            options:@{STMPersistingOptionRecordstatuses:@NO}
                                              error:&error];
    XCTAssertEqual(result, 1);
    XCTAssertNil(error);
}


@end
