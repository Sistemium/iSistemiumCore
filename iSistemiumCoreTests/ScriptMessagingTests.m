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

#define SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION @"Expect no errors"

@interface ScriptMessagingTestsExpectation : NSObject

@property (nonatomic,strong) XCTestExpectation * expectation;
@property (nonatomic) NSNumber *count;
@property (nonatomic,strong) NSPredicate *predicate;

+ (instancetype)withExpectation:(XCTestExpectation *)expectation;

@end

@interface ScriptMessagingTests : XCTestCase <STMScriptMessagingOwner>

@property (nonatomic, strong) STMModeller *modeller;
@property (nonatomic, strong) STMScriptMessageHandler *scriptMessenger;
@property (nonatomic, strong) id <STMScriptMessaging> scriptMessagingDelegate;
@property (nonatomic, strong) STMFakePersisting *fakePerster;

@property (nonatomic, strong) NSMutableDictionary <NSString *, ScriptMessagingTestsExpectation *> *expectations;
@property (nonatomic) NSUInteger requestId;

@end


@implementation ScriptMessagingTestsExpectation

+ (instancetype)withExpectation:(XCTestExpectation *)expectation {
    ScriptMessagingTestsExpectation *instance = [[self.class alloc] init];
    instance.expectation = expectation;
    return instance;
}

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
        
        self.scriptMessenger = [[STMScriptMessageHandler alloc] initWithOwner:self];
        self.fakePerster = [STMFakePersisting fakePersistingWithModelName:modelName options:nil];
        self.modeller = self.fakePerster;
        self.scriptMessenger.persistenceDelegate = self.fakePerster;
        self.scriptMessagingDelegate = self.scriptMessenger;
        
        self.requestId = 0;
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


- (void)testFindErrors {
    
    NSString *entityName = @"LogMessage";
    NSString *xid = [STMFunctions uuidString];
    
    // Not Implemented
    
    [self doFindRequest:@{@"entity":entityName,
                          @"id": xid
                          }
                 expect:@"Not implemented"];
    
    // No xid
    
    [self doFindRequest:@{@"entity":entityName} expect:@"empty xid"];
    
    // No Entity
    
    [self doFindRequest:@{} expect:@"entity is not specified"];

    // Not Found
    
    NSDictionary *body;
    NSString *errorDescription;
    
    body = @{@"entity":@"entityName",
             @"id":xid
             };

    errorDescription =
    [NSString stringWithFormat:@"entityName: not found in data model"];
    
    [self doFindRequest:body expect:errorDescription];
    
    // Find with unknown id
    
    self.fakePerster.options = @{STMFakePersistingOptionEmptyDB};
    
    body = [STMFunctions setValue:entityName
                           forKey:@"entity"
                     inDictionary:body];
    
    errorDescription =
    [NSString stringWithFormat:@"no object with xid %@ and entity name %@", xid, entityName];
    
    [self doFindRequest:body expect:errorDescription];
    
    // Update with no data
    
    errorDescription = @"message.body.data for update message is not a NSDictionary class";
    
    [self doUpdateRequest:body expect:errorDescription];
    
    //
    // Now wait because STMScriptMessageHandler is using async promises
    //
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
}


