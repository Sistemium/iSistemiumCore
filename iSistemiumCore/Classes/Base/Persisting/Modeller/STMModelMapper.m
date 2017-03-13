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

@property (nonatomic, weak, readonly) id <STMFiling> filing;

@property (nonatomic, strong) NSString *sourceModelName;
@property (nonatomic, strong) NSString *destinationModelName;
@property (nonatomic, strong) NSString *basePath;


@end


@implementation STMModelMapper

@synthesize sourceModel = _sourceModel;
@synthesize destinationModel = _destinationModel;

@synthesize mappingModel = _mappingModel;
@synthesize migrationManager = _migrationManager;

@synthesize addedEntities = _addedEntities;
@synthesize removedEntities = _removedEntities;

@synthesize addedProperties = _addedProperties;
@synthesize addedAttributes = _addedAttributes;
@synthesize addedRelationships = _addedRelationships;

@synthesize removedProperties = _removedProperties;
@synthesize removedAttributes = _removedAttributes;
@synthesize removedRelationships = _removedRelationships;

@synthesize needToMigrate = _needToMigrate;


- (instancetype)initWithModelName:(NSString *)modelName filing:(id <STMFiling>)filing basePath:(NSString *)basePath error:(NSError **)error {
    
    return [self initWithSourceModelName:modelName
                    destinationModelName:modelName
                                  filing:filing
                                basePath:basePath
                                   error:error];
    
}

- (instancetype)initWithSourceModelName:(NSString *)sourceModelName destinationModelName:(NSString *)destinationModelName filing:(id <STMFiling>)filing  basePath:(NSString *)basePath error:(NSError **)error {
    
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    _filing = filing;
    self.basePath = basePath;
    
    self.sourceModelName = sourceModelName;
    self.destinationModelName = destinationModelName;
    
    NSManagedObjectModel *sourceModel = [self loadModelFromFile:sourceModelName];
    NSManagedObjectModel *destinationModel = [self bundledModelWithName:destinationModelName];
    
    if (!sourceModel) sourceModel = [[NSManagedObjectModel alloc] init];
    if (!destinationModel) destinationModel = [[NSManagedObjectModel alloc] init];
    
    _needToMigrate = ![sourceModel isEqual:destinationModel];

    if (_needToMigrate) {
        NSLog(@"ModelMapper need to migrate");
    }
    
    _sourceModel = sourceModel;
    _destinationModel = destinationModel;
    
    _mappingModel = [NSMappingModel inferredMappingModelForSourceModel:sourceModel
                                                      destinationModel:destinationModel
                                                                 error:error];
    
    if (*error) {
        NSLog(@"NSMappingModel error: %@", [*error localizedDescription]);
    }
    
    _migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel
                                                       destinationModel:destinationModel];
    
#ifdef DEBUG
    [self showMappingInfo];
#endif
    
    return self;

}

- (NSString *)basePath {
    
    if (!_basePath) {
        _basePath = [self.filing persistenceBasePath];
    }
    return _basePath;
    
}

- (NSManagedObjectModel *)bundledModelWithName:(NSString *)modelName {
    
    NSURL *url = [NSURL URLWithString:[self.filing bundledModelFile:modelName]];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
}

- (NSManagedObjectModel *)loadModelFromFile:(NSString *)modelName {
    
    NSString *path = [self.basePath stringByAppendingPathComponent:modelName];
    
    NSError *error = nil;
    
    BOOL result = [self.filing fileExistsAtPath:path];
    
    if (!result) {

        NSLog(@"where is no model file at path: %@, return empty model", path);
        return [[NSManagedObjectModel alloc] init];

    }
    
    NSData *modelData = [NSData dataWithContentsOfFile:path
                                               options:0
                                                 error:&error];
    
    if (!modelData) {
        
        if (error) {
            
            NSLog(@"error: %@", error.localizedDescription);
            NSLog(@"can't load model from path %@, return empty model", path);
            
        }
        
        return [[NSManagedObjectModel alloc] init];
        
    }
    
    id unarchiveObject = [NSKeyedUnarchiver unarchiveObjectWithData:modelData];
    
    if (![unarchiveObject isKindOfClass:[NSManagedObjectModel class]]) {
        
        NSLog(@"loaded model from file is not NSManagedObjectModel class, return empty model");
        return [[NSManagedObjectModel alloc] init];
        
    }
    
    return (NSManagedObjectModel *)unarchiveObject;
    
}

