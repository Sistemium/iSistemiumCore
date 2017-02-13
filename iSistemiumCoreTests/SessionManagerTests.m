//
//  SessionManagerTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 13/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMCoreSessionManager.h"
#import "STMCoreSession.h"


@interface SessionManagerTests : XCTestCase


@end


@implementation SessionManagerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSessionManager {
    
    STMCoreSessionManager *sm = [STMCoreSessionManager sharedManager];
    
    XCTAssertNotNil(sm);
    XCTAssertEqual(sm.sessions.count, 0);
    XCTAssertNil(sm.currentSession);
    XCTAssertNil(sm.currentSessionUID);
    
    NSString *sessionUID = [STMFunctions uuidString];
    
    STMCoreSession *session = [sm startSessionForUID:sessionUID
                                              iSisDB:nil
                                        authDelegate:nil
                                            trackers:nil
                                       startSettings:nil
                             defaultSettingsFileName:nil];
    
    XCTAssertNotNil(session);
    XCTAssertEqual(sm.sessions.count, 1);
    XCTAssertEqual(sm.currentSession, session);
    XCTAssertEqual(sm.currentSessionUID, session.uid);
    
//    [sm stopSessionForUID:sessionUID];
//
//    XCTAssertNil(session);
//    XCTAssertEqual(sm.sessions.count, 0);
//    XCTAssertNil(sm.currentSession);
//    XCTAssertNil(sm.currentSessionUID);

}


@end
