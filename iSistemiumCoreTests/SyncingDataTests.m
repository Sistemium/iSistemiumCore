//
//  SyncingDataTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

#import "STMUnsyncedDataHelper.h"
#import "STMLogger.h"

#define SYNCING_DATA_TEST_ASYNC_DELAY PersistingTestsTimeOut / 5 * NSEC_PER_SEC
#define SYNCING_DATA_TEST_DISPATCH_TIME dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SYNCING_DATA_TEST_ASYNC_DELAY))

@interface SyncingDataTests : STMPersistingTests <STMDataSyncingSubscriber>

@property (nonatomic, strong) STMUnsyncedDataHelper *unsyncedDataHelper;
@property (nonatomic, strong) XCTestExpectation *syncedExpectation;

@end

@implementation SyncingDataTests

- (void)setUp {
    
    [super setUp];
    
    if (!self.unsyncedDataHelper) {
        
//        Uncomment to see test magically failed
//        self.unsyncedDataHelper = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persister
//                                                                                subscriber:self];
        self.unsyncedDataHelper = [[STMUnsyncedDataHelper alloc] init];
        self.unsyncedDataHelper.persistenceDelegate = self.persister;
        self.unsyncedDataHelper.subscriberDelegate = self;
    }

}

- (void)tearDown {
    [super tearDown];
}

- (void)testSync {

    XCTAssertNotNil(self.unsyncedDataHelper.persistenceDelegate);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for sync"];
    
    self.syncedExpectation = expectation;
    
    NSDictionary *attributes = @{
                                 @"text": @"testMessage",
                                 @"type": @"important",
                                 @"source": @"SyncingDataTests"
                                 };
    
    [self.persister mergeAsync:@"STMLogMessage"
                    attributes:attributes
                       options:nil
             completionHandler:^(BOOL success, NSDictionary *logMessage, NSError *error) {
                 XCTAssertNotNil(logMessage);
             }];
    
//    NSError *error;
//    
//    [self.persister mergeSync:@"STMLogMessage"
//                   attributes:attributes
//                      options:nil
//                        error:&error];

    
    
    NSDate *startedAt = [NSDate date];
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut
                                 handler:^(NSError * _Nullable error)
    {
        NSLog(@"testSync expectation handler after %f seconds", -[startedAt timeIntervalSinceNow]);
    }];

}


#pragma mark - STMDataSyncingSubscriber

- (void)haveUnsyncedObjectWithEntityName:(NSString *)entityName
                                itemData:(NSDictionary *)itemData
                             itemVersion:(NSString *)itemVersion {
    
    NSString *source = itemData[@"source"];
    
    BOOL isNotTheExpecteedData = !([entityName isEqualToString:@"STMLogMessage"] && ![source isEqual:NSNull.null] && [source isEqualToString:@"SyncingDataTests"]);
    
    if (isNotTheExpecteedData) {
        [self.unsyncedDataHelper setSynced:NO
                                    entity:entityName
                                  itemData:itemData
                               itemVersion:itemVersion];
        return;
    };
    
    NSLog(@"haveUnsyncedObject %@ %@", entityName, itemData);
    
    XCTAssertNotNil(itemVersion);
    XCTAssertNotNil(itemData);

    dispatch_after(SYNCING_DATA_TEST_DISPATCH_TIME, dispatch_get_main_queue(), ^{
    
        [self.unsyncedDataHelper setSynced:YES
                                    entity:entityName
                                  itemData:itemData
                               itemVersion:itemVersion];
        
        [self.syncedExpectation fulfill];
        
    });

    
}


@end
