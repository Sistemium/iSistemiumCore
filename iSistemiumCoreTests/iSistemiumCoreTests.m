//
//  iSistemiumCoreTests.m
//  iSistemiumCoreTests
//
//  Created by Maxim Grigoriev on 11/04/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STMPredicateToSQL.h"

#define STMAssertSQLFilter(predicate, expectation, ...) \
XCTAssertEqualObjects([STMPredicateToSQL.sharedInstance SQLFilterForPredicate:predicate], expectation, __VA_ARGS__)

@interface iSistemiumCoreTests : XCTestCase

@end

@implementation iSistemiumCoreTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSQLFilters {
    
    NSPredicate *predicate;
    
    predicate = [NSPredicate predicateWithFormat:@"date == %@", @"2017-01-01"];
    
    STMAssertSQLFilter(predicate, @"(date = '2017-01-01')");
    
    predicate = [NSPredicate predicateWithFormat:@"avatarPictureId == %@", nil];
    
    STMAssertSQLFilter(predicate, @"(avatarPictureId IS NULL)");
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", @[@"error", @"important"]];
    
    STMAssertSQLFilter(predicate, @"(type IN ('error','important'))");
    
    predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", @[@{@"id":@"xid"}, @{@"id":@"xid"}]];
    
    STMAssertSQLFilter(predicate, @"(id NOT IN ('xid','xid'))");
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", nil];
    
    STMAssertSQLFilter(predicate, @"(type IN (NULL))");
    
    predicate = [NSPredicate predicateWithFormat:@"SELF.deviceTs > SELF.lts"];
    
    STMAssertSQLFilter(predicate, @"(deviceTs > lts)");
    
    predicate = [NSPredicate predicateWithFormat:@"deviceTs > lts"];
    
    STMAssertSQLFilter(predicate, @"(deviceTs > lts)");
    
    
}

@end
