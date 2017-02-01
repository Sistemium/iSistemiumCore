//
//  PersistingSyncTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

@interface PersistingSyncTests : STMPersistingTests

@end

@implementation PersistingSyncTests

- (void)testCountSync {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSPredicate *predicate;

    NSUInteger countAll = [self.persister countSync:entityName
                                          predicate:predicate
                                            options:nil
                                              error:&error];
    XCTAssertTrue(countAll > 0);

    predicate = [NSPredicate predicateWithFormat:@"type in (%@)", @[@"important"]];
    
    NSUInteger count = [self.persister countSync:entityName
                                       predicate:predicate
                                         options:nil
                                           error:&error];
    
    XCTAssertTrue(count > 0);
    XCTAssertTrue(count != countAll);
    
    NSLog(@"testCountSync result: %lu %@ records of %lu total", (unsigned long)count, entityName, (unsigned long)countAll);
    
}

- (void)testCountSyncWithOptions {

    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    NSPredicate *predicate;
    
    NSDictionary *options;

    NSUInteger count = [self.persister countSync:entityName
                                          predicate:predicate
                                            options:options
                                              error:&error];
    
    
    XCTAssertTrue(count > 0, @"There should be some data");
    
    options = @{STMPersistingOptionFantoms:@YES};
    
    count = [self.persister countSync:entityName
                            predicate:predicate
                              options:options
                                error:&error];
    
    XCTAssertTrue(count == 0, @"There should be no fantoms");
    
    options = @{STMPersistingOptionForceStorage: @(STMStorageTypeCoreData)};
    
    count = [self.persister countSync:entityName
                            predicate:predicate
                              options:options
                                error:&error];
    
    XCTAssertTrue(count == 0, @"There should be no data in CoreData");
    
}

@end
