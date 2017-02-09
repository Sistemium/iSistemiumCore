//
//  LoggerTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 09/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

#import "STMLogger.h"
#import "STMCoreSessionManager.h"
#import "STMUserDefaults.h"


#define LOG_MESSAGE_ENTITY_NAME @"STMLogMessage"
#define LOGGER_TESTS_TIMEOUT 5

@interface LoggerTests : STMPersistingTests

@property (nonatomic, strong) XCTestExpectation *expectation;


@end


@implementation LoggerTests

+ (BOOL)needWaitSession {
    
    return YES; // this is for test logMessages in persister
//    return NO; // this is for test logMessages in userDefaults
    
}

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLogger {
    
    STMLogMessageType messageType = STMLogMessageTypeImportant;
    
    [[STMLogger sharedLogger] saveLogMessageWithText:@"testMessage 1"
                                             numType:messageType];

    [[STMLogger sharedLogger] saveLogMessageWithText:@"testMessage 2"
                                             numType:messageType];

    if ([self.class needWaitSession]) {
       
        [self performSelector:@selector(checkLogMessagesInPersister)
                   withObject:nil
                   afterDelay:1];
        
    } else {

        [self performSelector:@selector(checkLogMessagesInUserDefaults)
                   withObject:nil
                   afterDelay:1];

    }
    
    self.expectation = [self expectationWithDescription:@"waiting for logger test"];
    
    NSDate *startedAt = [NSDate date];

    [self waitForExpectationsWithTimeout:LOGGER_TESTS_TIMEOUT handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
        
        NSLog(@"testSync expectation handler after %f seconds", -[startedAt timeIntervalSinceNow]);
        
    }];

}

- (void)checkLogMessagesInPersister {
    
    STMLogMessageType messageType = STMLogMessageTypeImportant;

    NSString *type = [[STMLogger sharedLogger] stringTypeForNumType:messageType];
    
    NSPredicate *typePredicate = [NSPredicate predicateWithFormat:@"type == %@", type];
    NSPredicate *unsyncedPredicate = [STMFunctions predicateForUnsyncedObjectsWithEntityName:LOG_MESSAGE_ENTITY_NAME];
    
    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[unsyncedPredicate, typePredicate]];
    
    NSError *error = nil;
    NSArray *logMessages = [self.persister findAllSync:LOG_MESSAGE_ENTITY_NAME
                                             predicate:predicate
                                               options:nil
                                                 error:&error];
    
    XCTAssertNil(error);
    
    NSLog(@"logMessages %@", logMessages);
    
    XCTAssertTrue(logMessages.count == 1);

    [self.expectation fulfill];
    
}

- (void)checkLogMessagesInUserDefaults {
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSArray *loggerDefaults = [defaults arrayForKey:[[STMLogger sharedLogger] loggerKey]];
    NSMutableArray *loggerDefaultsMutable = (loggerDefaults) ? loggerDefaults.mutableCopy : @[].mutableCopy;
    
    STMLogMessageType messageType = STMLogMessageTypeImportant;
    NSString *type = [[STMLogger sharedLogger] stringTypeForNumType:messageType];
    
    NSPredicate *typePredicate = [NSPredicate predicateWithFormat:@"type == %@", type];
    NSArray *logMessages = [loggerDefaultsMutable filteredArrayUsingPredicate:typePredicate];
    
    NSLog(@"logMessages %@", logMessages);
    
    XCTAssertTrue(logMessages.count == 1);

    [self.expectation fulfill];

}


@end