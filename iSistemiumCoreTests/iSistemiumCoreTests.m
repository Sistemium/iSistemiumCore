//
//  iSistemiumCoreTests.m
//  iSistemiumCoreTests
//
//  Created by Maxim Grigoriev on 11/04/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>
#import "STMPredicateToSQL.h"
#import "STMModeller.h"

#define STMAssertSQLFilter(predicate, expectation, ...) \
XCTAssertEqualObjects([self.predicateToSQL SQLFilterForPredicate:predicate], expectation, __VA_ARGS__)

@interface iSistemiumCoreTests : XCTestCase

@property (nonatomic,strong) STMPredicateToSQL *predicateToSQL;

@end

@implementation iSistemiumCoreTests

- (void)setUp {
    [super setUp];
    if (!self.predicateToSQL) {
        NSManagedObjectModel *model = [self sampleModel];
        self.predicateToSQL = [[STMPredicateToSQL alloc] init];
        self.predicateToSQL.modellingDelegate = [[STMModeller alloc] initWithModel:model];
    }
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSQLFilters {
    
    NSPredicate *predicate;
    
    predicate = [NSPredicate predicateWithFormat:@"date == %@", @"2017-01-01"];
    
    STMAssertSQLFilter(predicate, @"(date = '2017-01-01')");
    
    predicate = [NSPredicate predicateWithFormat:@"avatarPictureId == %@", nil];
    
    STMAssertSQLFilter(predicate, @"(avatarPictureId IS NULL)");
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", @[@"error", @"important"]];
    
    STMAssertSQLFilter(predicate, @"(type IN ('error','important'))");
    
    predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", @[@{@"id":@"xid"}, @{@"id":@"xid"}]];
    
    STMAssertSQLFilter(predicate, @"NOT (id IN ('xid','xid'))");
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", nil];
    
    STMAssertSQLFilter(predicate, @"(type IN (NULL))");
    
    predicate = [NSPredicate predicateWithFormat:@"SELF.deviceTs > SELF.lts"];
    
    STMAssertSQLFilter(predicate, @"(deviceTs > lts)");
    
    predicate = [NSPredicate predicateWithFormat:@"deviceTs > lts"];
    
    STMAssertSQLFilter(predicate, @"(deviceTs > lts)");

    predicate = [NSCompoundPredicate notPredicateWithSubpredicate:predicate];
    
    STMAssertSQLFilter(predicate, @"NOT (deviceTs > lts)");

    
}

- (NSManagedObjectModel *) sampleModel {
    
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
    
    // create the entity
    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    [entity setName:@"Outlet"];
//    [entity setManagedObjectClassName:@"STMOutlet"];
    
    // create the attributes
    NSMutableArray *properties = [NSMutableArray array];
    
    NSAttributeDescription *nameAttribute = [[NSAttributeDescription alloc] init];
    
    nameAttribute.name = @"name";
    nameAttribute.attributeType = NSStringAttributeType;
    
    [properties addObject:nameAttribute];
    
    
    NSAttributeDescription *tsAttribute = [[NSAttributeDescription alloc] init];
    
    tsAttribute.name = @"ts";
    tsAttribute.attributeType = NSDateAttributeType;
    
    [properties addObject:tsAttribute];
    
    NSAttributeDescription *sizeAttribute = [[NSAttributeDescription alloc] init];
    sizeAttribute.name = @"size";
    sizeAttribute.attributeType = NSInteger32AttributeType;
    [properties addObject:sizeAttribute];
    
    // add attributes to entity
    [entity setProperties:properties];
    
    // add entity to model
    [model setEntities:[NSArray arrayWithObject:entity]];
    
    return model;
}


@end
