//
//  STMModeller.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 25/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller.h"
#import "STMFunctions.h"
#import "STMConstants.h"
#import "STMDatum.h"
#import "STMCoreObjectsController.h"

#import "STMModeller+Private.h"

#import "STMSessionManager.h"

@interface STMModeller()

@property (nonatomic, strong) NSMutableDictionary *allEntitiesCache;

@end

@implementation STMModeller

+ (instancetype)modellerWithModel:(NSManagedObjectModel *)model {
    return [[STMModeller alloc] initWithModel:model];
}


+ (NSManagedObjectModel *)modelWithName:(NSString *)modelName {
    NSString *path = [[NSBundle mainBundle] pathForResource:modelName ofType:@"momd"];
    
    if (!path) path = [[NSBundle mainBundle] pathForResource:modelName ofType:@"mom"];
    
    if (path) {
        
        NSURL *url = [NSURL fileURLWithPath:path];
        
        return [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        
    }
        
    NSLog(@"there is no path for data model with name %@", modelName);
    return nil;
}

- (instancetype)initWithModelName:(NSString *)modelName {
    return [self initWithModel:[self.class modelWithName:modelName]];
}

- (instancetype)initWithModel:(NSManagedObjectModel *)model{
    
    self = [super init];
    
    self.managedObjectModel = model;
    NSMutableDictionary *cache = @{}.mutableCopy;
    
    for (NSString *entityKey in self.entitiesByName) {
        NSEntityDescription *entity = self.entitiesByName[entityKey];
        cache[entityKey] = @{@"fields": entity.attributesByName,
                             @"relationships": entity.relationshipsByName};
    }
    
    self.allEntitiesCache = cache.copy;
    return self;
}

#pragma mark - STMModelling

- (NSManagedObject *)newObjectForEntityName:(NSString *)entityName {
#warning need to check if entity is stored in CoreData and use document's context
    return [[NSManagedObject alloc] initWithEntity:self.entitiesByName[entityName]
                    insertIntoManagedObjectContext:nil];
}


- (STMStorageType)storageForEntityName:(NSString *)entityName {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];
    
    NSEntityDescription *entity = self.entitiesByName[entityName];
    
    if (!entity) return STMStorageTypeNone;
    
    NSString *storeOption = entity.userInfo[@"STORE"];
    
    if (entity.abstract) return STMStorageTypeAbstract;
    
    if (!storeOption || [storeOption isEqualToString:@"FMDB"]){
        return STMStorageTypeFMDB;
    }
    
    if ([storeOption isEqualToString:@"CoreData"]) {
        return STMStorageTypeCoreData;
    }
    
    return STMStorageTypeNone;
    
}

- (BOOL)isConcreteEntityName:(NSString *)entityName {
    
    STMStorageType type = [self storageForEntityName:entityName];
    
    return !(type == STMStorageTypeNone || type == STMStorageTypeAbstract);
    
}

- (NSDictionary <NSString *, NSEntityDescription *> *)entitiesByName {
    return self.managedObjectModel.entitiesByName;
}

- (NSDictionary *)fieldsForEntityName:(NSString *)entityName {
    return self.allEntitiesCache[entityName][@"fields"];
}

- (NSDictionary <NSString *,NSRelationshipDescription *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany cascade:(NSNumber *)cascade{
    
    if (!entityName) {
        return nil;
    }
    
    NSDictionary *allRelationships = self.allEntitiesCache[entityName][@"relationships"];
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    for (NSString *relationshipName in allRelationships) {
        
        NSRelationshipDescription *relationship = allRelationships[relationshipName];
        
        if (!isToMany || relationship.isToMany == isToMany.boolValue) {
            
            if (!cascade || ([cascade boolValue] && relationship.deleteRule == NSCascadeDeleteRule) || (![cascade boolValue] && relationship.deleteRule != NSCascadeDeleteRule)){
                result[relationshipName] = relationship;
            }
            
        }
        
    }
    
    return result;
    
}

- (NSDictionary <NSString *,NSString *> *)toOneRelationshipsForEntityName:(NSString *)entityName{
    
    return [self objectRelationshipsForEntityName:entityName isToMany:@NO];
}

- (NSDictionary <NSString *,NSString *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany{
    
    NSDictionary *relationships = [self objectRelationshipsForEntityName:entityName isToMany:isToMany cascade:nil];
    
    return [STMFunctions mapDictionary:relationships withBlock:^id _Nonnull(NSRelationshipDescription *value, NSString *key) {
        return value.destinationEntity.name;
    }];
    
}

- (void)setObjectData:(NSDictionary *)objectData toObject:(STMDatum *)object withRelations:(BOOL)withRelations{
    
    NSEntityDescription *entity = object.entity;
    NSString *entityName = entity.name;
    
    NSArray *ownObjectKeys = [self fieldsForEntityName:entityName].allKeys;
    NSDictionary *ownObjectRelationships = [self toOneRelationshipsForEntityName:entityName];
    
    for (NSString *key in objectData.allKeys) {
        
        id value = objectData[key];
        
        if ([key isEqualToString:@"id"] && value) {
            if ([(NSString*)value length] == 36) {
                [object setValue:[STMFunctions xidDataFromXidString:value] forKey:@"xid"];
            }
        } else if ([ownObjectKeys containsObject:key]) {
            
            NSDictionary *entityAttributes = entity.attributesByName;
            
            value = (![value isKindOfClass:[NSNull class]]) ? [STMModeller typeConversionForValue:value key:key entityAttributes:entityAttributes] : nil;
            
            [object setValue:value forKey:key];
            
        } else {
            
            if ([key hasSuffix:RELATIONSHIP_SUFFIX] && withRelations) {
                
                NSUInteger toIndex = key.length - RELATIONSHIP_SUFFIX.length;
                NSString *localKey = [key substringToIndex:toIndex];
                
                NSString* destinationEntityName = [ownObjectRelationships objectForKey:localKey];
                
                NSString *destinationObjectXid = [value isKindOfClass:[NSNull class]] ? nil : value;
                
                if (destinationEntityName && destinationObjectXid) {
                    
                    STMDatum *destinationObject = (STMDatum*) [self newObjectForEntityName:destinationEntityName];
                    
                    NSDictionary *destinationObjectData = [STMSessionManager.sharedManager.currentSession.persistenceDelegate findSync:destinationEntityName identifier:destinationObjectXid options:nil error:nil];
                    
                    [self setObjectData:destinationObjectData toObject:destinationObject withRelations:false];
                    
                    [object setValue:destinationObject forKey:localKey];
                    
                }
                
            }
            
        }
        
    }
    
}


@end
