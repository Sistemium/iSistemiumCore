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
#import "STMCoreAuthController.h"


@interface SessionManagerTests : XCTestCase <STMCoreAuth>

@property (nonatomic, strong) STMCoreSessionManager *sessionManager;
@property (nonatomic) NSUInteger numberOfSessions;
@property (nonatomic, strong) NSMutableArray *sessionsUIDs;
@property (nonatomic, strong) NSMutableArray *runningSessionsUIDs;
@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, strong) NSString *removedSessionUID;
@property (nonatomic) BOOL haveAuthSession;


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

- (BOOL)haveAuthSession {
    return [STMCoreAuthController authController].controllerState == STMAuthSuccess;
}

- (void)testSessionManager {

    _userID = @"testUserID";
    
    NSDate *startedAt = [NSDate date];
    self.expectation = [self expectationWithDescription:@"waiting for session stop"];

    self.sessionManager = [STMCoreSessionManager sharedManager];
    
    NSUInteger count = self.haveAuthSession ? 1 : 0;
    
    XCTAssertNotNil(self.sessionManager);
    XCTAssertEqual(self.sessionManager.sessions.count, count);
    
    if (self.haveAuthSession) {
        
        XCTAssertNotNil(self.sessionManager.currentSession);
        XCTAssertNotNil(self.sessionManager.currentSessionUID);
        
    } else {
        
        XCTAssertNil(self.sessionManager.currentSession);
        XCTAssertNil(self.sessionManager.currentSessionUID);
        
    }

    self.numberOfSessions = 2;
    self.sessionsUIDs = @[].mutableCopy;
    self.runningSessionsUIDs = @[].mutableCopy;

    for (NSUInteger i = 1; i <= self.numberOfSessions; i++) {

        _userID = [self.userID stringByAppendingString:[NSString stringWithFormat:@"_%@", @(i)]];
        
        count = self.haveAuthSession ? i + 1 : i;

        [self.sessionsUIDs addObject:[self startSomeSession]];
        XCTAssertEqual(self.sessionManager.sessions.count, count);
        
    }
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
        
        NSLog(@"testSync expectation handler after %f seconds", -[startedAt timeIntervalSinceNow]);
        
    }];
    
}

- (NSString *)startSomeSession {
    
    NSString *sessionUID = [STMFunctions uuidString];
    
    STMCoreSession *session = [self.sessionManager startSessionWithAuthDelegate:self
                                                                       trackers:nil
                                                                  startSettings:nil
                                                        defaultSettingsFileName:nil];
    
    XCTAssertNotNil(session);
    XCTAssertEqual(self.sessionManager.currentSession, session);
    XCTAssertEqual(self.sessionManager.currentSessionUID, session.uid);

    NSPredicate *waitForSession = [NSPredicate predicateWithFormat:@"status == %d", STMSessionRunning];
    
    [self expectationForPredicate:waitForSession
              evaluatedWithObject:session
                          handler:^BOOL{
                              
                              NSLog(@"%@ session == STMSessionRunning", session.uid);
                              
                              [self.runningSessionsUIDs addObject:session.uid];
                              
                              if (self.runningSessionsUIDs.count == self.numberOfSessions) {
                                  [self stopSession];
                              }
                              
                              return YES;
                              
    }];

    return sessionUID;
    
}

- (void)stopSession {
    
    NSLogMethodName;
    
    self.removedSessionUID = self.runningSessionsUIDs.firstObject;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRemoved:)
                                                 name:NOTIFICATION_SESSION_REMOVED
                                               object:self.sessionManager];
    
    [self.runningSessionsUIDs removeObject:self.removedSessionUID];
    [self.sessionManager stopSessionForUID:self.removedSessionUID];

}

- (void)sessionRemoved:(NSNotification *)notification {
    
    NSString *uid = notification.userInfo[@"uid"];
    
    if ([self.removedSessionUID isEqualToString:uid]) {
        
        NSUInteger sessionsCount = self.haveAuthSession ? self.runningSessionsUIDs.count + 1 : self.runningSessionsUIDs.count;

        XCTAssertEqual(self.sessionManager.sessions.count, sessionsCount);
        XCTAssertNotEqual(self.sessionManager.currentSessionUID, uid);
        
        [self.expectation fulfill];
        
    }
    
}


#pragma mark - STMCoreAuth

@synthesize userName = _userName;
@synthesize userID = _userID;
@synthesize lastAuth = _lastAuth;
@synthesize accountOrg = _accountOrg;
@synthesize controllerState = _controllerState;
@synthesize iSisDB = _iSisDB;

- (void)logout {
    
}

- (NSURLRequest *)authenticateRequest:(NSURLRequest *)request {
    return nil;
}


@end
