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

@interface ScriptMessagingTests : XCTestCase <STMScriptMessagingOwner>

@property (nonatomic, strong) STMModeller *modeller;
@property (nonatomic, strong) STMScriptMessageHandler *scriptMessenger;

@end

@implementation ScriptMessagingTests

- (void)setUp {
    [super setUp];
    if (!self.modeller) {
        NSString *modelName = [STMCoreAuthController.authController dataModelName];
        self.modeller = [STMModeller modellerWithModel:[STMModeller modelWithName:modelName]];
        self.scriptMessenger = [[STMScriptMessageHandler alloc] initWithOwner:self];
        self.scriptMessenger.modellingDelegate = self.modeller;
    }
}

- (void)tearDown {
    [super tearDown];
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
    
    NSString *xid = @"7998f0143e83491fac972717e77fa0ff";
    
    STMScriptMessagingWhereFilterDictionary *whereFilter
    =@{
       @"ANY outletSalesmanContracts": @{
               @"salesmanId": @{@"==": xid}
               }
       };
    
    NSPredicate *predicate =
    [self.scriptMessenger predicateForEntityName:entityName
                                          filter:nil
                                     whereFilter:whereFilter
                                           error:&error];
    
    XCTAssertNil(error);
    
    NSString *predicateString = [NSString stringWithFormat:@"%@", predicate];
    
    NSString *expectedString = @"ANY outletSalesmanContracts.salesman.xid == <7998f014 3e83491f ac972717 e77fa0ff>";
    
    XCTAssertEqualObjects(predicateString, expectedString);
    
    
}


#pragma mark - STMScriptMessagingOwner protocol

- (void)callbackWithData:(NSArray *)data parameters:(NSDictionary *)parameters {
    
}

- (void)callbackWithError:(NSString *)errorDescription parameters:(NSDictionary *)parameters {
    
}

- (void)callbackWithData:(id)data parameters:(NSDictionary *)parameters jsCallbackFunction:(NSString *)jsCallbackFunction {
    
}

@end
