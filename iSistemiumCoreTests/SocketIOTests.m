//
//  SocketIOTests.m
//  iSisSales
//
//  Created by Alexander Levin on 26/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
@import SocketIO;

#import "STMFunctions.h"

#define TEST_SOCKETIO_URL @"https://socket2.sistemium.com/socket.io-client"
#define TEST_SOCKETIO_RESOURCE @"dr50/Setting"
#define TEST_SOCKETIO_TIMEOUT 2

@interface SocketIOTests : XCTestCase

@property (nonatomic,strong) SocketIOClient *socket;
@property (nonatomic) BOOL isConnected;

@end

@implementation SocketIOTests

- (void)setUp {
    [super setUp];
    [self setupSocket];
}

- (void)tearDown {
    [super tearDown];
    [self.socket disconnect];
    self.socket = nil;
    self.isConnected = NO;
}

- (void)testConnection {
    [self keyValueObservingExpectationForObject:self keyPath:@"isConnected" expectedValue:@YES];
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT handler:^(NSError *error) {
    
        XCTAssertNil(error);
        if (error) return;
        
        [self disconnectTest];
    
    }];
}

- (void)disconnectTest {
    [self.socket disconnect];
    XCTAssertEqual(self.socket.status, SocketIOClientStatusDisconnected, @"Socket should be disconnected");
}


- (void)testTimedOutEmitToConnectedSocket {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isConnected" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT handler:^(NSError * _Nullable error) {

        XCTAssertNil(error);
        
        XCTestExpectation *expectTimeout = [self expectationWithDescription:@"Emit unknown event to a connected socket"];
        
        OnAckCallback *infoAck = [self.socket emitWithAck:@"__unknown__" with:@[@{@"key": @"value"}]];
        
        NSDate *startedAt = [NSDate date];
        
        [infoAck timingOutAfter:TEST_SOCKETIO_TIMEOUT callback:^(NSArray * _Nonnull result) {
            NSLog(@"SocketIOTests infoAck result: %@", result);
            
            XCTAssertEqualObjects(result.firstObject, @"NO ACK", "Timed out ack result should be 'NO ACK'");
            
            XCTAssertEqualWithAccuracy([startedAt timeIntervalSinceNow], -TEST_SOCKETIO_TIMEOUT, 1);
            
            [expectTimeout fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT*2 handler:nil];

    }];
    
}

- (void)testTimedOutEmitOnDisconnectedSocket {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isConnected" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
        
        [self.socket disconnect];
        XCTAssertEqual(self.socket.status, SocketIOClientStatusDisconnected, @"Socket should be disconnected");
        
        XCTestExpectation *expectTimeout = [self expectationWithDescription:@"Emit 'info' to a disconnected socket"];
        
        OnAckCallback *infoAck = [self.socket emitWithAck:@"info" with:@[@{@"key": @"value"}]];
        
        NSDate *startedAt = [NSDate date];
        
        [infoAck timingOutAfter:TEST_SOCKETIO_TIMEOUT callback:^(NSArray * _Nonnull result) {
            NSLog(@"SocketIOTests infoAck result: %@", result);
            
            XCTAssertEqualObjects(result.firstObject, @"NO ACK", "Timed out ack result should be 'NO ACK'");
            
            XCTAssertEqualWithAccuracy([startedAt timeIntervalSinceNow], -TEST_SOCKETIO_TIMEOUT, 1);
            
            [expectTimeout fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT*2 handler:nil];
        
    }];
    
}

- (void)testEmitInfoDuringReconnect {
    
    [self keyValueObservingExpectationForObject:self keyPath:@"isConnected" expectedValue:@YES];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
        
        XCTestExpectation *expectTimeout = [self expectationWithDescription:@"Emit 'info' to a disconnected socket that will be reconnected after"];
        
        NSDictionary *info = @{@"emittedAt": [STMFunctions stringFromNow]};
        
        [self.socket reconnect];
        
        XCTAssertEqual(self.socket.status, SocketIOClientStatusConnecting, @"Socket should be connecting");
        
        OnAckCallback *infoAck = [self.socket emitWithAck:@"info" with:@[info]];
        
        // Started writting this test i expected that socket engine keeps emits in a queue and emits them after reconnect, but it's not
        
        [infoAck timingOutAfter:TEST_SOCKETIO_TIMEOUT callback:^(NSArray * _Nonnull result) {
            NSLog(@"SocketIOTests testEmitOnReconnectedSocket result: %@", result);
            
            XCTAssertEqualObjects(result.firstObject, @"NO ACK", "Timed out ack result should be 'NO ACK'");
            
            [expectTimeout fulfill];
        }];
        
        XCTestExpectation *expectReconnect = [self expectationWithDescription:@"Wait for reconnecting is done"];
        
        [self.socket once:@"connect" callback:^(NSArray *data, SocketAckEmitter *ack) {
            XCTAssertNotNil(data);
            [expectReconnect fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT*2 handler:nil];
        
    }];
    
}


- (void)setupSocket {
    
    NSURL *socketUrl = [NSURL URLWithString:TEST_SOCKETIO_URL];
    NSString *path = [socketUrl.path stringByAppendingString:@"/"];
    NSDictionary *config = @{
        @"voipEnabled": @YES,
        @"log": @NO,
        @"forceWebsockets": @NO,
        @"path": path,
        @"reconnects": @YES
        };
    
    self.socket = [[SocketIOClient alloc] initWithSocketURL:socketUrl
                                                     config:config];
    
    [self.socket connect];

    [self.socket on:@"connect" callback:^(NSArray *data, SocketAckEmitter *ack) {
        self.isConnected = true;
    }];
}

@end
