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
@property (nonatomic, strong) NSMutableDictionary <NSString *, XCTestExpectation *> *syncedExpectations;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSString *> *testObjects;
@property (nonatomic, strong) NSString *pkToWait;

@end

@implementation SyncingDataTests

- (void)setUp {
    
    [super setUp];
    
    if (!self.unsyncedDataHelper) {
        
//        Uncomment to see test magically failed
        self.unsyncedDataHelper = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persister
                                                                                subscriber:self];
//        self.unsyncedDataHelper = [[STMUnsyncedDataHelper alloc] init];
//        self.unsyncedDataHelper.persistenceDelegate = self.persister;
//        self.unsyncedDataHelper.subscriberDelegate = self;
    }

}

- (void)tearDown {
    [super tearDown];
}

- (void)testSync {

    XCTAssertNotNil(self.unsyncedDataHelper.persistenceDelegate);
    
    self.pkToWait = [NSUUID UUID].UUIDString;
    
    [self createTestData];
    
    NSDate *startedAt = [NSDate date];
    
    self.unsyncedDataHelper.syncingState = [[STMDataSyncingState alloc] init];
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut handler:^(NSError * _Nullable error) {

        XCTAssertNil(error);

        [self.testObjects enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull objectId, NSString * _Nonnull entityName, BOOL * _Nonnull stop) {
           
            NSError *localError = nil;
            
            BOOL result = [self.persister destroySync:entityName
                                           identifier:objectId
                                              options:nil
                                                error:&localError];
            
            XCTAssertTrue(result);
            XCTAssertNil(localError);
            
        }];
        
        NSLog(@"testSync expectation handler after %f seconds", -[startedAt timeIntervalSinceNow]);
        
    }];

}

- (void)createTestData {
    
    self.syncedExpectations = @{}.mutableCopy;
    self.testObjects = @{}.mutableCopy;
    
    NSDictionary *testAttributes = @{@"source"      : @"SyncingDataTests",
                                     @"ownerXid"    : self.pkToWait};
    
    NSString *entityName = @"STMLogMessage";
    NSMutableDictionary *logMessageAttributes = testAttributes.mutableCopy;
    logMessageAttributes[@"text"] = @"testMessage";
    logMessageAttributes[@"type"] = @"important";
    
    NSError *error = nil;
    NSDictionary *logMessage = [self.persister mergeSync:entityName
                                              attributes:logMessageAttributes
                                                 options:nil
                                                   error:&error];

    XCTAssertNotNil(logMessage);

    NSString *logMessageId = logMessage[@"id"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for sync logMessage"];
    self.syncedExpectations[logMessageId] = expectation;
    self.testObjects[logMessageId] = entityName;
    
    entityName = @"STMPartner";
    NSMutableDictionary *partnerAttributes = testAttributes.mutableCopy;
    partnerAttributes[@"name"] = @"testPartner";

    NSDictionary *partner = [self.persister mergeSync:entityName
                                           attributes:partnerAttributes
                                              options:nil
                                                error:&error];
    
    XCTAssertNotNil(partner);

    NSString *partnerId = partner[@"id"];
    expectation = [self expectationWithDescription:@"wait for sync partner"];
    self.syncedExpectations[partnerId] = expectation;
    self.testObjects[partnerId] = entityName;

    
    entityName = @"STMOutlet";
    NSMutableDictionary *outletAttributes = testAttributes.mutableCopy;
    outletAttributes[@"name"] = @"testOutlet";
    outletAttributes[@"partnerId"] = partnerId;

    NSDictionary *outlet = [self.persister mergeSync:entityName
                                          attributes:outletAttributes
                                             options:nil
                                               error:&error];
    
    XCTAssertNotNil(outlet);

    NSString *outletId = outlet[@"id"];
    expectation = [self expectationWithDescription:@"wait for sync outlet"];
    self.syncedExpectations[outletId] = expectation;
    self.testObjects[outletId] = entityName;

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
        
        if ([itemData[@"ownerXid"] isEqualToString:self.pkToWait]) {
            
            XCTestExpectation *expectation = self.syncedExpectations[itemData[@"id"]];
            [expectation fulfill];
            
        }
        
    });
    
}


@end
