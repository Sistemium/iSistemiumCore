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
@property (nonatomic, strong) XCTestExpectation *fantomExpectation;


@end


@implementation DefantomizingTests

- (void)setUp {
    
    [super setUp];

    [self inMemoryPersisting];

    if (!self.defantomizingDelegate) {
        
        self.defantomizingDelegate = [[STMSyncerHelper alloc] init];
        self.defantomizingDelegate.defantomizingOwner = self;
        self.defantomizingDelegate.persistenceFantomsDelegate = [STMPersisterFantoms persisterFantomsWithPersistenceDelegate:self.persister];

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
    
    NSDictionary *fantomOptions = @{STMPersistingOptionFantoms:@YES};
    
    NSDictionary *fantom = @{@"name" : @"fantomArticle"};
    
    NSError *error = nil;
    
    fantom = [self.persister mergeSync:FANTOM_ENTITY_NAME
                            attributes:fantom
                               options:FANTOM_OPTIONS
                                 error:&error];
    
    XCTAssertNil(error);
    
    NSLog(@"fantom %@", fantom);
    
    NSString *expectationDescription = [NSString stringWithFormat:@"wait for fantom"];
    self.fantomExpectation = [self expectationWithDescription:expectationDescription];

}


#pragma mark - STMDefantomizingOwner

- (void)defantomizeObject:(NSDictionary *)fantomDic {
    
    [self.fantomExpectation fulfill];
    
}

- (void)defantomizingFinished {
    
}


@end
