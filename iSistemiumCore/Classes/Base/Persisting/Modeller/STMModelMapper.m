//
//  STMModelMapper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModelMapper.h"

#import "STMModeller.h"
#import "STMFunctions.h"


@interface STMModelMapper()

@property (nonatomic, strong) NSManagedObjectModel *sourceModel;
@property (nonatomic, strong) NSManagedObjectModel *destinationModel;

@property (nonatomic, strong) NSMappingModel *mappingModel;
@property (nonatomic, strong) NSMigrationManager *migrationManager;

@property (nonatomic) BOOL needToMigrate;

@end


@implementation STMModelMapper

- (instancetype)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel error:(NSError **)error {
    
    self = [self init];
    
    if (!self) {
        return nil;
    }
    
    if (!sourceModel) sourceModel = [[NSManagedObjectModel alloc] init];
    if (!destinationModel) destinationModel = [[NSManagedObjectModel alloc] init];
    
    self.sourceModel = sourceModel;
    self.destinationModel = destinationModel;
    self.needToMigrate = ![self.sourceModel isEqual:self.destinationModel];
    
    if (self.needToMigrate) {
        NSLog(@"ModelMapper need to migrate");
    }
    
    while (true) {
        self.mappingModel = [NSMappingModel inferredMappingModelForSourceModel:sourceModel
                                                              destinationModel:destinationModel
                                                                         error:error];
        
        if (*error) {
            
            // This is a workaround for migrating json fields to Transformable
            
            NSDictionary *errorUserInfo = (*error).userInfo;
            NSLog(@"NSMappingModel error: %@: %@", [*error localizedDescription], errorUserInfo[@"reason"]);
            
            if ([STMFunctions isNotNull:errorUserInfo[@"reason"]] && [errorUserInfo[@"reason"] isEqualToString:@"Source and destination attribute types are incompatible"]){
                
                NSString *entityName = errorUserInfo[@"entity"];
                NSString *propertyName = errorUserInfo[@"property"];
                
                NSMutableDictionary *sourceEntities = sourceModel.entitiesByName.mutableCopy;
                NSEntityDescription *sourceEntity = sourceEntities[entityName];
                NSMutableDictionary *sourceEntityProperties = sourceEntity.propertiesByName.mutableCopy;
                
                NSEntityDescription *destinationEntity = destinationModel.entitiesByName[entityName];
                NSAttributeDescription *destinationProperty = destinationEntity.attributesByName[propertyName];
                
                sourceEntityProperties[propertyName] = destinationProperty.copy;
                sourceEntity.properties = sourceEntityProperties.allValues;
                
                sourceEntities[errorUserInfo[@"entity"]] = sourceEntity;
                sourceModel.entities = sourceEntities.allValues;
                
                *error = nil;
                
                self.needToMigrate = YES;
                
                continue;
            }
        }
        break;
    }
    
    self.migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel
                                                           destinationModel:destinationModel];
    
#ifdef DEBUG
    [self showMappingInfo];
#endif
    
    return self;

}


#pragma mark - STMModelMapping

- (NSArray <NSEntityDescription *> *)addedEntities {
    return [self mappingEntitiesDescriptionsWithType:NSAddEntityMappingType];
}

- (NSArray <NSEntityDescription *> *)removedEntities {
    return [self mappingEntitiesDescriptionsWithType:NSRemoveEntityMappingType];
}

- (NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *)addedProperties {
    
    NSMutableDictionary <NSString *, NSArray <NSPropertyDescription *> *> *addedProperties = @{}.mutableCopy;
    
    NSArray <NSEntityMapping *> *transformedEntities = [self mappingEntitiesWithType:NSTransformEntityMappingType];
    
    for (NSEntityMapping *entityMapping in transformedEntities) {
        
        NSSet *propertiesSet = entityMapping.userInfo[@"addedProperties"];

        if (propertiesSet.count) {
        
            NSEntityDescription *entity = [self.migrationManager destinationEntityForEntityMapping:entityMapping];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", propertiesSet];
            NSArray *result = [entity.properties filteredArrayUsingPredicate:predicate];
            
            if (result) addedProperties[entity.name] = result;
            
        }

    }
    
    return addedProperties.copy;
    
}

- (NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *)addedAttributes {
    return [self attributesFromProperties:self.addedProperties];
}

- (NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *)addedRelationships {
    return [self relationshipsFromProperties:self.addedProperties];
}

- (NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *)removedProperties {
    
    
    NSMutableDictionary <NSString *, NSArray <NSPropertyDescription *> *> *removedProperties = @{}.mutableCopy;
    
    NSArray <NSEntityMapping *> *transformedEntities = [self mappingEntitiesWithType:NSTransformEntityMappingType];
    
    for (NSEntityMapping *entityMapping in transformedEntities) {
        
        NSSet *propertiesSet = entityMapping.userInfo[@"removedProperties"];

        if (propertiesSet.count) {
        
            NSEntityDescription *entity = [self.migrationManager sourceEntityForEntityMapping:entityMapping];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", propertiesSet];
            NSArray *result = [entity.properties filteredArrayUsingPredicate:predicate];
            
            if (result) removedProperties[entity.name] = result;
            
        }
        
    }

    return removedProperties.copy;
    
}

- (NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *)removedAttributes {
    return [self attributesFromProperties:self.removedProperties];
}

- (NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *)removedRelationships {
    return [self relationshipsFromProperties:self.removedProperties];
}


#pragma mark - private methods

