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

    [self.persister destroyAllAsync:entityName
                          predicate:nil
                            options:nil
                  completionHandler:^(BOOL success, NSUInteger result, NSError *error) {
                      XCTAssertNotNil(error);
                      XCTAssertFalse(success);
                  }];
    
    [self.persister findAsync:entityName
                    identifier:entityName
                      options:nil
            completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
                XCTAssertNotNil(error);
                XCTAssertFalse(success);
            }];
    
    [self.persister destroyAsync:entityName
                      identifier:entityName
                         options:nil
               completionHandler:^(BOOL success, NSError *error) {
                   XCTAssertNotNil(error);
                   XCTAssertFalse(success);
               }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

}


@end
