//
//  PersistingAsyncTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

@interface PersistingAsyncTests : STMPersistingTests

@end

@implementation PersistingAsyncTests


-(void)testErrors{
    
    [self.fakePersiser setOption:STMFakePersistingOptionCheckModelKey
                           value:@(YES)];
    
    NSString *entityName = @"UnknownEntity";
    
    XCTestExpectation *findAllAsync = [self expectationWithDescription:@"findAllAsync"];
    
    [self.persister findAllAsync:entityName
                       predicate:nil
                         options:nil
               completionHandler:^(BOOL success, NSArray *result, NSError *error) {
                   XCTAssertNotNil(error);
                   XCTAssertFalse(success);
                   [findAllAsync fulfill];
               }];

    XCTestExpectation *destroyAllAsync = [self expectationWithDescription:@"destroyAllAsync"];
    
    [self.persister destroyAllAsync:entityName
                          predicate:nil
                            options:nil
                  completionHandler:^(BOOL success, NSUInteger result, NSError *error) {
                      XCTAssertNotNil(error);
                      XCTAssertFalse(success);
                      [destroyAllAsync fulfill];
                  }];
    
    XCTestExpectation *findAsync = [self expectationWithDescription:@"findAsync"];
    
    [self.persister findAsync:entityName
                    identifier:entityName
                      options:nil
            completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
                XCTAssertNotNil(error);
                XCTAssertFalse(success);
                [findAsync fulfill];
            }];
    
    XCTestExpectation *destroyAsync = [self expectationWithDescription:@"destroyAsync"];
    
    [self.persister destroyAsync:entityName
                      identifier:entityName
                         options:nil
               completionHandler:^(BOOL success, NSError *error) {
                   XCTAssertNotNil(error);
                   XCTAssertFalse(success);
                   [destroyAsync fulfill];
               }];
    
    XCTestExpectation *mergeAsync = [self expectationWithDescription:@"mergeAsync"];
    
    [self.persister mergeAsync:entityName
                    attributes:@{}
                       options:nil
             completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
                 XCTAssertNotNil(error);
                 XCTAssertFalse(success);
                 [mergeAsync fulfill];
             }];

    XCTestExpectation *mergeManyAsync = [self expectationWithDescription:@"mergeManyAsync"];
    
    [self.persister mergeManyAsync:entityName
                    attributeArray:@[@{}]
                           options:nil
                 completionHandler:^(BOOL success, NSArray *result, NSError *error) {
                     XCTAssertNotNil(error);
                     XCTAssertFalse(success);
                     [mergeManyAsync fulfill];
                 }];
     

    [self waitForExpectationsWithTimeout:1 handler:nil];

}


@end
