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
    
    [self prefillWithValues:@[@"0", @"1", @"2", @"3", @"4"]];
    
    NSLog(@"lastLogMessagesArray %@", self.logger.lastLogMessagesArray);
    
    [self noPatternWithValues:@[@"5", @"9"]];
    
    NSArray *pattern = @[@"4", @"5", @"9"];
    [self possiblePatternWithValues:pattern];

    for (NSUInteger i = 0; i < 10; i++) {
        [self detectPatternWithValues:pattern];
    }
    
    [self detectEndOfPatternWithValue:@"0"];
    
    [self noPatternWithValues:@[@"a", @"b"]];

    NSLog(@"lastLogMessagesArray %@", self.logger.lastLogMessagesArray);

}

- (void)prefillWithValues:(NSArray *)values {

    NSUInteger i = 0;
    
    for (NSString *value in values) {

        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", value]};
        
        NSArray *result =
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertEqual(self.logger.lastLogMessagesArray.count, ++i);
        XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
        XCTAssertNotNil(result);

    }

}

- (void)noPatternWithValues:(NSArray *)values {
    
    for (NSString *value in values) {
        
        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", value]};
        
        NSArray *result =
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertTrue(self.logger.lastLogMessagesArray.count <= self.logger.patternDepth);
        XCTAssertEqual(self.logger.possiblePatternArray.count, 0);
        XCTAssertFalse(self.logger.patternDetected);
        XCTAssertEqual(result.count, 1);

    }
    
}

- (void)possiblePatternWithValues:(NSArray *)values {

    for (NSString *value in values) {
    
        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", value]};
        
        NSArray *result =
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertTrue(self.logger.lastLogMessagesArray.count <= self.logger.patternDepth);
        XCTAssertTrue(self.logger.possiblePatternArray.count > 0);
        XCTAssertFalse(self.logger.patternDetected);
        XCTAssertNil(result);

    }

}

- (void)detectPatternWithValues:(NSArray *)values {
    
    for (NSString *value in values) {
    
        BOOL patternAlreadyDetected = self.logger.patternDetected;

        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", value]};
        
        NSArray *result =
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertTrue(self.logger.lastLogMessagesArray.count <= self.logger.patternDepth);
        XCTAssertTrue(self.logger.possiblePatternArray.count > 0);
        XCTAssertTrue(self.logger.patternDetected);
        
        if (patternAlreadyDetected) {
            XCTAssertNil(result);
        } else {
            XCTAssertEqual(result.count, 1);
        }
        
    }
    
}

- (void)detectEndOfPatternWithValue:(NSString *)value {
    
    NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", value]};
    
    NSArray *result =
    [self.logger checkMessageForRepeatingPattern:dic];
    
    XCTAssertTrue(self.logger.lastLogMessagesArray.count <= self.logger.patternDepth);
    XCTAssertTrue(self.logger.possiblePatternArray.count == 0);
    XCTAssertFalse(self.logger.patternDetected);
    
    XCTAssertEqual(result.count, 2);
    
}


@end
