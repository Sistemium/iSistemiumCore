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
@property (nonatomic, strong) NSString *xid;

@end


@implementation LoggerTests

+ (BOOL)needWaitSession {
    
    return YES; // this is for test logMessages in persister
//    return NO; // this is for test logMessages in userDefaults
    
}

- (void)setUp {
    [super setUp];
    self.xid = [STMFunctions uuidString];
}

- (void)testLogger {
    
    STMLogMessageType messageType = STMLogMessageTypeImportant;
    
    [[STMLogger sharedLogger] saveLogMessageWithText:[@"testMessage 1 " stringByAppendingString:self.xid]
                                             numType:messageType];

    [[STMLogger sharedLogger] saveLogMessageWithText:[@"testMessage 2 " stringByAppendingString:self.xid]
                                             numType:messageType];

    if ([self.class needWaitSession]) {
       
        [self performSelector:@selector(checkLogMessagesInPersister)
                   withObject:nil
                   afterDelay:0.1];
        
    } else {

        [self performSelector:@selector(checkLogMessagesInUserDefaults)
                   withObject:nil
                   afterDelay:0.1];

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
    STMSyncer *syncer = [STMSyncer alloc];
    NSPredicate *unsyncedPredicate = [syncer predicateForUnsyncedObjectsWithEntityName:LOG_MESSAGE_ENTITY_NAME];
    
    NSPredicate *selfXidPredicate = [NSPredicate predicateWithFormat: @"text ENDSWITH %@", self.xid];
    
    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[unsyncedPredicate, typePredicate, selfXidPredicate]];
    
    NSError *error = nil;
    NSArray *logMessages = [self.persister findAllSync:LOG_MESSAGE_ENTITY_NAME
                                             predicate:predicate
                                               options:nil
                                                 error:&error];
    
    XCTAssertNil(error);
    
    NSLog(@"logMessages %@", logMessages);
    
    XCTAssertEqual(logMessages.count, 2);

    [self.expectation fulfill];
    
    NSUInteger deletedCount = [self.persister destroyAllSync:LOG_MESSAGE_ENTITY_NAME
                                                   predicate:predicate
                                                     options:@{STMPersistingOptionRecordstatuses:@NO}
                                                       error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(logMessages.count, deletedCount);
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
