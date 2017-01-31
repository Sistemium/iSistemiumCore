//
//  LtsCoreDataTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

#define LtsCoreDataTestEntity @"STMClientEntity"
#define LtsCoreDataTestEntityNameValue @"Debug2"
#define LtsCoreDataTestsTimeOut 10


@interface LtsCoreDataTests : STMPersistingTests
@end


@implementation LtsCoreDataTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (NSDictionary *)objectForTest {
    
    NSError *error;
    NSMutableDictionary *objProperty = @{}.mutableCopy;

    objProperty[@"name"] = LtsCoreDataTestEntityNameValue;
    
    NSDictionary *testObject = [self.persister mergeSync:LtsCoreDataTestEntity
                                              attributes:objProperty
                                                 options:@{STMPersistingOptionReturnSaved: @YES}
                                                   error:&error];
    
    XCTAssertNil(error);
    
    NSLog(@"testObject %@", testObject);
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", LtsCoreDataTestEntityNameValue];
    
    NSArray *clientEntities = [self.persister findAllSync:LtsCoreDataTestEntity
                                                predicate:predicate
                                                  options:nil
                                                    error:nil];
    
    NSLog(@"clientEntities %@", clientEntities);

    return testObject;

}

- (void)testMergeSyncInCoreData {
    
    NSDictionary *object = [self objectForTest];
    NSError *error;
    NSUInteger result = [self.persister destroySync:LtsCoreDataTestEntity
                                         identifier:object[@"id"]
                                            options:@{STMPersistingOptionRecordstatuses:@NO}
                                              error:&error];
    XCTAssertEqual(result, 1);
    XCTAssertNil(error);
}


@end
