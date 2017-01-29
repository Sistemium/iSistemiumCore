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
                                       andEntityResource:@"STMEntity"
                                                   owner:self];
    }
}

- (void)tearDown {
    [super tearDown];
}

- (void)testConnection {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isReady" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];
    
}

- (void)testFindAllSuccess {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isReady" expectedValue:@YES];

    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:^(NSError * _Nullable error) {
        
        XCTestExpectation *expectFindAll = [self expectationWithDescription:@"Successful findAll"];
        
        NSDictionary *options = @{@"pageSize"   : @(1),
                                  @"offset"     : @"*"};
        
        [self.transport findAllAsync:TEST_SOCKET_ENTITY_NAME
                           predicate:nil
                             options:options
        completionHandlerWithHeaders:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
            
            XCTAssertNotNil(result);
            XCTAssertNotNil(headers);
            XCTAssertNil(error);
            XCTAssertTrue(success);
            
            XCTAssertEqual([result count], 1, @"Pagesize:1 result in one object array");
            
            [expectFindAll fulfill];
            
        }];
        
        [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];

    }];
    
}

- (void)testFindAllError {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isReady" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:^(NSError * _Nullable error) {
        
        XCTestExpectation *expectFindAllError = [self expectationWithDescription:@"Errored findAll"];
        
        [self.transport findAllAsync:[TEST_SOCKET_ENTITY_NAME stringByAppendingString:@"noSuchCollection"] predicate:nil options:@{} completionHandlerWithHeaders:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
            
            XCTAssertNil(result);
            XCTAssertNil(headers);
            XCTAssertNotNil(error);
            XCTAssertFalse(success);
            
            NSLog(@"error: %@", error.localizedDescription);
            
            [expectFindAllError fulfill];
            
        }];
        
        [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];
    
    }];
    
}

- (void)testFindError {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isReady" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:^(NSError * _Nullable error) {
        
        XCTestExpectation *expectFindError = [self expectationWithDescription:@"Errored find"];
        
        [self.transport findAsync:TEST_SOCKET_ENTITY_NAME
                       identifier:[[NSUUID alloc] UUIDString]
                          options:@{}
     completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {
         
             NSLog(@"STMSocketTransportTests find error: %@", error);
             NSLog(@"STMSocketTransportTests find headers: %@", headers);
             
             XCTAssertNotNil(error);
             XCTAssertNil(result);
             XCTAssertFalse(success);
             
             [expectFindError fulfill];
             
         }];
        
        [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];

    }];
    
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
