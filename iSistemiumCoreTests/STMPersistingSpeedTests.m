//
//  STMPersistingSpeedTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMLogger.h"

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

- (void)testInsertLargeData{
    
    NSString *entityName = @"STMLogMessage";
    int numberOfLogs = 100;
    __block NSError *error;
    
    NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    
    [self measureBlock:^{
        
        for (int i = 0; i<numberOfLogs;i++){
            
            NSString *messageText = [@"Log message test #" stringByAppendingString:[NSString stringWithFormat:@"%d", i]];
            
            NSDictionary *logMessage = @{@"text":[NSString stringWithFormat:@"%@: %@", [STMFunctions stringFromNow], messageText],
                                         @"type":@"info"};
            
            [self.persister mergeSync:entityName attributes:logMessage options:options error:&error];
            
            XCTAssertNil(error);
            
        }
        
    }];
    
}

- (void)testFindFromLargeData{
    
    NSString *entityName = @"STMLogMessage";
    int numberOfLogs = 10000;
    __block NSError *error;
    
    NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    
    NSMutableArray *logMessages = @[].mutableCopy;
    
    for (int i = 0; i<numberOfLogs;i++){
        
        NSString *messageText = [@"Log message test #" stringByAppendingString:[NSString stringWithFormat:@"%d", i]];
        
        NSDictionary *logMessage = @{@"text":[NSString stringWithFormat:@"%@: %@", [STMFunctions stringFromNow], messageText],
                                     @"type":@"info"};
        
        XCTAssertNil(error);
        
        [logMessages addObject:logMessage];
        
    }
    
    [self.persister mergeManySync:entityName attributeArray:logMessages options:options error:&error];
    
    [self measureBlock:^{
        
        NSArray *rez = [self.persister findAllSync:entityName predicate:[NSPredicate predicateWithFormat:@"type == %@",@"info"] options:nil error:&error];
        
        XCTAssertGreaterThanOrEqual(rez.count, numberOfLogs);
        
        rez = [self.persister findAllSync:entityName predicate:[NSPredicate predicateWithFormat:@"text ENDSWITH %@",@"0"] options:nil error:&error];
        
        XCTAssertGreaterThanOrEqual(rez.count, numberOfLogs % 10);
        
    }];
    
}



@end
