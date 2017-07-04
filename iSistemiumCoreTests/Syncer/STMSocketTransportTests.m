//
//  STMSocketTransportTests.m
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//


#import <XCTest/XCTest.h>

#import "STMSocketTransport+Persisting.h"
#import "STMSocketConnectionOwner.h"

#define TEST_SOCKET_URL @"https://socket2.sistemium.com/socket.io-client"
#define TEST_SOCKET_ENTITY_NAME @"STMSetting"
#define TEST_SOCKET_TIMEOUT 5

@interface STMSocketTransportTests : XCTestCase <STMSocketConnectionOwner>

@property (nonatomic,strong) STMSocketTransport *transport;
@property (nonatomic) BOOL isReady;

@end

@implementation STMSocketTransportTests

- (void)setUp {
    
    [super setUp];
    
    if (!self.transport) {
        self.transport = [STMSocketTransport transportWithUrl:TEST_SOCKET_URL
                                            andEntityResource:STM_ENTITY_NAME
                                                        owner:self
                                     remotePersistingDelegate:nil];
        [self waitConnection];
    }
}

- (void)tearDown {
    [super tearDown];
}

- (void)waitConnection {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isReady" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];
    
}

- (void)testFindAllSuccess {
    
    XCTestExpectation *expectFindAll = [self expectationWithDescription:@"Successful findAll"];
    
    NSDictionary *options = @{STMPersistingOptionPageSize: @(1),
                              @"offset"     : @"*"};
    
    [self findAllTestEntityWithOptions:options
                     completionHandler:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
        
        XCTAssertNotNil(result);
        XCTAssertNotNil(headers);
        XCTAssertNil(error);
        XCTAssertTrue(success);
        
        XCTAssertEqual([result count], 1, @"Pagesize:1 result in one object array");
        
        XCTAssertTrue([result.firstObject isKindOfClass:NSDictionary.class]);
        
        XCTAssertNotNil(result.firstObject[@"name"]);
        XCTAssertNotNil(result.firstObject[@"group"]);
        
        [expectFindAll fulfill];
        
    }];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];

    
}

- (void)findAllTestEntityWithOptions:(NSDictionary *)options
                   completionHandler:(STMPersistingWithHeadersAsyncArrayResultCallback)completionHandler {
    
    [self.transport findAllAsync:TEST_SOCKET_ENTITY_NAME
                       predicate:nil
                         options:options
    completionHandlerWithHeaders:completionHandler];
    
}

- (void)testFindSuccess {
    
    XCTestExpectation *expectFind = [self expectationWithDescription:@"Successful find"];
    
    NSDictionary *options = @{STMPersistingOptionPageSize: @(1)};
    
    [self findAllTestEntityWithOptions:options
                     completionHandler:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error)
    {
    
        XCTAssertTrue(result.count == 1);
        NSString *pk = result.firstObject[@"id"];
        
        [self.transport findAsync:TEST_SOCKET_ENTITY_NAME
                       identifier:pk
                          options:options
     completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {
         
         XCTAssertNotNil(result);
         XCTAssertNotNil(headers);
         XCTAssertNil(error);
         XCTAssertTrue(success);
         
         XCTAssertNotNil(result[@"name"]);
         XCTAssertNotNil(result[@"group"]);
         
         [expectFind fulfill];
         
     }];
        

    
    }];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];
    
}

- (void)testMergeSuccess {
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Successful merge"];
    NSDictionary *attributes = @{
                                 @"type": @"debug",
                                 @"id": NSUUID.UUID.UUIDString,
                                 @"text": @"testMergeSuccess",
                                 @"source": @"SocketTransportTests"
                                 };
    
    [self.transport    mergeAsync:@"STMLogMessage"
                       attributes:attributes
                          options:nil
     completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {
          
         XCTAssertNotNil(result);
         XCTAssertNotNil(headers);
         XCTAssertNil(error);
         XCTAssertTrue(success);
         
         XCTAssertNotNil(result[@"type"]);
         XCTAssertNotNil(result[@"text"]);
         
         NSLog(@"testMergeSuccess result: %@", result);
         [expectation fulfill];
          
     }];

    [self waitForExpectationsWithTimeout:TEST_SOCKET_TIMEOUT handler:nil];
    
}

- (void)testFindAllError {
    
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

    
}

- (void)testFindError {
    
    
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

}


#pragma mark - STMSocketConnectionOwner

- (void)socketReceiveAuthorization {
    
    NSLog(@"STMSocketTransportTests socketReceiveAuthorization");
    self.isReady = YES;
    
}

- (void)socketWillClosed {
    NSLog(@"STMSocketTransportTests socketWillClosed");
}

- (void)socketLostConnection {
    NSLog(@"STMSocketTransportTests socketLostConnection");
}

- (NSTimeInterval)timeout {
    return TEST_SOCKET_TIMEOUT;
}

- (void)socketAuthorizationError:(NSError *)error {
    // TODO: test socketAuthorizationError
}

@end
