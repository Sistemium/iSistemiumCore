//
//  NSJSONSerializationTests.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 21/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface NSJSONSerializationTests : XCTestCase

@end

@implementation NSJSONSerializationTests
    
int testsCount = 100000;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBooleanParse{
    
    NSDictionary *testData = @{@"int data": @1, @"booleanTrueData":@true, @"booleanFalseData":@false};
    
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:testData options:0 error:nil];
    NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(@"{\"booleanTrueData\":1,\"booleanFalseData\":0,\"int data\":1}", JSONString);
    
    testData = [NSDictionary dictionaryWithObjectsAndKeys:(id _Nonnull) kCFBooleanTrue, @"booleanTrueData",
    kCFBooleanFalse, @"booleanFalseData",
                @1, @"int data",
    nil];
    
    JSONData = [NSJSONSerialization dataWithJSONObject:testData options:kNilOptions error:nil];
    JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(@"{\"int data\":1,\"booleanFalseData\":false,\"booleanTrueData\":true}", JSONString);
    
}
    
- (void)testStandartBooleanParseSpeed{
    
    [self measureBlock:^{
        
        for (int i = 0; i < testsCount; i++){
            
            NSDictionary *testData = @{@"int data": @1, @"booleanTrueData":@true, @"booleanFalseData":@false};
            
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:testData options:0 error:nil];
            NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
            
            XCTAssertEqualObjects(@"{\"booleanTrueData\":1,\"booleanFalseData\":0,\"int data\":1}", JSONString);
            
        }
        
    }];
    
}
    
-(void)testkCFBooleanParse{
    
    [self measureBlock:^{
        
        for (int i = 0; i < testsCount; i++){
            
            NSDictionary *testData = [NSDictionary dictionaryWithObjectsAndKeys:(id _Nonnull) kCFBooleanTrue, @"booleanTrueData",
                        kCFBooleanFalse, @"booleanFalseData",
                        @1, @"int data",
                        nil];
            
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:testData options:kNilOptions error:nil];
            NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
            
            XCTAssertEqualObjects(@"{\"int data\":1,\"booleanFalseData\":false,\"booleanTrueData\":true}", JSONString);
            
        }
        
    }];
    
}
    
@end
