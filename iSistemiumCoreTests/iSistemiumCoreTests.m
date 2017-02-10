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
#import "STMFunctions.h"


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
        self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:[STMModeller modellerWithModel:model]];
    }
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSQLFiltersSubqueries {

    NSPredicate *predicate;
    
    predicate = [NSPredicate predicateWithFormat:@"outlet.partnerId == %@", @"xid"];
    
    STMAssertSQLFilter(predicate, @"(exists ( select * from Outlet where [partnerId] = 'xid' and id = outletId ))");
    
    predicate = [NSPredicate predicateWithFormat:@"ANY outlets.partner.id == %@", @"xid"];
    
    STMAssertSQLFilter(predicate, @"(exists ( select * from Outlet where partnerId = 'xid' and ?uncapitalizedTableName?Id = ?capitalizedTableName?.id ))");
    

}

- (void)testSQLFilters {
    
    NSPredicate *predicate;
    
    predicate = [NSPredicate predicateWithFormat:@"date == %@", @"2017-01-01"];
    
    STMAssertSQLFilter(predicate, @"([date] = '2017-01-01')");
    
    predicate = [NSPredicate predicateWithFormat:@"avatarPictureId == %@", nil];
    
    STMAssertSQLFilter(predicate, @"([avatarPictureId] IS NULL)");
    
    predicate = [NSPredicate predicateWithFormat:@"avatarPictureId != %@", nil];
    
    STMAssertSQLFilter(predicate, @"([avatarPictureId] IS NOT NULL)");
    
    NSSet *set = [NSSet setWithObjects:@"error", @"important", nil];
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", set];
    
    STMAssertSQLFilter(predicate, @"([type] IN ('error','important'))");
    
    NSArray *array = set.allObjects;
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", array];
    
    STMAssertSQLFilter(predicate, @"([type] IN ('error','important'))");

    predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", @[@{@"id":@"xid"}, @{@"id":@"xid"}]];
    
    STMAssertSQLFilter(predicate, @"NOT (id IN ('xid','xid'))");
    
    predicate = [NSPredicate predicateWithFormat:@"type IN %@", nil];
    
    STMAssertSQLFilter(predicate, @"([type] IN (NULL))");
    
    predicate = [NSPredicate predicateWithFormat:@"SELF.deviceTs > SELF.lts"];
    
    STMAssertSQLFilter(predicate, @"([deviceTs] > lts)");
    
    predicate = [NSPredicate predicateWithFormat:@"deviceTs > lts"];
    
    STMAssertSQLFilter(predicate, @"([deviceTs] > lts)");

    predicate = [NSCompoundPredicate notPredicateWithSubpredicate:predicate];
    
    STMAssertSQLFilter(predicate, @"NOT ([deviceTs] > lts)");
    
    NSUUID *uuid = [NSUUID UUID];
    NSData *uuidData = [STMFunctions UUIDDataFromNSUUID:uuid];
    NSString *uuidString = uuid.UUIDString.lowercaseString;

    predicate = [NSPredicate predicateWithFormat:@"xid == %@", uuidData];
    
    NSString *string = [NSString stringWithFormat:@"([id] = '%@')", uuid.UUIDString.lowercaseString];
    STMAssertSQLFilter(predicate, string);

    predicate = [NSPredicate predicateWithFormat:@"xid IN %@", @[uuidData, uuidData]];
    
    string = [NSString stringWithFormat:@"([id] IN ('%@','%@'))", uuidString, uuidString];
    STMAssertSQLFilter(predicate, string);

    predicate = [NSPredicate predicateWithFormat: @"name ENDSWITH %@", uuidString];
    string = [NSString stringWithFormat:@"([name] LIKE '%%%@')", uuidString];
    
    STMAssertSQLFilter(predicate, string);
    
    predicate = [NSPredicate predicateWithFormat: @"name BEGINSWITH %@", uuidString];
    string = [NSString stringWithFormat:@"([name] LIKE '%@%%')", uuidString];
    
    STMAssertSQLFilter(predicate, string);
    
    predicate = [NSPredicate predicateWithFormat: @"name LIKE %@", uuidString];
    string = [NSString stringWithFormat:@"([name] LIKE '%%%@%%')", uuidString];
    
    STMAssertSQLFilter(predicate, string);

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
    
    NSEntityDescription *partner = [self entityWithName:@"STMPartner"
                                            properties:partnerProperties];
    
    NSArray *outletProperties = @[
        [self attributeWithName:@"name"
                          type:NSStringAttributeType],
        [self attributeWithName:@"ts"
                          type:NSDateAttributeType],
        [self attributeWithName:@"size"
                          type:NSInteger32AttributeType]
    ];
    
    NSEntityDescription *outlet = [self entityWithName:@"STMOutlet"
                                            properties:outletProperties];
    
    NSRelationshipDescription *outletPartner = [[NSRelationshipDescription alloc] init];
    
    outletPartner.name = @"partner";
    outletPartner.maxCount = 1;
    outletPartner.destinationEntity = partner;
    
    NSRelationshipDescription *partnerOutlets = [[NSRelationshipDescription alloc] init];
    
    partnerOutlets.name = @"outlets";
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
