//
//  STMModellerTests.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 09/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//


#import "STMPersistingTests.h"
#import "STMModeller.h"

@interface STMModellerTests : STMPersistingTests

@end

@implementation STMModellerTests

+ (BOOL)needWaitSession {
    return YES;
}

- (void)testEntitiesHierarchy {
    
    NSArray<NSString*>* expectedPictrureNames = @[
                                                  @"STMArticlePicture",
                                                  @"STMOutletPhoto",
                                                  @"STMVisitPhoto",
                                                  @"STMMessagePicture",
                                                  @"STMUncashingPicture",
                                                  @"STMCampaignPicture"
                                                  ];
    NSSet *expectedPictrureNamesSet=[NSSet setWithArray:expectedPictrureNames];
    NSSet *resultSet= [self.persister hierarchyForEntityName:@"STMCorePicture"];
    XCTAssertEqualObjects(expectedPictrureNamesSet, resultSet);
    
    expectedPictrureNames = @[@"STMOutletPhoto",@"STMVisitPhoto", @"STMUncashingPicture"];
    expectedPictrureNamesSet=[NSSet setWithArray:expectedPictrureNames];
    resultSet= [self.persister hierarchyForEntityName:@"STMCorePhoto"];
    XCTAssertEqualObjects(expectedPictrureNamesSet, resultSet);
    
}

- (void)testEntitiesList {

    NSMutableSet *fromPersister = [NSSet setWithArray:self.persister.concreteEntities.allKeys].mutableCopy;
    
    NSArray *coreEntities = [self localDataModelEntityNames];
    
    [fromPersister minusSet:[NSSet setWithArray:coreEntities]];
    
    XCTAssertEqual(fromPersister.count, 0);
    
    if (fromPersister.count) {
        NSLog(@"fromPersister: %@", fromPersister);
    }
    

}


- (NSArray *)localDataModelEntityNames {
    
    NSArray *entities = [(STMModeller *)self.persister managedObjectModel].entitiesByName.allValues;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"abstract == NO"];
    
    return [[entities filteredArrayUsingPredicate:predicate] valueForKeyPath:@"name"];
    
}

@end
