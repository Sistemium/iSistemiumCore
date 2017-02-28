//
//  FilingTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 28/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMFiling.h"
#import "STMFunctions.h"

#define TEST_ORG @"testOrg"
#define TEST_UID @"testUid"
#define SHARED_PATH @"shared"


@interface FilingTests : XCTestCase

@end


@interface STMDirectoring : NSObject <STMDirectoring>

@end


@implementation STMDirectoring

@end


@interface STMFiling : NSObject <STMFiling>

@end


@implementation STMFiling

@end


@implementation FilingTests

- (void)setUp {
    
    [super setUp];
    
}

- (void)tearDown {

    [super tearDown];
    
}

- (void)testDirectoring {
    
}



@end
