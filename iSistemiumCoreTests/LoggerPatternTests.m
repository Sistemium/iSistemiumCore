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

    NSDictionary *dic0 = @{@"test"   : @"test 0"};
    
    [self.logger checkMessageForRepeatingPattern:dic0];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 1);
    XCTAssertFalse(self.logger.patternDetected);

    NSDictionary *dic1 = @{@"test"   : @"test 1"};

    [self.logger checkMessageForRepeatingPattern:dic1];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertFalse(self.logger.patternDetected);

    [self.logger checkMessageForRepeatingPattern:dic0];
    
    XCTAssertEqual(self.logger.lastLogMessagesArray.count, self.logger.patternDepth);
    XCTAssertEqual(self.logger.possiblePatternArray.count, 2);
    XCTAssertTrue(self.logger.patternDetected);


    NSLog(@"lastLogMessagesArray %@", self.logger.lastLogMessagesArray);
    NSLog(@"possiblePatternArray %@", self.logger.possiblePatternArray);
    
}


@end
