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


@interface SyncingDataTests : STMPersistingTests <STMDataSyncingSubscriber>

@property (nonatomic, strong) STMUnsyncedDataHelper *unsyncedDataHelper;


@end

@implementation SyncingDataTests

- (void)setUp {
    
    [super setUp];
    
    self.unsyncedDataHelper = [[STMUnsyncedDataHelper alloc] init];
    self.unsyncedDataHelper.subscriberDelegate = self;

}

- (void)tearDown {
    [super tearDown];
}

- (void)testSync {

    [[STMLogger sharedLogger] saveLogMessageWithText:@"testMessage"];
    
    // ???
    
    [self waitForExpectationsWithTimeout:PersistingTestsTimeOut
                                 handler:nil];

}


#pragma mark - STMDataSyncingSubscriber

- (void)haveUnsyncedObjectWithEntityName:(NSString *)entityName itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    
    NSLog(@"haveUnsyncedObject %@ %@", entityName, itemData[@"id"]);
    
    [self.unsyncedDataHelper setSynced:YES
                                entity:entityName
                              itemData:itemData
                           itemVersion:itemVersion];
    
}


@end
