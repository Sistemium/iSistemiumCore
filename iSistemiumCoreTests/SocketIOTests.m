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
    [self waitForExpectationsWithTimeout:TEST_SOCKETIO_TIMEOUT handler:^(NSError *error) {}];
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
