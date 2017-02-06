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

#import "STMCoreSessionManager.h"

#define PersistingTestsTimeOut 5
#define SyncTestsTimeOut 15

@interface STMPersistingTests : XCTestCase

@property (nonatomic, strong) id <STMPersistingObserving, STMPersistingSync, STMPersistingAsync, STMPersistingPromised, STMModelling> persister;

@end
