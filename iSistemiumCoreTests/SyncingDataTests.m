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

@interface SyncingDataTests : STMPersistingTests <STMDataSyncingSubscriber>

@property (nonatomic, strong) STMUnsyncedDataHelper *unsyncedDataHelper;
@property (nonatomic, strong) XCTestExpectation *syncedExpectation;

@end

@implementation SyncingDataTests

- (void)setUp {
    
    [super setUp];
    
    if (!self.unsyncedDataHelper) {
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SYNCING_DATA_TEST_ASYNC_DELAY)), dispatch_get_main_queue(), ^{
    
        [self.unsyncedDataHelper setSynced:YES
                                    entity:entityName
                                  itemData:itemData
                               itemVersion:itemVersion];
        
        [self.syncedExpectation fulfill];
        
    });

    
}


@end
