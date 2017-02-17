//
//  LoggerPatternTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMLogger.h"


@interface LoggerPatternTests : XCTestCase

@property (nonatomic, strong) STMLogger *logger;


@end

@implementation LoggerPatternTests

- (void)setUp {
    
    [super setUp];
    
    self.logger = [[STMLogger alloc] init];
    
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLoggerPattern {
    
    [self runSimpleTest];
    
}

- (void)runSimpleTest {
 
    self.logger.patternDepth = 5;
    
    for (NSUInteger i = 0; i < self.logger.patternDepth; i++) {
        
        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", @(i)]};
        
        NSArray *result =
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertEqual(self.logger.lastLogMessagesArray.count, i + 1);
        XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
        XCTAssertNotNil(result);
        
    }
    
    [self createNoPatternSimple];
    [self createPatternSimple];
    [self detectPatternSimple];
    [self finishPatternSimple];
    
    NSLog(@"lastLogMessagesArray %@", self.logger.lastLogMessagesArray);
    NSLog(@"possiblePatternArray %@", self.logger.possiblePatternArray);

}

- (void)createNoPatternSimple {
    
    NSArray *result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 1);
    XCTAssertFalse(self.logger.patternDetected);
    XCTAssertNil(result);
    
    result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 2"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
    XCTAssertFalse(self.logger.patternDetected);
    XCTAssertEqual(result.count, 2);

}

- (void)createPatternSimple {
    
    NSArray *result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 1);
    XCTAssertFalse(self.logger.patternDetected);
    XCTAssertNil(result);
    
    result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 2"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertFalse(self.logger.patternDetected);
    XCTAssertNil(result);
    
}

- (void)detectPatternSimple {
    
    NSArray *result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);
    XCTAssertNil(result);

    result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 2"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);
    XCTAssertNil(result);

}

- (void)finishPatternSimple {

    NSArray *result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);
    XCTAssertNil(result);

    result =
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 1"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
    XCTAssertFalse(self.logger.patternDetected);
    XCTAssertEqual(result.count, 1);

}


@end
