//
//  STMModelling.h
//  iSisSales
//
//  Created by Alexander Levin on 23/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

typedef NS_ENUM(NSInteger, STMStorageType) {
    STMStorageTypeFMDB,
    STMStorageTypeCoreData,
    STMStorageTypeAbstract,
    STMStorageTypeNone
};

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@protocol STMModelling

@required

- (NSManagedObject *)newObjectForEntityName:(NSString *)entityName;

- (STMStorageType)storageForEntityName:(NSString *)entityName;

- (BOOL)isConcreteEntityName:(NSString *)entityName;

- (NSDictionary <NSString *, NSEntityDescription *> *)entitiesByName;

- (NSDictionary *)fieldsForEntityName:(NSString *)entityName;

- (NSDictionary <NSString *,NSRelationshipDescription *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany cascade:(NSNumber *)cascade;

- (NSDictionary <NSString *,NSString *> *)toOneRelationshipsForEntityName:(NSString *)entityName;

- (NSDictionary <NSString *,NSString *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany;

@end
