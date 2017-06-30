//
//  STMFMDBTests.m
//  iSisSales
//
//  Created by Alexander Levin on 01/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMPersister.h"
#import "STMFmdb+Transactions.h"

@interface STMFMDBTests : STMPersistingTests

@property (nonatomic, strong) STMFmdb *fmdb;

@end

@implementation STMFMDBTests

- (void)setUp {
    if (self.fmdb) return;
    [super setUp];
    
}


- (void)testCount {
    
    
#warning needs to be rewriten, since pool is no longer used
//    NSString *tableName = @"Outlet";
//    
//    [self.fmdb.pool inDatabase:^(FMDatabase *db) {
//
//        STMFmdbTransaction *transaction = [STMFmdbTransaction persistingTransactionWithFMDatabase:db stmFMDB:self.fmdb];
//        
//        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isFantom = 0"];
//        NSError *error;
//
//        NSUInteger count = [transaction count:tableName predicate:predicate options:nil error:&error];
//        
//        XCTAssertTrue(count > 0);
//        
//        predicate = [NSPredicate predicateWithFormat:@"isFantom = 2"];
//        
//        count = [transaction count:tableName predicate:predicate options:nil error:&error];
//        
//        XCTAssertTrue(count == 0);
//        
//    }];
    
    
}

@end
