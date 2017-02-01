//
//  STMFMDBTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMPersister.h"

@interface STMFMDBTests : STMPersistingTests

@property (nonatomic, strong) STMFmdb *fmdb;

@end

@implementation STMFMDBTests

- (void)setUp {
    if (self.fmdb) return;
    [super setUp];
    self.fmdb = [(STMPersister *)self.persister fmdb];
}


- (void)testCount {
    
    NSString *tableName = @"Outlet";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isFantom = 0"];
    
    NSUInteger count = [self.fmdb count:tableName
                          withPredicate:predicate];
    
    XCTAssertTrue(count > 0);
    
    predicate = [NSPredicate predicateWithFormat:@"isFantom = 2"];
    
    count = [self.fmdb count:tableName
               withPredicate:predicate];
    
    XCTAssertTrue(count == 0);
    
    NSError *error;
    
    count = [self.persister countSync:[STMFunctions addPrefixToEntityName:tableName]
                            predicate:[NSPredicate predicateWithFormat:@"partnerId != nil"]
                              options:nil
                                error:&error];
    XCTAssertTrue(count > 0);
    
}

@end
