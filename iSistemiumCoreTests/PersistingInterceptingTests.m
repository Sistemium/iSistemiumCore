//
//  PersistingInterceptingTests.m
//  iSisSales
//
//  Created by Alexander Levin on 17/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"
#import "STMPersistingIntercepting.h"
#import "STMClientEntityController.h"
#import "STMEntityController.h"

@interface PersistingInterceptingTests : STMPersistingTests <STMPersistingMergeInterceptor>

@end

@implementation PersistingInterceptingTests

+ (BOOL)needWaitSession {
    return YES;
}

- (void)setUp {
    [super setUp];
    XCTAssertNotNil(self.persister);
    XCTAssertNotNil(self.realPersiser);
}

- (void)testEntityControllerInterceptor {
    
    NSString *entityName = @"STMEntity";
    NSString *name = @"EntityControllerInterceptor";
    NSError *error;
    
    id keepEntityInterceptor = self.realPersiser.beforeMergeInterceptors.dictionaryRepresentation[entityName];
    
    STMEntityController *interceptor = [STMEntityController controllerWithPersistenceDelegate:self.persister];
    
    [self.fakePersiser beforeMergeEntityName:entityName interceptor:interceptor];
    [self.realPersiser beforeMergeEntityName:entityName interceptor:interceptor];
    
    NSMutableDictionary *testData = [[self sampleDataOf:entityName count:1][0] mutableCopy];
    
    NSString *xid = [STMFunctions uuidString];
    testData[@"name"] = name;
    testData[STMPersistingKeyPrimary] = xid;
    
    NSString *pk1 = [self.persister mergeSync:entityName attributes:testData options:nil error:&error][STMPersistingKeyPrimary];
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(pk1, xid);
    
    NSString *pk2 = [self.persister mergeSync:entityName attributes:testData options:nil error:&error][STMPersistingKeyPrimary];
    XCTAssertNil(error);
    XCTAssertEqualObjects(pk2, xid);
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    
    NSUInteger count = [self.persister countSync:entityName predicate:predicate options:nil error:&error];
    
    XCTAssertEqual(count, 1);
    
    XCTAssertTrue([self.persister destroySync:entityName identifier:pk1 options:self.cleanupOptions error:&error]);
    XCTAssertFalse([self.persister destroySync:entityName identifier:pk2 options:self.cleanupOptions error:&error]);
    
    [self.fakePersiser beforeMergeEntityName:entityName interceptor:nil];
    [self.realPersiser beforeMergeEntityName:entityName interceptor:keepEntityInterceptor];

}

- (void)testForceSingleItem {
    
    NSString *entityName = @"STMLogMessage";
    NSError *error;
    
    [self.fakePersiser beforeMergeEntityName:entityName interceptor:self];
    [self.realPersiser beforeMergeEntityName:entityName interceptor:self];
   
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
    
    [self.fakePersiser beforeMergeEntityName:entityName interceptor:nil];
    [self.realPersiser beforeMergeEntityName:entityName interceptor:nil];
    
}

- (NSDictionary *)interceptedAttributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    return [STMFunctions setValue:self.ownerXid forKey:STMPersistingKeyPrimary inDictionary:attributes];
    
}

@end
