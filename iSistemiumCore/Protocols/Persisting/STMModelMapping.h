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

@property (readonly) NSManagedObjectModel *sourceModel;
@property (readonly) NSManagedObjectModel *destinationModel;

@property (readonly) NSArray <NSEntityDescription *> *addedEntities;
@property (readonly) NSArray <NSEntityDescription *> *removedEntities;

@property (readonly) NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *addedProperties;
@property (readonly) NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *addedAttributes;
@property (readonly) NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *addedRelationships;

@property (readonly) NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *removedProperties;
@property (readonly) NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *removedAttributes;
@property (readonly) NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *removedRelationships;

@property (readonly) BOOL needToMigrate;

@end
