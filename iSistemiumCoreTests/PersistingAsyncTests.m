//
//  PersistingAsyncTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

#define PATExpectation(name) \
XCTestExpectation *name = [self expectationWithDescription:@"name"];

#define PATExpectErrorBody(expectation) \
    XCTAssertNotNil(error); \
    XCTAssertFalse(success); \
    [expectation fulfill]; \
}


#define PATExpectArrayError(expectation) \
    ^(STMP_ASYNC_ARRAY_RESULT_CALLBACK_ARGS) { \
    PATExpectErrorBody(expectation)

#define PATExpectDictionaryError(expectation) \
    ^(STMP_ASYNC_DICTIONARY_RESULT_CALLBACK_ARGS) { \
        PATExpectErrorBody(expectation)

#define PATExpectIntegerError(expectation) \
    ^(STMP_ASYNC_INTEGER_RESULT_CALLBACK_ARGS) { \
        PATExpectErrorBody(expectation)

#define PATExpectError(expectation) \
    ^(STMP_ASYNC_NORESULT_CALLBACK_ARGS) { \
        PATExpectErrorBody(expectation)


@interface PersistingAsyncTests : STMPersistingTests

@end

@implementation PersistingAsyncTests


-(void)testErrors{
    
    [self.fakePersiser setOption:STMFakePersistingOptionCheckModelKey
                           value:@(YES)];
    
    NSString *entityName = @"UnknownEntity";
    
    PATExpectation(findAllAsync)
    
    [self.persister findAllAsync:entityName
                       predicate:nil
                         options:nil
               completionHandler:PATExpectArrayError(findAllAsync)];

    PATExpectation(destroyAllAsync)
    
    [self.persister destroyAllAsync:entityName
                          predicate:nil
                            options:nil
                  completionHandler:PATExpectIntegerError(destroyAllAsync)];
    
    PATExpectation(findAsync)
    
    [self.persister findAsync:entityName
                    identifier:entityName
                      options:nil
            completionHandler:PATExpectDictionaryError(findAsync)];
    
    PATExpectation(destroyAsync)
    
    [self.persister destroyAsync:entityName
                      identifier:entityName
                         options:nil
               completionHandler:PATExpectError(destroyAsync)];
    
    PATExpectation(mergeAsync)
    
    [self.persister mergeAsync:entityName
                    attributes:@{}
                       options:nil
             completionHandler:PATExpectDictionaryError(mergeAsync)];

    PATExpectation(mergeManyAsync)
    
    [self.persister mergeManyAsync:entityName
                    attributeArray:@[@{}]
                           options:nil
                 completionHandler:PATExpectArrayError(mergeManyAsync)];
     

    [self waitForExpectationsWithTimeout:1 handler:nil];

}


@end
