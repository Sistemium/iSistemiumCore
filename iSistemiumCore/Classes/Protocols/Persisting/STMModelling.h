//
//  STMModelling.h
//  iSisSales
//
//  Created by Alexander Levin on 23/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

typedef NS_ENUM(NSInteger, STMStorageType) {
    STMStorageTypeFMDB,
    STMStorageTypeCoreData
};

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@protocol STMModelling

@required

- (NSManagedObject *)newObjectForEntityName:(NSString *)entityName;

- (STMStorageType)storageForEntityName:(NSString *)entityName;

- (NSDictionary <NSString *, NSEntityDescription *> *)entitiesByName;

- (NSDictionary *)fieldsForEntityName:(NSString *)entityName;

- (NSDictionary *)toOneRelationshipsForEntityName:(NSString *)entityName;

- (NSDictionary *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany cascade:(NSNumber *)cascade;

- (NSDictionary *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany;

@end
