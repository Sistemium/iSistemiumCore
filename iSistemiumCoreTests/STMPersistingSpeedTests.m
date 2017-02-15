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
    
    NSArray *sampleData = [self sampleDataOf:entityName ownerXid:self.ownerXid count:STMPersistingSpeedTestsCount];
    
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
    
}

- (void)testFindFromLargeData{
    
    NSString *entityName = @"STMLogMessage";
    int numberOfLogs = 10000;
    __block NSError *error;
    
    NSDictionary *options = @{STMPersistingOptionReturnSaved : @NO};
    
    NSMutableArray *logMessages = @[].mutableCopy;
    
    NSString *type = @"debug";
    
    for (int i = 0; i<numberOfLogs;i++){
        
        NSString *messageText = [@"Log message test #" stringByAppendingString:[NSString stringWithFormat:@"%d", i]];
        
        NSDictionary *logMessage = @{@"text": [NSString stringWithFormat:@"%@: %@", [STMFunctions stringFromNow], messageText],
                                     @"type": type,
                                     @"ownerXid": self.ownerXid};
        
        XCTAssertNil(error);
        
        [logMessages addObject:logMessage];
        
    }
    
    [self.persister mergeManySync:entityName attributeArray:logMessages options:options error:&error];
    
    XCTAssertNil(error);
    
    NSPredicate *isJustMergedData = [NSPredicate predicateWithFormat:@"type == %@ AND ownerXid == %@", type, self.ownerXid];
    NSPredicate *endsWith0 = [NSPredicate predicateWithFormat:@"text ENDSWITH %@", @"0"];
    
    endsWith0 = [NSCompoundPredicate andPredicateWithSubpredicates:@[endsWith0, isJustMergedData]];
    
    [self measureBlock:^{
        
        NSArray *rez = [self.persister findAllSync:entityName predicate:isJustMergedData options:nil error:&error];
        
        XCTAssertEqual(rez.count, numberOfLogs);
        
        rez = [self.persister findAllSync:entityName predicate:endsWith0 options:nil error:&error];
        
        XCTAssertGreaterThanOrEqual(rez.count, numberOfLogs % 10);
        
    }];
    
}



@end
