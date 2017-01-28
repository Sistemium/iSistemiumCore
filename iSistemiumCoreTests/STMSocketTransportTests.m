//
//  STMSocketTransportTests.m
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//


#import <XCTest/XCTest.h>

#import "STMSocketTransport.h"
#import "STMSocketTransportOwner.h"

#define TEST_SOCKET_URL @"https://socket2.sistemium.com/socket.io-client"
#define TEST_SOCKET_ENTITY_NAME @"STMSetting"
#define TEST_SOCKET_RESOURCE @"dr50/Setting"
#define TEST_SOCKET_TIMEOUT 5

@interface STMSocketTransportTests : XCTestCase <STMSocketTransportOwner>

@property (nonatomic,strong) STMSocketTransport *transport;
@property (nonatomic) BOOL isReady;

@end

@implementation STMSocketTransportTests

- (void)setUp {
    
    [super setUp];
    
    if (!self.transport) {
        self.transport = [STMSocketTransport initWithUrl:TEST_SOCKET_URL
                                       andEntityResource:TEST_SOCKET_RESOURCE
                                                   owner:self];
    }
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSocketConnection {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isReady" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:^(NSError *error) {
        
        if (error) {
            return NSLog(@"STMSocketTransportTests testSocketConnection error: %@", error);
        }
        
        [self findAllTest];
        
    }];
    
}

- (void)findAllTest {
    
    XCTestExpectation *expectFindAll = [self expectationWithDescription:@"Successful findAll"];
    XCTestExpectation *expectFindAllError = [self expectationWithDescription:@"Errored findAll"];
    
    NSDictionary *options = @{@"pageSize"   : @(1),
                              @"offset"     : @"*"};

    [self.transport findAllAsync:TEST_SOCKET_ENTITY_NAME predicate:nil options:options completionHandler:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
        
        XCTAssertNotNil(result);
        XCTAssertNotNil(headers);
        XCTAssertNil(error);
        XCTAssertTrue(success);
                
        [expectFindAll fulfill];

    }];
    
//    [self.transport findAllFromResource:TEST_SOCKET_RESOURCE
//                               withETag:@"*"
//                             fetchLimit:1
//                                 params:nil
//                      completionHandler:^(BOOL success, NSArray *data, NSError *error) {
//                          
//                          XCTAssertNotNil(data);
//                          XCTAssertNil(error);
//                          XCTAssertTrue(success);
//                          
//                          id result = [data firstObject];
//                          
//                          XCTAssertNotNil(result, @"findAllTest result is empty");
//                          
//                          XCTAssertTrue([[result class] isSubclassOfClass:NSDictionary.class], @"findAll result firstObject should be a dictionary");
//                          
//                          id resultData = result[@"data"];
//                          
//                          XCTAssertTrue([[resultData class] isSubclassOfClass:NSArray.class], @"findAll result.data should be an array");
//                          
////                          NSLog(@"STMSocketTransportTests findAll result: %@", result);
//                          
//                          [expectFindAll fulfill];
//                          
//                      }];
    
    [self.transport findAllAsync:[TEST_SOCKET_ENTITY_NAME stringByAppendingString:@"noSuchCollection"] predicate:nil options:options completionHandler:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
        
        XCTAssertNil(result);
        XCTAssertNil(headers);
        XCTAssertNotNil(error);
        XCTAssertFalse(success);

        NSLog(@"error: %@", error.localizedDescription);
        
        [expectFindAllError fulfill];
        
    }];

//    [self.transport findAllFromResource:[TEST_SOCKET_RESOURCE stringByAppendingString:@"noSuchCollection"]
//                               withETag:@"*"
//                             fetchLimit:1
//                                 params:nil
//                      completionHandler:^(BOOL success, NSArray *data, NSError *error) {
//                          
//                          XCTAssertNotNil(data);
//                          XCTAssertNil(error);
//                          XCTAssertTrue(success);
//                          
//                          id result = [data firstObject];
//                          
//                          XCTAssertEqualObjects(result[@"error"], @404, @"findAllTest should be 404");
//                          
//                          NSLog(@"STMSocketTransportTests findAll result: %@", result);
//                          
//                          [expectFindAllError fulfill];
//                          
//                      }];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:^(NSError *error) {}];
    
    
}


#pragma mark - STMSocketTransportOwner

- (void)socketReceiveAuthorization {
    
    NSLog(@"STMSocketTransportTests socketReceiveAuthorization");
    self.isReady = YES;
    
}

- (void)socketLostConnection {
    NSLog(@"STMSocketTransportTests socketLostConnection");
}

- (NSTimeInterval)timeout {
    return TEST_SOCKET_TIMEOUT;
}

@end