- (void)saveModelToFile:(NSString *)modelName {
    
    NSData *modelData = [NSKeyedArchiver archivedDataWithRootObject:self.destinationModel];
    
    NSString *path = [self.basePath stringByAppendingPathComponent:modelName];
    
    NSError *error = nil;
    BOOL writeResult = [modelData writeToFile:path
                                      options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                        error:&error];
    
    if (!writeResult) {
        NSLog(@"can't write model to path %@", path);
    }
    
}


#pragma mark - STMModelMapping

- (void)migrationComplete {
    [self saveModelToFile:self.destinationModelName];
}

- (NSArray <NSEntityDescription *> *)addedEntities {
    
    if (!_addedEntities) {
        _addedEntities = [self mappingEntitiesDescriptionsWithType:NSAddEntityMappingType];
    }
    return _addedEntities;

}

- (NSArray <NSEntityDescription *> *)removedEntities {
    
    if (!_removedEntities) {
        _removedEntities = [self mappingEntitiesDescriptionsWithType:NSRemoveEntityMappingType];
    }
    return _removedEntities;
    
}

- (NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *)addedProperties {
    
    if (!_addedProperties) {
        
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
        
        _addedProperties = addedProperties;
        
    }
    return _addedProperties;
    
}

- (NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *)addedAttributes {
    
    if (!_addedAttributes) {
        
        NSMutableDictionary <NSString *, NSArray <NSAttributeDescription *> *> *addedAttributes = @{}.mutableCopy;
        
        [self.addedProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSPropertyDescription *> * _Nonnull propertiesArray, BOOL * _Nonnull stop) {
            
            NSEntityDescription *entity = self.destinationModel.entitiesByName[entityName];
            NSArray <NSString *> *attributesNames = entity.attributesByName.allKeys;
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", attributesNames];
            NSArray <NSAttributeDescription *> *result = (NSArray <NSAttributeDescription *> *)[propertiesArray filteredArrayUsingPredicate:predicate];
            
            if (result.count) addedAttributes[entityName] = result;
            
        }];
        
        _addedAttributes = addedAttributes;
        
    }
    return _addedAttributes;
    
}

- (NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *)addedRelationships {
    
    if (!_addedRelationships) {
        
        NSMutableDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *addedRelationships = @{}.mutableCopy;
        
        [self.addedProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSPropertyDescription *> * _Nonnull propertiesArray, BOOL * _Nonnull stop) {
            
            NSEntityDescription *entity = self.destinationModel.entitiesByName[entityName];
            NSArray <NSString *> *relationshipsNames = entity.relationshipsByName.allKeys;
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", relationshipsNames];
            NSArray <NSRelationshipDescription *> *result = (NSArray <NSRelationshipDescription *> *)[propertiesArray filteredArrayUsingPredicate:predicate];
            
            if (result) addedRelationships[entityName] = result;
            
        }];
        
        _addedRelationships = addedRelationships;

    }
    return _addedRelationships;
    
}

- (NSDictionary <NSString *, NSArray <NSPropertyDescription *> *> *)removedProperties {
    
    if (!_removedProperties) {
        
        NSMutableDictionary <NSString *, NSArray <NSPropertyDescription *> *> *removedProperties = @{}.mutableCopy;
        
        NSArray <NSEntityMapping *> *transformedEntities = [self mappingEntitiesWithType:NSTransformEntityMappingType];
        
        for (NSEntityMapping *entityMapping in transformedEntities) {
            
            NSSet *propertiesSet = entityMapping.userInfo[@"removedProperties"];

            if (propertiesSet.count) {
            
                NSEntityDescription *entity = [self.migrationManager destinationEntityForEntityMapping:entityMapping];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", propertiesSet];
                NSArray *result = [entity.properties filteredArrayUsingPredicate:predicate];
                
                if (result) removedProperties[entity.name] = result;
                
            }
            
        }
        
        _removedProperties = removedProperties;

    }
    return _removedProperties;
    
}

- (NSDictionary <NSString *, NSArray <NSAttributeDescription *> *> *)removedAttributes {
    
    if (!_removedAttributes) {
    }
    return _removedAttributes;
    
}

- (NSDictionary <NSString *, NSArray <NSRelationshipDescription *> *> *)removedRelationships {
    
    if (!_removedRelationships) {
    }
    return _removedRelationships;
    
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
            for (NSString *propertyName in mappedProperties) {
                NSLog(@"    !!! remains the same property: %@", propertyName);
            }
        }
        
    }
    
}

- (void)parseUndefinedEntityMappings:(NSArray *)undefinedEntityMappings {
    NSLog(@"undefinedEntityMappings %@", undefinedEntityMappings);
}


@end
