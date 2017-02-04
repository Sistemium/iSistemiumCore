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

//#define SYNCING_DATA_TEST_ASYNC_DELAY PersistingTestsTimeOut / 5 * NSEC_PER_SEC
#define SYNCING_DATA_TEST_ASYNC_DELAY 0.5 * NSEC_PER_SEC
#define SYNCING_DATA_TEST_DISPATCH_TIME dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SYNCING_DATA_TEST_ASYNC_DELAY))
#define SYNCING_DATA_TEST_SOURCE @"SyncingDataTests"

@interface SyncingDataTests : STMPersistingTests <STMDataSyncingSubscriber>

@property (nonatomic, strong) STMUnsyncedDataHelper *unsyncedDataHelper;
@property (nonatomic, weak) id <STMDataSyncing> dataSyncingDelegate;
@property (nonatomic, strong) NSMutableDictionary <NSString *, XCTestExpectation *> *syncedExpectations;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSString *> *testObjects;
@property (nonatomic, strong) NSString *pkToWait;

@end

@implementation SyncingDataTests

- (void)setUp {
    
    [super setUp];
    
    if (!self.unsyncedDataHelper) {
        self.unsyncedDataHelper = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persister subscriber:self];
        self.dataSyncingDelegate = self.unsyncedDataHelper;
        XCTAssertNotNil(self.unsyncedDataHelper.persistenceDelegate);
    }

}

- (void)tearDown {
    [super tearDown];
}

- (void)testSync {

    self.pkToWait = [STMFunctions uuidString];
    NSLog(@"self.pkToWait %@", self.pkToWait);
    
    [self createTestData];
    
    NSDate *startedAt = [NSDate date];
    
    [self.dataSyncingDelegate startSyncing];
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut handler:^(NSError * _Nullable error) {

        XCTAssertNil(error);

        NSArray *testEntities = [self.testObjects.allValues valueForKeyPath:@"@distinctUnionOfObjects.self"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"source == %@", SYNCING_DATA_TEST_SOURCE];
        
        for (NSString *entityName in testEntities) {
            
            NSError *localError = nil;
            
            NSUInteger result = [self.persister destroyAllSync:entityName
                                                     predicate:predicate
                                                       options:@{STMPersistingOptionRecordstatuses:@NO}
                                                         error:&localError];
            
            NSLog(@"testSync cleanup destroy: %@ (%@)", entityName, @(result));
            XCTAssertNil(localError);
            
        }
        
        NSLog(@"testSync expectation handler after %f seconds", -[startedAt timeIntervalSinceNow]);
        
    }];

}

- (void)createTestData {
    
    self.syncedExpectations = @{}.mutableCopy;
    self.testObjects = @{}.mutableCopy;
    
    [self createTestObject:@"STMLogMessage" withAttributes:@{@"text"    : @"testMessage",
                                                             @"type"    : @"important"}];

    NSDictionary *partnerOne = [self createTestObject:@"STMPartner" withAttributes:@{@"name": @"testPartner"}];
    
    [self createTestObject:@"STMOutlet" withAttributes:@{@"name"        : @"testOutlet",
                                                         @"partnerId"   : partnerOne[@"id"]}];

    [self createTestObject:@"STMOutlet" withAttributes:@{@"name"        : @"testOutlet2",
                                                         @"partnerId"   : partnerOne[@"id"]}];

    NSDictionary *partnerTwo = [self createTestObject:@"STMPartner" withAttributes:@{@"name": @"testPartner2"}];
    
    [self createTestObject:@"STMOutlet" withAttributes:@{@"name"        : @"testOutlet3",
                                                         @"partnerId"   : partnerTwo[@"id"]}];

    NSDictionary *outlet = [self createTestObject:@"STMOutlet" withAttributes:@{@"name"        : @"testOutlet4",
                                                                                @"partnerId"   : partnerOne[@"id"]}];

    [self createTestObject:@"STMOutletPhoto" withAttributes:@{@"outletId"   : outlet[@"id"]}];
    
    NSLog(@"self.testObjects %@", self.testObjects);

}

- (NSDictionary *)createTestObject:(NSString *)entityName withAttributes:(NSDictionary *)attributes {
    
    NSDictionary *testAttributes = @{@"source"      : SYNCING_DATA_TEST_SOURCE,
                                     @"ownerXid"    : self.pkToWait};
    
    NSMutableDictionary *objectAttributes = testAttributes.mutableCopy;
    
    [attributes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        objectAttributes[key] = obj;
    }];
    
    NSError *error = nil;
    NSDictionary *object = [self.persister mergeSync:entityName
                                          attributes:objectAttributes
                                             options:nil
                                               error:&error];
    
    XCTAssertNotNil(object);

    NSString *objectId = object[@"id"];
    NSString *expectationDescription = [NSString stringWithFormat:@"wait for sync %@ %@", entityName, objectId];
    XCTestExpectation *expectation = [self expectationWithDescription:expectationDescription];
    self.syncedExpectations[objectId] = expectation;
    self.testObjects[objectId] = entityName;
    
    return object;
    
}


#pragma mark - STMDataSyncingSubscriber

- (void)haveUnsyncedObjectWithEntityName:(NSString *)entityName
                                itemData:(NSDictionary *)itemData
                             itemVersion:(NSString *)itemVersion {
    
    NSString *source = itemData[@"source"];
    
    NSArray *testEntities = [self.testObjects.allValues valueForKeyPath:@"@distinctUnionOfObjects.self"];
    BOOL isNotTestEntities = ![testEntities containsObject:entityName];
    BOOL isNotTestSource = [source isEqual:NSNull.null] || ![source isEqualToString:@"SyncingDataTests"];
    BOOL isNotCurrentTest = ![itemData[@"ownerXid"] isEqual:self.pkToWait];
    
    BOOL isNotTheExpectedData = isNotTestEntities || isNotTestSource || isNotCurrentTest;
    
    if (isNotTheExpectedData) {
        [self.dataSyncingDelegate setSynced:NO
                                     entity:entityName
                                   itemData:itemData
                                itemVersion:itemVersion];
        return;
    };
    
    NSLog(@"haveUnsyncedObject %@ %@", entityName, itemData);
    
    XCTAssertNotNil(itemVersion);
    XCTAssertNotNil(itemData);
    
//    dispatch_async(dispatch_get_main_queue(), ^{
    dispatch_after(SYNCING_DATA_TEST_DISPATCH_TIME, dispatch_get_main_queue(), ^{
    
        [self.dataSyncingDelegate setSynced:YES
                                     entity:entityName
                                   itemData:itemData
                                itemVersion:itemVersion];
        
        XCTestExpectation *expectation = self.syncedExpectations[itemData[@"id"]];
        [expectation fulfill];
        
    });
    
}


@end
