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
@property (nonatomic) NSUInteger timesToRepeat;


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
    [self runOneMoreSimpleTest];
    [self runMoreComplicatedTest];
    [self runTestWithNoDetection];
    [self runTestWithTimeDelay];
    
}

- (void)testAsync {
    [self runTestWithAsync];
}

- (void)runSimpleTest {
 
    [self initLoggerWithPatternDepth:5];

    [self prefillWithValues:@[@"0", @"1", @"2", @"3", @"4"]];
    
    [self noPatternWithValues:@[@"5", @"9"]];
    
    [self possiblePatternWithValues:@[@"4", @"5"]];
    
    [self detectPatternWithValues:@[@"9"]];

    self.timesToRepeat = 10;
    NSArray *pattern = @[@"4", @"5", @"9"];
    
    for (NSUInteger i = 0; i < self.timesToRepeat; i++) {
        [self detectPatternWithValues:pattern];
    }
    
    [self detectEndOfPatternWithValue:@"0"];
    
    [self noPatternWithValues:@[@"a", @"b"]];
    
}

- (void)runOneMoreSimpleTest {
    
    [self initLoggerWithPatternDepth:15];
    
    [self prefillWithValues:@[@"3", @"4"]];
    
    [self noPatternWithValues:@[@"9"]];
    
    NSArray *pattern = @[@"9"];
    [self detectPatternWithValues:pattern];
    
    self.timesToRepeat = 5;

    for (NSUInteger i = 0; i < self.timesToRepeat; i++) {
        [self detectPatternWithValues:pattern];
    }
    
    [self detectEndOfPatternWithValue:@"0"];
    
    [self noPatternWithValues:@[@"a", @"b"]];

}

- (void)runMoreComplicatedTest {
    
    [self initLoggerWithPatternDepth:10];
    
    [self prefillWithValues:@[@"3", @"4", @"5", @"6", @"7", @"8", @"9", @"a", @"b", @"c", @"d", @"e"]];

    NSArray *possiblePattern = @[@"5", @"6", @"7", @"8", @"9", @"a", @"b", @"c", @"d"];

    [self possiblePatternWithValues:possiblePattern];

    [self detectPatternWithValues:@[@"e"]];

    self.timesToRepeat = 17;
    NSArray *pattern = @[@"5", @"6", @"7", @"8", @"9", @"a", @"b", @"c", @"d", @"e"];

    for (NSUInteger i = 0; i < self.timesToRepeat; i++) {
        [self detectPatternWithValues:pattern];
    }
    
    [self detectPatternWithValues:@[@"5", @"6"]];
    
    [self detectEndOfPatternWithValue:@"0"];
    
    [self noPatternWithValues:@[@"f", @"g"]];
    
}

- (void)runTestWithNoDetection {
    
    [self initLoggerWithPatternDepth:10];
    
    [self prefillWithValues:@[@"3", @"4", @"5", @"6"]];
    
    NSArray *possiblePattern = @[@"4", @"5"];
    
    [self possiblePatternWithValues:possiblePattern];
    
    self.timesToRepeat = 17;
    NSArray *repeatValues = @[@"7", @"8", @"9", @"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h"];
    
    for (NSUInteger i = 0; i < self.timesToRepeat; i++) {
        [self noPatternWithValues:repeatValues];
    }
    
    [self possiblePatternWithValues:@[@"f", @"g"]];
    [self noPatternWithValues:@[@"8"]];

}

- (void)runTestWithTimeDelay {
    
    [self initLoggerWithPatternDepth:10];
    
    [self prefillWithValues:@[@"1", @"2", @"3"]];
    
    [self possiblePatternWithValues:@[@"1", @"2"]];
    
    XCTestExpectation *expectationOne = [self expectationWithDescription:@"wait 1st delay"];
    XCTestExpectation *expectationTwo = [self expectationWithDescription:@"wait 2nd delay"];
    
    double delayInSeconds = MESSAGE_DELAY_TO_CHECK_PATTERN + 0.1;
    dispatch_time_t popTimeOne = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTimeOne, dispatch_get_main_queue(), ^(void){
        
        [self noPatternWithValues:@[@"3"]];
        
        [expectationOne fulfill];
        
        self.timesToRepeat = 5;
        
        [self possiblePatternWithValues:@[@"1", @"2"]];
        [self detectPatternWithValues:@[@"3"]];
        
        NSArray *pattern = @[@"1", @"2", @"3"];
        
        for (NSUInteger i = 0; i < self.timesToRepeat; i++) {
            [self detectPatternWithValues:pattern];
        }

        dispatch_time_t popTimeTwo = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTimeTwo, dispatch_get_main_queue(), ^(void){
            
            [self detectEndOfPatternWithValue:@"1"];
            
            [self noPatternWithValues:@[@"f", @"g"]];
            
            [expectationTwo fulfill];

        });
        
    });

    NSTimeInterval timeout = MESSAGE_DELAY_TO_CHECK_PATTERN * 2 + 5;
    
    [self waitForExpectationsWithTimeout:timeout handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];

}

- (void)runTestWithAsync {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [self initLoggerWithPatternDepth:5];
        
        [self prefillWithValues:@[@"0", @"1"]];
        
        [self noPatternWithValues:@[@"2", @"3"]];
        
        [self possiblePatternWithValues:@[@"1", @"2"]];
        
        [self detectPatternWithValues:@[@"3"]];
        
        self.timesToRepeat = 1000;
        NSArray *pattern = @[@"1", @"2", @"3"];
        
        for (NSUInteger i = 0; i < self.timesToRepeat; i++) {
            [self detectPatternWithValues:pattern];
        }
        
        [self detectEndOfPatternWithValue:@"0"];
        
        [self noPatternWithValues:@[@"a", @"b"]];
        
    });
    
}

- (void)initLoggerWithPatternDepth:(NSUInteger)patternDepth {
    
    self.logger.lastLogMessagesArray = nil;
    self.logger.possiblePatternArray = nil;
    self.logger.patternDepth = patternDepth;

}


#pragma mark - filling values

- (void)prefillWithValues:(NSArray *)values {
    
    for (NSString *value in values) {

        NSDictionary *dic = @{@"test"   : [NSString stringWithFormat:@"test %@", value]};
        
        NSArray *result =
        [self.logger checkMessageForRepeatingPattern:dic];
        
        XCTAssertTrue(self.logger.lastLogMessagesArray.count <= self.logger.patternDepth);
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
        XCTAssertTrue(result.count > 0);

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
    
    XCTAssertTrue(result.count > 1);
    
    NSDictionary *testDic = result.firstObject;
    NSString *testText = testDic[@"text"];
    
    BOOL textEndsCorrect = [testText hasSuffix:[NSString stringWithFormat:@"%@ times", @(self.timesToRepeat + 1)]];
    
    XCTAssertTrue(textEndsCorrect);
    
}


@end
