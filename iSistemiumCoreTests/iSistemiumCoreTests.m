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
    
    NSArray *partnerProperties = @[
        [self attributeWithName:@"name"
                           type:NSStringAttributeType],
        [self attributeWithName:@"ts"
                           type:NSDateAttributeType],
        [self attributeWithName:@"size"
                           type:NSInteger32AttributeType]
    ];
    
    NSEntityDescription *partner = [self entityWithName:@"Partner"
                                            properties:partnerProperties];
    
    NSArray *outletProperties = @[
        [self attributeWithName:@"name"
                          type:NSStringAttributeType],
        [self attributeWithName:@"ts"
                          type:NSDateAttributeType],
        [self attributeWithName:@"size"
                          type:NSInteger32AttributeType]
    ];
    
    NSEntityDescription *outlet = [self entityWithName:@"Outlet"
                                            properties:outletProperties];
    
    NSRelationshipDescription *outletPartner = [[NSRelationshipDescription alloc] init];
    
    outletPartner.name = @"partner";
    outletPartner.maxCount = 1;
    outletPartner.destinationEntity = partner;
    
    NSRelationshipDescription *partnerOutlets = [[NSRelationshipDescription alloc] init];
    
    partnerOutlets.name = @"Outlets";
    partnerOutlets.destinationEntity = outlet;
    partnerOutlets.inverseRelationship = outletPartner;
    
    outletPartner.inverseRelationship = partnerOutlets;
    
    outlet.properties = [outlet.properties arrayByAddingObject:outletPartner];
    partner.properties = [partner.properties arrayByAddingObject:partnerOutlets];
    
    [model setEntities:@[outlet, partner]];
    
    return model;
}

- (NSAttributeDescription *)attributeWithName:(NSString *)name type:(NSAttributeType)type {
    NSAttributeDescription *attribute = [[NSAttributeDescription alloc] init];
    attribute.name = name;
    attribute.attributeType = type;
    return attribute;
}

- (NSEntityDescription *)entityWithName:(NSString *)name properties:(NSArray *)properties {
    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = name;
    entity.properties = properties;
    return entity;
}


@end
