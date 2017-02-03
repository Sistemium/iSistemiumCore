//
//  ScriptMessagingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STMModeller.h"
#import "STMPersistingPromised.h"
#import "STMCoreAuthController.h"
#import "STMScriptMessageHandler+Predicates.h"
#import "STMFakePersisting.h"

@interface ScriptMessagingTests : XCTestCase <STMScriptMessagingOwner>

@property (nonatomic, strong) STMModeller *modeller;
@property (nonatomic, strong) STMScriptMessageHandler *scriptMessenger;
@property (nonatomic, strong) id <STMScriptMessaging> scriptMessagingDelegate;
@property (nonatomic, strong) STMFakePersisting *fakePerster;

@property (nonatomic, strong) NSMutableDictionary <NSString *, XCTestExpectation *> *expectations;

@end

@interface STMScriptMessage : WKScriptMessage

@property (nonatomic,strong) NSString *nameSTM;
@property (nonatomic,strong) id bodySTM;

@end

@implementation STMScriptMessage

- (NSString *)name {
    return self.nameSTM;
}

- (id)body {
    return self.bodySTM;
}

@end

@implementation ScriptMessagingTests

- (void)setUp {
    
    self.expectations = [NSMutableDictionary dictionary];
    
    [super setUp];
    
    if (!self.modeller) {
        NSString *modelName = [STMCoreAuthController.authController dataModelName];
        
        self.modeller = [STMModeller modellerWithModel:[STMModeller modelWithName:modelName]];
        self.scriptMessenger = [[STMScriptMessageHandler alloc] initWithOwner:self];
        self.fakePerster = [STMFakePersisting fakePersistingWithOptions:nil];
        
        self.scriptMessenger.persistenceDelegate = self.fakePerster;
        self.scriptMessenger.modellingDelegate = self.modeller;
        
        self.scriptMessagingDelegate = self.scriptMessenger;
    }
    
    self.fakePerster.options = nil;
    
}

- (void)testWhereFilter {
    
    NSString *entityName = @"STMPartner";
    NSError *error;
    
    XCTAssertTrue([self.modeller isConcreteEntityName:entityName]);
    
    STMScriptMessagingWhereFilterDictionary *whereFilter
    =@{
       @"name": @{@"==": @"test"}
       };
    
    NSPredicate *predicate =
    [self.scriptMessenger predicateForEntityName:entityName
                                          filter:nil
                                     whereFilter:whereFilter
                                           error:&error];
    
    XCTAssertNil(error);
    
    NSString *predicateString = [NSString stringWithFormat:@"%@", predicate];
    
    NSString *expectedString = [NSString stringWithFormat:@"name == \"%@\"", @"test"];
    
    XCTAssertEqualObjects(predicateString, expectedString);
    
}

- (void)testWhereFilterANY {
    
    NSString *entityName = @"STMOutlet";
    NSError *error;
    
    XCTAssertTrue([self.modeller isConcreteEntityName:entityName]);
    
    NSUUID *xid = [NSUUID UUID];
    
    STMScriptMessagingWhereFilterDictionary *whereFilter
    =@{
       @"ANY outletSalesmanContracts": @{
               @"salesmanId": @{@"==": xid.UUIDString}
               }
       };
    
    NSPredicate *predicate =
    [self.scriptMessenger predicateForEntityName:entityName
                                          filter:nil
                                     whereFilter:whereFilter
                                           error:&error];
    
    XCTAssertNil(error);
    
    NSString *predicateString = [NSString stringWithFormat:@"%@", predicate];
    
    NSString *expectedString = [NSString stringWithFormat:@"ANY outletSalesmanContracts.salesman.xid == %@", [STMFunctions UUIDDataFromNSUUID:xid]];
    
    XCTAssertEqualObjects(predicateString, expectedString);
    
    
}


- (void)testFindError {
    
    NSString *entityName = @"LogMessage";
    NSString *xid = [STMFunctions uuidString];
    
    // Not Implemented
    
    [self doFindRequestId:@"1"
                     body:@{@"entity":entityName,
                            @"id": xid
                            }
                   expect:@"Not implemented"];
    
    // No xid
    
    [self doFindRequestId:@"2"
                     body:@{@"entity":entityName}
                   expect:@"empty xid"];
    
    // No Entity
    
    [self doFindRequestId:@"3"
                     body:@{}
                   expect:@"entity is not specified"];

    // Not Found
    
    NSDictionary *body;
    NSString *errorDescription;
    
    body = @{@"entity":@"entityName",
             @"id":xid
             };

    errorDescription =
    [NSString stringWithFormat:@"entityName: not found in data model"];
    
    [self doFindRequestId:@"4"
                     body:body
                   expect:errorDescription];
    
    // Find with unknown id
    
    self.fakePerster.options = @{STMFakePersistingOptionEmptyDB};
    
    body = [STMFunctions setValue:entityName
                           forKey:@"entity"
                     inDictionary:body];
    
    errorDescription =
    [NSString stringWithFormat:@"no object with xid %@ and entity name %@", xid, entityName];
    
    [self doFindRequestId:@"5"
                     body:body
                   expect:errorDescription];
    
    // Update with no data
    
    errorDescription = @"message.body.data for update message is not a NSDictionary class";
    
    [self.scriptMessagingDelegate receiveUpdateMessage:[self expect:WK_MESSAGE_UPDATE
                                                          requestId:@"6"
                                                               body:body
                                                             description:errorDescription]];
    
    //
    // Now wait because STMScriptMessageHandler is using async promises
    //
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
}


#pragma mark - Private helpers


- (void)doFindRequestId:(NSString *)requestId body:(NSDictionary*)body expect:(NSString *)errorDescription{
    
    [self.scriptMessagingDelegate receiveFindMessage:[self expect:WK_MESSAGE_FIND
                                                        requestId:requestId
                                                             body:body
                                                           description:errorDescription]];
    
}


- (STMScriptMessage *)expect:(NSString *)requestName requestId:(NSString *)requestId body:(NSDictionary*)body description:(NSString *)description{
    
    XCTAssertNil(self.expectations[requestId]);
    
    self.expectations[requestId] = [self expectationWithDescription:description];
    
    STMScriptMessage *message = [[STMScriptMessage alloc] init];
    
    message.nameSTM = requestName;
    message.bodySTM = [STMFunctions setValue:requestId
                                      forKey:@"requestId"
                                inDictionary:body];
    
    return message;
    
}

#pragma mark - STMScriptMessagingOwner protocol


- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters {
    XCTAssertNoThrow(@"not expected");
}

- (void)callbackWithError:(NSString *)errorDescription parameters:(NSDictionary *)parameters {
    XCTAssertNotNil(errorDescription);
    NSLog(@"ScriptMessagingTests callbackWithError '%@' params: %@", errorDescription, parameters);
    XCTestExpectation *expectation = self.expectations[parameters[@"requestId"]];
    if (expectation) {
        XCTAssertEqualObjects(expectation.description, errorDescription);
        [expectation fulfill];
    }
}

- (void)callbackWithData:(id)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    XCTAssertNoThrow(@"not expected");
}


@end
