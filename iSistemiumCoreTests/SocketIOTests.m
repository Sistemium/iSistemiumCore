//
//  SocketIOTests.m
//  iSisSales
//
//  Created by Alexander Levin on 26/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
@import SocketIO;

#define TEST_SOCKETIO_URL @"https://socket2.sistemium.com/socket.io-client"
#define TEST_SOCKETIO_RESOURCE @"dr50/Setting"
#define TEST_SOCKETIO_TIMEOUT 5

@interface SocketIOTests : XCTestCase

@property (nonatomic,strong) SocketIOClient *socket;
@property (nonatomic) BOOL isConnected;

@end

@implementation SocketIOTests

- (void)setUp {
    [super setUp];
    if (!self.socket) [self setupSocket];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testConnection {
    [self keyValueObservingExpectationForObject:self keyPath:@"isConnected" expectedValue:@YES];
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT handler:^(NSError *error) {
    
        XCTAssertNil(error);
        if (error) return;
        
        [self disconnectTest];
        [self timeOutTest];
    
    }];
}

- (void)disconnectTest {
    [self.socket disconnect];
    XCTAssertEqual(self.socket.status, SocketIOClientStatusDisconnected, @"Socket should be disconnected");
}


- (void)timeOutTest {
    
    OnAckCallback *infoAck = [self.socket emitWithAck:@"info" with:@[@{@"key": @"value"}]];
    
    XCTAssertEqual(self.socket.status, SocketIOClientStatusDisconnected, @"Socket should be disconnected");
    
    XCTestExpectation *expectTimeout = [self expectationWithDescription:@"Emit info to disconnected socket"];
    
    NSDate *startedAt = [NSDate date];
    
    [infoAck timingOutAfter:TEST_SOCKETIO_TIMEOUT callback:^(NSArray * _Nonnull result) {
        NSLog(@"SocketIOTests infoAck result: %@", result);
        
        XCTAssertEqualObjects(result.firstObject, @"NO ACK", "Timed out ack result should be 'NO ACK'");
        
        XCTAssertEqualWithAccuracy([startedAt timeIntervalSinceNow], -TEST_SOCKETIO_TIMEOUT, 1);
        
        [expectTimeout fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT*2 handler:^(NSError * _Nullable error) {
        
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
