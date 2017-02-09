//
//  STMModellerTests.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 09/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//


#import "STMPersistingTests.h"

@interface STMModellerTests : STMPersistingTests

@end

@implementation STMModellerTests

- (void)testEntitiesHierarchy {
    
    NSArray<NSString*>* expectedPictrureNames = @[@"STMArticlePicture",@"STMOutletPhoto",@"STMVisitPhoto",@"STMMessagePicture"];
    NSSet *expectedPictrureNamesSet=[NSSet setWithArray:expectedPictrureNames];
    NSSet *resultSet= [self.persister hierarchyForEntityName:@"STMCorePicture"];
    XCTAssertEqualObjects(expectedPictrureNamesSet, resultSet);
    
    expectedPictrureNames = @[@"STMOutletPhoto",@"STMVisitPhoto"];
    expectedPictrureNamesSet=[NSSet setWithArray:expectedPictrureNames];
    resultSet= [self.persister hierarchyForEntityName:@"STMCorePhoto"];
    XCTAssertEqualObjects(expectedPictrureNamesSet, resultSet);
    
    
}

@end
