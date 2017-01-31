//
//  STMPersistingSpeedTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

@interface STMPersistingSpeedTests : STMPersistingTests

@end

@implementation STMPersistingSpeedTests

- (void)setUp {
    [super setUp];
}


- (void)testBunchOfFindSpeed {
    
    NSString *sourceEntityName = @"STMOutlet";
    NSString *parentEntity = @"STMPartner";
    NSString *parentKey = @"partnerId";
    
    __block NSError *error;
    
    NSArray *sourceArray = [self.persister findAllSync:sourceEntityName
                                             predicate:nil
                                               options:@{STMPersistingOptionPageSize:@500}
                                                 error:&error];
    XCTAssertNil(error);
    XCTAssertNotEqual(sourceArray.count, 0, @"There should be some sourceArray data to test");
    
    NSLog(@"testFindSpeed will do %lu find requests to '%@'",
          (unsigned long)sourceArray.count, parentEntity);
    
    NSDate *startedAt = [NSDate date];
    
    [self measureBlock:^{
        for (NSDictionary *item in sourceArray) {
            
            if (!item[parentKey]) continue;
            
            [self.persister findSync:parentEntity
                          identifier:item[parentKey]
                             options:nil
                               error:&error];
            
            XCTAssertNil(error);
        }
    }];
    
    NSLog(@"testFindSpeed measured %lu finds per seconds", - (unsigned long) (10.0 * sourceArray.count / [startedAt timeIntervalSinceNow]));
}

@end
