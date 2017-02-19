//
//  STMPersistingTests.h
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMPersistingObserving.h"
#import "STMPersistingSync.h"
#import "STMConstants.h"
#import "STMFunctions.h"
#import "STMFakePersisting.h"
#import "STMPersister+Async.h"

#define PersistingTestsTimeOut 5

#define STMPTStartedAt NSDate *startedAt = [NSDate date];
#define STMPTSecondsAfterStartedAt -[startedAt timeIntervalSinceNow]

@interface STMPersistingTests : XCTestCase

@property (nonatomic, strong) id <STMPersistingObserving, STMPersistingSync, STMPersistingAsync, STMPersistingPromised, STMModelling> persister;

@property (nonatomic, strong) STMFakePersistingOptions fakePersistingOptions;
@property (nonatomic, strong) STMFakePersisting *fakePersiser;
@property (nonatomic, weak) STMPersister *realPersister;

@property (nonatomic, strong) NSString *ownerXid;
@property (nonatomic, strong) NSPredicate *cleanupPredicate;
@property (nonatomic, strong) NSDictionary *cleanupOptions;

- (STMFakePersisting *)fakePersistingWithOptions:(STMFakePersistingOptions)options;
- (STMFakePersisting *)inMemoryPersisting;

+ (BOOL)needWaitSession;

- (NSArray *)sampleDataOf:(NSString *)entityName count:(NSUInteger)count;

- (NSUInteger)destroyOwnData:(NSString *)entityName;

@end
