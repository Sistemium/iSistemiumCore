//
//  DefantomizingTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTests.h"

#import "STMPersisterFantoms.h"
#import "STMSyncerHelper+Defantomizing.h"


#define FantomsTestsTimeOut 15
#define GOOD_FANTOM @"good fantom"
#define BAD_FANTOM @"bad fantom"
#define BAD_FANTOM_DELETE @"bad fantom to delete"
#define FANTOM_ENTITY_NAME @"STMArticle"
#define FANTOM_OPTIONS @{STMPersistingOptionFantoms:@YES}


@interface DefantomizingTests : STMPersistingTests <STMDefantomizingOwner>

@property (nonatomic, strong) id <STMDefantomizing> defantomizingDelegate;
@property (nonatomic, strong) NSMutableDictionary <NSString *, XCTestExpectation *> *expectations;
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSDictionary *> *fantomObjects;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end


@implementation DefantomizingTests

+ (BOOL)needWaitSession {
    return YES;
}

- (void)setUp {
    
    [super setUp];
    
    self.operationQueue = [NSOperationQueue mainQueue];

    if (!self.defantomizingDelegate) {
        
        self.defantomizingDelegate = [[STMSyncerHelper alloc] init];
        self.defantomizingDelegate.defantomizingOwner = self;
        self.defantomizingDelegate.persistenceFantomsDelegate = [STMPersisterFantoms controllerWithPersistenceDelegate:self.persister];

    }
    
    XCTAssertNotNil(self.defantomizingDelegate);

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefantomize {
    
    [self fillPersisterWithFantoms];
    
    NSDate *startedAt = [NSDate date];

    [self.defantomizingDelegate startDefantomization];
    
    [self waitForExpectationsWithTimeout:FantomsTestsTimeOut handler:^(NSError * _Nullable error) {
        
        XCTAssertNil(error);
                
        NSLog(@"testSync expectation handler after %f seconds", -[startedAt timeIntervalSinceNow]);
        
    }];

}

- (void)fillPersisterWithFantoms {
    
    self.expectations = @{}.mutableCopy;
    self.fantomObjects = @{}.mutableCopy;
    
    [self createFantomWithName:GOOD_FANTOM];
    [self createFantomWithName:BAD_FANTOM];
    [self createFantomWithName:BAD_FANTOM_DELETE];
    
    XCTAssertEqual(self.expectations.count, [self fantomsCount]);
    
}

- (void)createFantomWithName:(NSString *)fantomName {
    
    NSDictionary *fantom = @{@"name" : fantomName};
    
    NSError *error = nil;
    
    fantom = [self.persister mergeSync:FANTOM_ENTITY_NAME
                            attributes:fantom
                               options:FANTOM_OPTIONS
                                 error:&error];
    
    XCTAssertNil(error);
    
    NSString *fantomId = fantom[@"id"];
    
    NSString *expectationDescription = fantomName;
    self.expectations[fantomId] = [self expectationWithDescription:expectationDescription];

    self.fantomObjects[fantomId] = fantom;
    
}

- (NSUInteger)fantomsCount {
    
    NSError *error = nil;
    
    NSArray *fantoms = [self.persister findAllSync:FANTOM_ENTITY_NAME
                                         predicate:nil
                                           options:FANTOM_OPTIONS
                                             error:&error];
    
    NSLog(@"fantoms %@", fantoms);
    
    NSUInteger count = [self.persister countSync:FANTOM_ENTITY_NAME
                                       predicate:nil
                                         options:FANTOM_OPTIONS
                                           error:&error];
    
    XCTAssertNil(error);

    return count;
    
}


#pragma mark - STMDefantomizingOwner

- (void)defantomizeEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    
    XCTestExpectation *expectation = self.expectations[identifier];
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];
    
    NSError *error = nil;

    if ([expectation.description isEqualToString:GOOD_FANTOM]) {
    
        NSMutableDictionary *attributes = self.fantomObjects[identifier].mutableCopy;
        [attributes removeObjectForKey:@"isFantom"];

        [self.operationQueue addOperationWithBlock:^{
            
            [self.defantomizingDelegate defantomizedEntityName:entityName identifier:identifier success:YES attributes:attributes error:error];
            [expectation fulfill];
            
            [self.expectations removeObjectForKey:identifier];
            
            XCTAssertEqual(self.expectations.count, [self fantomsCount]);

        }];
        
        
        
    } else if ([expectation.description isEqualToString:BAD_FANTOM_DELETE]) {
        
        error = [STMFunctions errorWithMessage:@"response got error: 404"];
        
        [self.operationQueue addOperationWithBlock:^{

            [self.defantomizingDelegate defantomizedEntityName:entityName identifier:identifier success:NO attributes:nil error:error];
            
            [expectation fulfill];
            
            [self.expectations removeObjectForKey:identifier];
            
            XCTAssertEqual(self.expectations.count, [self fantomsCount]);
            
        }];
        
    } else if ([expectation.description isEqualToString:BAD_FANTOM]) {
        
        error = [STMFunctions errorWithMessage:@"response got error"];
        
        [self.operationQueue addOperationWithBlock:^{
            [self.defantomizingDelegate defantomizedEntityName:entityName identifier:identifier success:NO attributes:nil error:error];
            
            [expectation fulfill];
            
            XCTAssertEqual(self.expectations.count, [self fantomsCount]);
        }];
        
    }
    
}

- (void)defantomizingFinished {
    
}


@end
