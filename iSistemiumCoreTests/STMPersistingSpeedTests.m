//
//  STMPersistingSpeedTests.m
//  iSisSales
//
//  Created by Alexander Levin on 31/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#define STMPersistingSpeedTestsCount 500

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
                                               options:@{STMPersistingOptionPageSize:@(STMPersistingSpeedTestsCount)}
                                                 error:&error];
    XCTAssertNil(error);
    XCTAssertNotEqual(sourceArray.count, 0, @"There should be some sourceArray data to test");
    
    NSLog(@"testFindSpeed will do %lu find requests to '%@'",
          (unsigned long)sourceArray.count, parentEntity);
    
    __block NSTimeInterval result = 0;
    
    [self measureBlock:^{
        
        NSDate *startedAt = [NSDate date];
        
        for (NSDictionary *item in sourceArray) {
            
            if (!item[parentKey]) continue;
            
            [self.persister findSync:parentEntity
                          identifier:item[parentKey]
                             options:nil
                               error:&error];
            
            XCTAssertNil(error);
        }
        
        result += [startedAt timeIntervalSinceNow];
        
    }];
    
    NSLog(@"testFindSpeed measured %lu finds per second", @(-10.0 * sourceArray.count / result).integerValue);
}


- (void)testMergeManySpeed {

    __block NSTimeInterval totalTime = 0;
    
    [self measureMetrics:[[self class] defaultPerformanceMetrics] automaticallyStartMeasuring:NO forBlock:^{
        
        totalTime += [self measureSampleData:@{STMPersistingOptionReturnSaved:@NO}];
        
    }];
    
    NSLog(@"testMergeManySpeed merged %lu items per second", @(-10.0 * STMPersistingSpeedTestsCount / totalTime).integerValue);
    
}

- (void)testMergeManySpeedReturnSaved {
    
    __block NSTimeInterval totalTime = 0;
    
    [self measureMetrics:[[self class] defaultPerformanceMetrics] automaticallyStartMeasuring:NO forBlock:^{

        totalTime += [self measureSampleData:@{STMPersistingOptionReturnSaved:@YES}];
        
    }];
    
    NSLog(@"testMergeManySpeedReturnSaved merged %lu items per second", @(-10.0 * STMPersistingSpeedTestsCount / totalTime).integerValue);

}

- (NSTimeInterval)measureSampleData:(NSDictionary *)options {
    
    NSString *entityName = @"LogMessage";
    
    NSError *error;
    NSTimeInterval result = 0;

    options = [STMFunctions setValue:[STMFunctions stringFromNow]
                              forKey:STMPersistingOptionLts
                        inDictionary:options];
    
    NSArray *sampleData = [self sampleDataOf:entityName count:STMPersistingSpeedTestsCount];
    
    [self startMeasuring];
    
    NSDate *startedAt = [NSDate date];

    [self.persister mergeManySync:entityName attributeArray:sampleData options:options error:&error];
    
    XCTAssertNil(error);
    
    result = [startedAt timeIntervalSinceNow];
    
    [self stopMeasuring];

    return result;
    
}

- (void)testMergeSyncSpeed{
    
    NSString *entityName = @"STMLogMessage";
    int numberOfLogs = 100;
    __block NSError *error;
    
    NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    
    STMPTStartedAt
    
    [self measureBlock:^{
        
        for (int i = 0; i<numberOfLogs;i++){
            
            NSString *messageText = [@"Log message test #" stringByAppendingString:[NSString stringWithFormat:@"%d", i]];
            
            NSDictionary *logMessage = @{@"text": [NSString stringWithFormat:@"%@: %@", [STMFunctions stringFromNow], messageText],
                                         @"type": @"debug",
                                         @"ownerXid": self.ownerXid};
            
            [self.persister mergeSync:entityName attributes:logMessage options:options error:&error];
            
            XCTAssertNil(error);
            
        }
        
    }];
    
    NSLog(@"testMergeSyncSpeed merged %lu items per second", @(10.0 * numberOfLogs / STMPTSecondsAfterStartedAt).integerValue);
    
}

- (void)testFindFromLargeData{
    
    NSString *entityName = @"LogMessage";
    
    NSUInteger numberOfPages = 10;
    NSUInteger pageSize = 10000;
    
    NSUInteger totalItems = pageSize * numberOfPages;
    
    __block NSError *error;
    
    NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    
    NSString *type = @"debug";
    
    NSDate *startedAt = [NSDate date];
    
    for (NSUInteger i = 1; i<=numberOfPages; i++){
        // Async helps with memory issues
        XCTestExpectation *mergePage = [self expectationWithDescription:[NSString stringWithFormat:@"Page %lu", i]];
        [self.persister mergeManyAsync:entityName attributeArray:[self sampleDataOf:entityName count:pageSize] options:options completionHandler:^(BOOL success, NSArray<NSDictionary *> *result, NSError *error) {
            [mergePage fulfill];
            XCTAssertNil(error);
            NSLog(@"testFindFromLargeData created page %lu of %lu", i, numberOfPages);
        }];
        [self waitForExpectationsWithTimeout:10 handler:nil];
    }
    
    NSLog(@"testFindFromLargeData created %lu of %@ in %lu seconds", totalItems, entityName, @(-[startedAt timeIntervalSinceNow]).integerValue);
    
    NSPredicate *isJustMergedData = [NSPredicate predicateWithFormat:@"type == %@ AND ownerXid == %@", type, self.ownerXid];
    NSPredicate *endsWith0 = [NSPredicate predicateWithFormat:@"text ENDSWITH %@", @"00"];
    
    endsWith0 = [NSCompoundPredicate andPredicateWithSubpredicates:@[endsWith0, isJustMergedData]];
    
    [self measureBlock:^{
        
        NSArray *rez = [self.persister findAllSync:entityName predicate:endsWith0 options:nil error:&error];
        
        XCTAssertGreaterThanOrEqual(rez.count, totalItems % 100);
        
    }];
    
}



@end
