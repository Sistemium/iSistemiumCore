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

#define PersistingTestsTimeOut 5

@interface STMPersistingTests : XCTestCase

@property (nonatomic, strong) id <STMPersistingObserving, STMPersistingSync, STMPersistingAsync, STMPersistingPromised, STMModelling> persister;

@property (nonatomic, strong) STMFakePersistingOptions fakePersistingOptions;
@property (nonatomic, strong) STMFakePersisting *fakePersiser;

@property (nonatomic, strong) NSString *ownerXid;

- (STMFakePersisting *)fakePersistingWithOptions:(STMFakePersistingOptions)options;
- (STMFakePersisting *)inMemoryPersisting;

+ (BOOL)needWaitSession;

- (NSArray *)sampleDataOf:(NSString *)entityName ownerXid:(NSString *)ownerXid count:(NSUInteger)count;

- (NSUInteger)destroyOwnData:(NSString *)entityName;

@end
