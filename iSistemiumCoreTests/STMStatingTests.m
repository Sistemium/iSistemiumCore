//
//  STMStatingTests.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 31/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STMCoreApplication.h"

@interface STMCustomStates : NSObject<STMStating>

@end

@implementation STMCustomStates

@synthesize networkActivityIndicatorVisible;

@end

@interface STMStatingTests : XCTestCase

@end

@implementation STMStatingTests

- (void)tearDown {
    [super tearDown];
    [STMCoreApplication sharedApplication].states = nil;
}

-(void)testNetworkActivityIndicatorVisible{
    XCTAssertTrue([STMCoreApplication sharedApplication].networkActivityIndicatorVisible);
}

-(void)testCustomNetworkActivityIndicatorVisible{
    
    STMCustomStates *customStates = [[STMCustomStates alloc] init];
    
    [customStates setNetworkActivityIndicatorVisible:NO];
    
    [STMCoreApplication sharedApplication].states = customStates;
    
    XCTAssertFalse([STMCoreApplication sharedApplication].networkActivityIndicatorVisible);
}

@end