- (void)testUpdateErrors {
    
    NSString *entityName = @"LogMessage";
    NSString *xid = [STMFunctions uuidString];
    NSString *noErrorsDescription = SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION;
    
    NSDictionary *body = @{@"entity":entityName};
    
    self.fakePerster.options = @{STMFakePersistingOptionInMemoryDB};
    
    // Update data
    
    [self doUpdateRequest:[STMFunctions setValue:@{@"id": xid}
                                          forKey:@"data"
                                    inDictionary:body]
                   expect:noErrorsDescription];
    
    // Find Updated with id

    [self doFindRequest:[STMFunctions setValue:xid forKey:@"id" inDictionary:body]
                 expect:noErrorsDescription];
    
    // Create many
    
    NSArray *testArray = @[
                           @{@"text":@"Name 1"},
                           @{@"text":@"Name 2"}
                           ];
    
    [self doUpdateManyRequest:[STMFunctions setValue:testArray
                                              forKey:@"data"
                                        inDictionary:body]
                       expect:noErrorsDescription];
    
    // Find all the created data
    
    [self doFindAllRequest:body expectCount:@(3)];
    
    // Find some of the created data with predicate
    
    NSDictionary *where = @{@"text": @{@"==": @"Name 1"}};
    
    [self doFindAllRequest:[STMFunctions setValue:where forKey:@"where" inDictionary:body]
               expectCount:@(1)];
    
    //
    // Now wait because STMScriptMessageHandler is using async promises
    //
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testDestroy {

    NSString *entityName = @"LogMessage";
    NSString *xid = [STMFunctions uuidString];
    
    self.fakePerster.options = @{STMFakePersistingOptionInMemoryDB};
    
    NSDictionary *body = @{@"entity":entityName};
    
    // Empty xid
    
    [self doDestroyRequest:body expect:@"empty xid"];
    
    [self doDestroyRequest:[STMFunctions setValue:xid forKey:@"id" inDictionary:body]
                    expect:SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self doUpdateRequest:[STMFunctions setValue:@{@"id": xid} forKey:@"data" inDictionary:body]
                   expect:SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION];
    
    [self doDestroyRequest:[STMFunctions setValue:xid forKey:@"id" inDictionary:body]
                    expect:SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION];
    
    [self doFindAllRequest:body expectCount:@(0)];
    
    //
    // Now wait
    //
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
}


- (void)testSubscriptions {
    
    NSString *entityName = @"LogMessage";

    // Test for the callback key should be lowercase
    
    NSDictionary *body = @{
                           @"entities":@[entityName],
                           @"callBack":@"callBack",
                           @"dataCallback":@"dataCallback"
                           };
    
    [self doSubscribeRequest:body expect:@"No callback specified"];
    
    // No dataCallback specified
    
    body = @{
             @"entities":@[entityName],
             @"callback":@"callback"
             };

    [self doSubscribeRequest:body expect:@"No dataCallback specified"];
    
    // Successful subscription
    
    body = @{
             @"entities":@[entityName],
             @"callback":@"callBack",
             @"dataCallback":@"dataCallback"
             };
    
    [self doSubscribeRequest:body expect:@"subscribe to entities success"];
    
    // Merge test data and catch it in delegate
    
    self.fakePerster.options = @{STMFakePersistingOptionInMemoryDB};
    
    NSArray *testArray = @[
                           @{@"text":@"Name 1"},
                           @{@"text":@"Name 2"}
                           ];
    
    [self mergeEntityName:entityName data:testArray];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSArray *testArray2 = @[
                           @{@"text":@"Name 3"},
                           @{@"text":@"Name 4"}
                           ];
    [self mergeEntityName:entityName data:testArray2];
    
    //
    // Now wait because STMScriptMessageHandler is using async promises
    //
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
}

#pragma mark - Private helpers


- (void)mergeEntityName:(NSString *)entityName data:(NSArray <NSDictionary *> *)data {
    
    XCTestExpectation *waitData = [self expectationWithDescription:@"Wait for subscribed data"];
    NSString *xid = [STMFunctions uuidString];
    
    ScriptMessagingTestsExpectation *expectation = [ScriptMessagingTestsExpectation withExpectation:waitData];
    expectation.count = @(data.count);
    expectation.predicate = [NSPredicate predicateWithFormat:@"entity == %@ AND data.ownerXid == %@", entityName, xid];
    
    self.expectations[@"subscription"] = expectation;
    
    data = [STMFunctions mapArray:data withBlock:^id _Nonnull(NSDictionary * _Nonnull value) {
        return [STMFunctions setValue:xid forKey:@"ownerXid" inDictionary:value];
    }];
    
    [self doUpdateManyRequest:[STMFunctions setValue:data
                                              forKey:@"data"
                                        inDictionary:@{@"entity":entityName}]
                       expect:SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION];

}

- (void)doFindRequest:(NSDictionary*)body expect:(NSString *)errorDescription{
    
    [self.scriptMessagingDelegate receiveFindMessage:[self doRequestName:WK_MESSAGE_FIND
                                                                    body:body
                                                             description:errorDescription]];
    
}

- (void)doFindAllRequest:(NSDictionary*)body expectCount:(NSNumber *)count{
    
    STMScriptMessage *message = [self doRequestName:WK_MESSAGE_FIND_ALL
                                               body:body
                                        description:@"Expect no errors"];
    
    self.expectations[message.body[@"requestId"]].count = count;
    
    [self.scriptMessagingDelegate receiveFindMessage:message];
    
}

- (void)doUpdateRequest:(NSDictionary*)body expect:(NSString *)description{
    
    [self.scriptMessagingDelegate receiveUpdateMessage:[self doRequestName:WK_MESSAGE_UPDATE
                                                                      body:body
                                                               description:description]];
    
}


- (void)doUpdateManyRequest:(NSDictionary*)body expect:(NSString *)description{
    
    [self.scriptMessagingDelegate receiveUpdateMessage:[self doRequestName:WK_MESSAGE_UPDATE_ALL
                                                                      body:body
                                                               description:description]];
    
}

- (void)doSubscribeRequest:(NSDictionary *)body expect:(NSString*)description {

    STMScriptMessage *message = [self doRequestName:WK_MESSAGE_SUBSCRIBE
                                               body:body
                                        description:description];

    [self.scriptMessagingDelegate receiveSubscribeMessage:message];
    
}

- (void)doDestroyRequest:(NSDictionary *)body expect:(NSString *)description {
    
    [self.scriptMessagingDelegate receiveDestroyMessage:[self doRequestName:WK_MESSAGE_DESTROY
                                                                       body:body
                                                                description:description]];
    
}


- (STMScriptMessage *)doRequestName:(NSString *)requestName body:(NSDictionary*)body description:(NSString *)description{
    
    NSString *requestId = [NSString stringWithFormat:@"%@", @(++self.requestId)];
    XCTAssertNil(self.expectations[requestId]);
    
    self.expectations[requestId] = [ScriptMessagingTestsExpectation withExpectation:[self expectationWithDescription:description]];
    
    STMScriptMessage *message = [[STMScriptMessage alloc] init];
    
    message.nameSTM = requestName;
    message.bodySTM = [STMFunctions setValue:requestId
                                      forKey:@"requestId"
                                inDictionary:body];
    
    return message;
    
}

#pragma mark - STMScriptMessagingOwner protocol


- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters {
    NSLog(@"ScriptMessagingTests callbackWithData: %@ params: %@", data, parameters);
    
    ScriptMessagingTestsExpectation *expectation = self.expectations[parameters[@"requestId"]];
    XCTAssertNotNil(expectation);
    XCTAssertNotNil(data);
    XCTAssertEqualObjects(SCRIPT_MESSAGING_TEST_NO_ERRORS_DESCRIPTION, expectation.expectation.description);
    NSNumber *count = expectation.count;
    
    if (count) {
        XCTAssertEqual(count.integerValue, data.count);
    }
    
    [expectation.expectation fulfill];

}

- (void)callbackWithError:(NSString *)errorDescription parameters:(NSDictionary *)parameters {
    XCTAssertNotNil(errorDescription);
    NSLog(@"ScriptMessagingTests callbackWithError '%@' params: %@", errorDescription, parameters);
    XCTestExpectation *expectation = self.expectations[parameters[@"requestId"]].expectation;
    if (expectation) {
        XCTAssertEqualObjects(expectation.description, errorDescription);
        [expectation fulfill];
    }
}

- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {

    NSLog(@"ScriptMessagingTests jsCallbackFunction:%@ data:%@ parameters:%@", jsCallbackFunction, data, parameters);
    
    NSString *requestId = parameters[@"requestId"];
    
    if (!requestId) {
        XCTAssertNotNil(jsCallbackFunction);
        requestId =  parameters[@"reason"];
    }
    
    ScriptMessagingTestsExpectation *expectation = self.expectations[requestId];
    XCTAssertNotNil(expectation.expectation);
    
    if ([parameters[@"callBack"] isEqualToString:@"subscribeCallBack"]) {
        XCTAssertEqualObjects(data.firstObject, expectation.expectation.description);
    }
    
    if (expectation.predicate) {
        data = [data filteredArrayUsingPredicate:expectation.predicate];
    }
    
    if (expectation.count) {
        XCTAssertEqual(expectation.count.integerValue, data.count);
    }
    
    [expectation.expectation fulfill];
    
}


@end
