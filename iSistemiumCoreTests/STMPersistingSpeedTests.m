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
    
    NSLog(@"testFindSpeed measured %lu finds per seconds", @(-10.0 * sourceArray.count / [startedAt timeIntervalSinceNow]).integerValue);
}


- (void)testMergeManySpeed {

    __block NSTimeInterval totalTime = 0;
    
    [self measureMetrics:[[self class] defaultPerformanceMetrics] automaticallyStartMeasuring:NO forBlock:^{
        
        totalTime += [self measureSampleData:@{}];
        
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
    
    NSString *ownerXid = [STMFunctions uuidString];
    
    NSPredicate *cleanupPredicate = [NSPredicate predicateWithFormat:@"ownerXid == %@", ownerXid];
    NSDictionary *cleanupOptions = @{STMPersistingOptionRecordstatuses:@NO};
    
    NSError *error;
    NSTimeInterval result = 0;

    options = [STMFunctions setValue:[STMFunctions stringFromNow]
                              forKey:STMPersistingOptionLts
                        inDictionary:options];
    
    NSArray *sampleData = [self sampleDataOf:entityName ownerXid:ownerXid count:STMPersistingSpeedTestsCount];
    
    [self startMeasuring];
    
    NSDate *startedAt = [NSDate date];

    [self.persister mergeManySync:entityName attributeArray:sampleData options:options error:&error];
    
    XCTAssertNil(error);
    
    result = [startedAt timeIntervalSinceNow];
    
    [self stopMeasuring];
    
    [self.persister destroyAllSync:entityName predicate:cleanupPredicate options:cleanupOptions error:&error];
    
    XCTAssertNil(error);
    
    return result;
    
}

@end
