//
//  PersistingInterceptingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMPersistingIntercepting.h"

@interface PersistingInterceptingTests : STMPersistingTests <STMPersistingMergeInterceptor>

@end

@implementation PersistingInterceptingTests

+ (BOOL)needWaitSession {
    return YES;
}

- (void)testForceSingleItem {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    [self.fakePersiser beforeMergeEntityName:entityName interceptor:self];
    [self.realPersiser beforeMergeEntityName:entityName interceptor:self];
    
    XCTAssertNotNil(self.persister);
    XCTAssertNotNil(self.realPersiser);
   
    NSDictionary *testData = [self sampleDataOf:entityName count:1][0];
    
    NSDictionary *result = [self.persister mergeSync:entityName attributes:testData options:nil error:&error];
    
    // Interceptor should set the primary key to our ownerXid
    
    XCTAssertEqualObjects(result[STMPersistingKeyPrimary], self.ownerXid);
    
    result = [self.persister mergeSync:entityName attributes:testData options:nil error:&error];
    XCTAssertNil(error);
    
    // Interceptor should set the primary key to our ownerXid again
    
    XCTAssertEqualObjects(result[STMPersistingKeyPrimary], self.ownerXid);
    XCTAssertNil(error);
    
    NSUInteger count = [self.persister countSync:entityName predicate:self.cleanupPredicate options:nil error:&error];
    
    // Interceptor have had provided uniqueness of the data
    
    XCTAssertEqual(count, 1);
    
}

- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    return [STMFunctions setValue:self.ownerXid forKey:STMPersistingKeyPrimary inDictionary:attributes];
    
}

@end
