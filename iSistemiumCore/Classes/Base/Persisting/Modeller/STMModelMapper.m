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

@property (nonatomic, strong) NSString *sourceModelName;
@property (nonatomic, strong) NSString *destinationModelName;


@end


@implementation STMModelMapper

@synthesize filing = _filing;

@synthesize sourceModel = _sourceModel;
@synthesize sourceModeling = _sourceModeling;

@synthesize destinationModel = _destinationModel;
@synthesize destinationModeling = _destinationModeling;

@synthesize mappingModel = _mappingModel;
@synthesize migrationManager = _migrationManager;

@synthesize addedEntities = _addedEntities;
@synthesize removedEntities = _removedEntities;

@synthesize addedProperties = _addedProperties;
@synthesize removedProperties = _removedProperties;


- (instancetype)initWithModelName:(NSString *)modelName filing:(id <STMFiling>)filing error:(NSError **)error {
    
    return [self initWithSourceModelName:modelName
                    destinationModelName:modelName
                                  filing:filing
                                   error:error];
    
}

- (instancetype)initWithSourceModelName:(NSString *)sourceModelName destinationModelName:(NSString *)destinationModelName filing:(id <STMFiling>)filing error:(NSError **)error {
    
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    _filing = filing;
    
    self.sourceModelName = sourceModelName;
    self.destinationModelName = destinationModelName;
    
    NSManagedObjectModel *sourceModel = [self loadModelFromFile:sourceModelName];
    NSManagedObjectModel *destinationModel = [self bundledModelWithName:destinationModelName];
    
    if (!sourceModel) sourceModel = [[NSManagedObjectModel alloc] init];
    if (!destinationModel) destinationModel = [[NSManagedObjectModel alloc] init];
    
    _sourceModel = sourceModel;
    _sourceModeling = [STMModeller modellerWithModel:sourceModel];
    
    _destinationModel = destinationModel;
    _destinationModeling = [STMModeller modellerWithModel:destinationModel];
    
    _mappingModel = [NSMappingModel inferredMappingModelForSourceModel:sourceModel
                                                      destinationModel:destinationModel
                                                                 error:error];
    
    _migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel
                                                       destinationModel:destinationModel];
#ifdef DEBUG
    [self showMappingInfo];
#endif
    
    return self;

}

- (NSManagedObjectModel *)bundledModelWithName:(NSString *)modelName {
    
    NSURL *url = [NSURL URLWithString:[self.filing bundledModelFile:modelName]];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
}

- (NSManagedObjectModel *)loadModelFromFile:(NSString *)modelName {
    
    NSString *path = [[self.filing persistenceBasePath] stringByAppendingPathComponent:modelName];
    
    NSError *error = nil;
    NSData *modelData = [NSData dataWithContentsOfFile:path
                                               options:0
                                                 error:&error];
    
    if (!modelData) {
        
        if (error) {
            
            NSLog(@"can't load model from path %@, return empty model", path);
            NSLog(@"error: %@", error.localizedDescription);
            
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

    
}


#pragma mark - STMModelMapping

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

- (NSDictionary <NSString *, NSArray <NSString *> *> *)addedProperties {
    
    if (!_addedProperties) {
        
        NSMutableDictionary <NSString *, NSArray <NSString *> *> *addedProperties = @{}.mutableCopy;
        
        NSArray <NSEntityMapping *> *transformedEntities = [self mappingEntitiesWithType:NSTransformEntityMappingType];
        
        for (NSEntityMapping *entityMapping in transformedEntities) {
            
            NSSet *propertiesSet = entityMapping.userInfo[@"addedProperties"];
            
            if (propertiesSet.count) {
                addedProperties[entityMapping.destinationEntityName] = propertiesSet.allObjects;
            }

        }
        
        _addedProperties = addedProperties;
        
    }
    return _addedProperties;
    
}

- (NSDictionary <NSString *, NSArray <NSString *> *> *)removedProperties {
    
    if (!_removedProperties) {
        
        NSMutableDictionary <NSString *, NSArray <NSString *> *> *removedProperties = @{}.mutableCopy;
        
        NSArray <NSEntityMapping *> *transformedEntities = [self mappingEntitiesWithType:NSTransformEntityMappingType];
        
        for (NSEntityMapping *entityMapping in transformedEntities) {
            
            NSSet *propertiesSet = entityMapping.userInfo[@"removedProperties"];
            
            if (propertiesSet.count) {
                removedProperties[entityMapping.destinationEntityName] = propertiesSet.allObjects;
            }
            
        }
        
        _removedProperties = removedProperties;

    }
    return _removedProperties;
    
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
