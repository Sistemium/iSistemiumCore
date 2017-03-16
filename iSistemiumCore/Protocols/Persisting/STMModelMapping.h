//
//  STMModelMapping.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreData/CoreData.h>
#import "STMFiling.h"


@protocol STMModelMapping <NSObject>

@property (nonatomic, strong, readonly) NSManagedObjectModel *sourceModel;
@property (nonatomic, strong, readonly) NSManagedObjectModel *destinationModel;
@property (nonatomic, strong, readonly) NSMappingModel *mappingModel;
@property (nonatomic, strong, readonly) NSMigrationManager *migrationManager;

@property (nonatomic, strong, readonly) NSArray <NSEntityDescription *> *addedEntities;
@property (nonatomic, strong, readonly) NSArray <NSEntityDescription *> *removedEntities;

@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *addedProperties;
@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *addedAttributes;
@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *addedRelationships;

@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *removedProperties;
@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *removedAttributes;
@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *removedRelationships;

@property (nonatomic, readonly) BOOL needToMigrate;

@end