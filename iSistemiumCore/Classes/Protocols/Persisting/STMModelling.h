//
//  STMModelling.h
//  iSisSales
//
//  Created by Alexander Levin on 23/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisting.h"
#import <Foundation/Foundation.h>
#import "STMDatum.h"

@protocol STMModelling

@required

- (STMStorageType)storageForEntityName:(NSString *)entityName;

- (BOOL)isConcreteEntityName:(NSString *)entityName;

- (NSDictionary <NSString *, NSEntityDescription *> *)entitiesByName;

- (NSDictionary *)fieldsForEntityName:(NSString *)entityName;

- (NSDictionary <NSString *,NSRelationshipDescription *> *)objectRelationshipsForEntityName:(NSString *)entityName
                                                                                   isToMany:(NSNumber *)isToMany
                                                                                    cascade:(NSNumber *)cascade;

- (NSDictionary <NSString *,NSRelationshipDescription *> *)objectRelationshipsForEntityName:(NSString *)entityName
                                                                                   isToMany:(NSNumber *)isToMany
                                                                                    cascade:(NSNumber *)cascade
                                                                                   optional:(NSNumber *)optional;

- (NSDictionary <NSString *,NSString *> *)toOneRelationshipsForEntityName:(NSString *)entityName;

- (NSDictionary <NSString *,NSString *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany;

@optional

// TODO: Declare a separate protocol for using NSManagedObject

- (NSManagedObject *)newObjectForEntityName:(NSString *)entityName;

- (NSManagedObject *)findOrCreateManagedObjectOf:(NSString *)entityName
                                      identifier:(NSString *)identifier;

- (NSDictionary *)dictionaryFromManagedObject:(NSManagedObject *)object;

- (void)setObjectData:(NSDictionary *)objectData toObject:(NSManagedObject *)object withRelations:(BOOL)withRelations;
- (void)setObjectData:(NSDictionary *)objectData toObject:(NSManagedObject *)object;

@end
