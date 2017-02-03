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
@property (nonatomic, strong) id <STMPersistingSync, STMPersistingPromised> fakePerster;

@property (nonatomic, strong) XCTestExpectation *errorExpectation;

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
    
    self.errorExpectation = nil;
    
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
    
}

- (void)testFindError {
    
    self.errorExpectation = [self expectationWithDescription:@"wait for callback"];
    
    STMScriptMessage *message = [[STMScriptMessage alloc] init];
    
    message.nameSTM = WK_MESSAGE_FIND;
    message.bodySTM = @{};
    
    [self.scriptMessagingDelegate receiveFindMessage:message];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
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


#pragma mark - STMScriptMessagingOwner protocol

- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters {
    
}

- (void)callbackWithError:(NSString *)errorDescription parameters:(NSDictionary *)parameters {
    XCTAssertNotNil(errorDescription);
    NSLog(@"ScriptMessagingTests callbackWithError %@ %@", errorDescription, parameters);
    [self.errorExpectation fulfill];
}

- (void)callbackWithData:(id)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
}


@end
