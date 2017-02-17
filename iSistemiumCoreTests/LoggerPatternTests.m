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
    
    self.logger.patternDepth = 5;
    
    for (NSUInteger i = 0; i < self.logger.patternDepth; i++) {
        
        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", @(i)]};
        
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertEqual(self.logger.lastLogMessagesArray.count, i + 1);
        XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
        
    }

    [self createNoPattern];
    [self createPattern];
    [self detectPattern];
    [self finishPattern];

    NSLog(@"lastLogMessagesArray %@", self.logger.lastLogMessagesArray);
    NSLog(@"possiblePatternArray %@", self.logger.possiblePatternArray);
    
}

- (void)createNoPattern {
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 1);
    XCTAssertFalse(self.logger.patternDetected);
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 2"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
    XCTAssertFalse(self.logger.patternDetected);

}

- (void)createPattern {
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 1);
    XCTAssertFalse(self.logger.patternDetected);
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 2"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertFalse(self.logger.patternDetected);
    
}

- (void)detectPattern {
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 2"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);

}

- (void)finishPattern {

    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 0"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);
    
    [self.logger checkMessageForRepeatingPattern:@{@"test"   : @"test 1"}];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
    XCTAssertFalse(self.logger.patternDetected);

}


@end