- (NSArray <NSEntityDescription *> *)mappingEntitiesDescriptionsWithType:(NSEntityMappingType)mappingType {
    
    NSArray <NSEntityMapping *> *entityMappings = [self mappingEntitiesWithType:mappingType];
    
    NSArray <NSEntityDescription *> *result = [STMFunctions mapArray:entityMappings withBlock:^id _Nonnull(NSEntityMapping *  _Nonnull entityMapping) {
        
        if (mappingType == NSRemoveEntityMappingType) {
            return [self.migrationManager sourceEntityForEntityMapping:entityMapping];
        } else {
            return [self.migrationManager destinationEntityForEntityMapping:entityMapping];
        }
        
    }];
    
    return result;
    
}

- (NSArray <NSEntityMapping *> *)mappingEntitiesWithType:(NSEntityMappingType)mappingType {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType == %d", mappingType];
    NSArray <NSEntityMapping *> *entityMappings = [self.mappingModel.entityMappings filteredArrayUsingPredicate:predicate];

    return entityMappings;
    
}

- (NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *)attributesFromProperties:(NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *)properties {
    
    NSMutableDictionary <NSString *, NSArray <NSAttributeDescription *> *> *attributes = @{}.mutableCopy;
    
    [properties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSPropertyDescription *> * _Nonnull propertiesArray, BOOL * _Nonnull stop) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"class == %@", [NSAttributeDescription class]];
        NSArray <NSAttributeDescription *> *result = (NSArray <NSAttributeDescription *> *)[propertiesArray filteredArrayUsingPredicate:predicate];
        
        if (result.count) attributes[entityName] = result;
        
    }];

    return attributes.copy;
    
}

- (NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *)relationshipsFromProperties:(NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *)properties {
    
    NSMutableDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *relationships = @{}.mutableCopy;
    
    [properties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSPropertyDescription *> * _Nonnull propertiesArray, BOOL * _Nonnull stop) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"class == %@", [NSRelationshipDescription class]];
        NSArray <NSRelationshipDescription *> *result = (NSArray <NSRelationshipDescription *> *)[propertiesArray filteredArrayUsingPredicate:predicate];
        
        if (result) relationships[entityName] = result;
        
    }];

    return relationships.copy;
    
}


#pragma mark - info

- (void)showMappingInfo {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType != %d", NSCopyEntityMappingType];
    NSArray *changedEntityMappings = [self.mappingModel.entityMappings filteredArrayUsingPredicate:predicate];
    
    NSArray *entityMappingTypes = @[@(NSAddEntityMappingType),
                                    @(NSCustomEntityMappingType),
                                    @(NSRemoveEntityMappingType),
                                    @(NSTransformEntityMappingType),
                                    @(NSUndefinedEntityMappingType)];
    
    for (NSNumber *mapType in entityMappingTypes) {
        
        NSUInteger mappingType = mapType.integerValue;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType == %d", mappingType];
        NSArray *result = [changedEntityMappings filteredArrayUsingPredicate:predicate];
        
        if (result.count) {
            
            switch (mappingType) {
                case NSAddEntityMappingType:
                    [self parseAddEntityMappings:result];
                    break;
                    
                case NSCustomEntityMappingType:
                    [self parseCustomEntityMappings:result];
                    break;
                    
                case NSRemoveEntityMappingType:
                    [self parseRemoveEntityMappings:result];
                    break;
                    
                case NSTransformEntityMappingType:
                    [self parseTransformEntityMappings:result];
                    break;
                    
                case NSUndefinedEntityMappingType:
                    [self parseUndefinedEntityMappings:result];
                    break;
                    
                default:
                    break;
            }
            
        }
        
    }
    
}

- (void)parseAddEntityMappings:(NSArray *)addEntityMappings {
    
    NSLog(@"!!! next entities should be added: ");
    for (NSEntityMapping *entityMapping in addEntityMappings) {
        NSLog(@"!!! add %@", entityMapping.destinationEntityName);
    }
    
}

- (void)parseCustomEntityMappings:(NSArray *)customEntityMappings {
    NSLog(@"customEntityMappings %@", customEntityMappings);
}

- (void)parseRemoveEntityMappings:(NSArray *)removeEntityMappings {
    
    NSLog(@"!!! next entities should be removed: ");
    for (NSEntityMapping *entityMapping in removeEntityMappings) {
        NSLog(@"!!! remove %@", entityMapping.sourceEntityName);
    }
    
}

- (void)parseTransformEntityMappings:(NSArray *)transformEntityMappings {
    
    NSLog(@"!!! next entities should be transformed: ");
    
    for (NSEntityMapping *entityMapping in transformEntityMappings) {
        
        NSLog(@"!!! transform %@", entityMapping.destinationEntityName);
        
        NSSet *addedProperties = entityMapping.userInfo[@"addedProperties"];
        if (addedProperties.count) {
            for (NSString *propertyName in addedProperties) {
                NSLog(@"    !!! add property: %@", propertyName);
            }
        }
        
        NSSet *removedProperties = entityMapping.userInfo[@"removedProperties"];
        if (removedProperties.count) {
            for (NSString *propertyName in removedProperties) {
                NSLog(@"    !!! remove property: %@", propertyName);
            }
        }
        
        NSSet *mappedProperties = entityMapping.userInfo[@"mappedProperties"];
        if (mappedProperties.count) {
//            for (NSString *propertyName in mappedProperties) {
//                NSLog(@"    !!! remains the same property: %@", propertyName);
//            }
        }
        
    }
    
}

- (void)parseUndefinedEntityMappings:(NSArray *)undefinedEntityMappings {
    NSLog(@"undefinedEntityMappings %@", undefinedEntityMappings);
}


@end
