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

#import "STMModeller+Private.h"

#import "STMSessionManager.h"


@implementation STMModeller

@synthesize concreteEntities = _concreteEntities;


+ (instancetype)modellerWithModel:(NSManagedObjectModel *)model {
    return [[self alloc] initWithModel:model];
}

+ (NSManagedObjectModel *)modelWithName:(NSString *)modelName {
    
    NSString *path = [[NSBundle mainBundle] pathForResource:modelName
                                                     ofType:@"momd"];
    
    if (!path) path = [[NSBundle mainBundle] pathForResource:modelName
                                                      ofType:@"mom"];
    
    if (path) {
        
        NSError *error = nil;
        NSMappingModel *mappingModel = [self checkDataModelsWithBundlePath:path
                                                                     error:&error];
        
        if (mappingModel) {
            
            [self parseMappingModel:mappingModel];
            
        } else {
            
            if (error) {
                NSLog(@"can't create mapping model, have to create db's tables from blank");
            } else {
                NSLog(@"documentsModel was empty or can't create it or the same as bundleModel, should use the last one");
                //TODO: have to handle each of this three cases
            }
            
        }
        
        NSManagedObjectModel *model = [self modelWithPath:path];
        
        return model;
        
    }
        
    NSLog(@"there is no path for data model with name %@", modelName);
    return nil;
    
}

+ (void)parseMappingModel:(NSMappingModel *)mappingModel {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType != %d", NSCopyEntityMappingType];
    NSArray *changedEntityMappings = [mappingModel.entityMappings filteredArrayUsingPredicate:predicate];
    
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

+ (void)parseAddEntityMappings:(NSArray *)addEntityMappings {
    
//    NSLog(@"addEntityMappings %@", addEntityMappings);
    NSLog(@"!!! next entities should be added: ");
    
    for (NSEntityMapping *entityMapping in addEntityMappings) {
        
        NSLog(@"!!! add %@", entityMapping.destinationEntityName);
        
    }
    
}

+ (void)parseCustomEntityMappings:(NSArray *)customEntityMappings {
    NSLog(@"customEntityMappings %@", customEntityMappings);
}

+ (void)parseRemoveEntityMappings:(NSArray *)removeEntityMappings {

//    NSLog(@"removeEntityMappings %@", removeEntityMappings);
    NSLog(@"!!! next entities should be removed: ");
    
    for (NSEntityMapping *entityMapping in removeEntityMappings) {
        
        NSLog(@"!!! remove %@", entityMapping.sourceEntityName);
        
    }

}

+ (void)parseTransformEntityMappings:(NSArray *)transformEntityMappings {

//    NSLog(@"transformEntityMappings %@", transformEntityMappings);
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

+ (void)parseUndefinedEntityMappings:(NSArray *)undefinedEntityMappings {
    NSLog(@"undefinedEntityMappings %@", undefinedEntityMappings);
}

+ (NSMappingModel *)checkDataModelsWithBundlePath:(NSString *)bundlePath error:(NSError **)error {
    
    NSString *modelDirInDocuments = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:@"model"];

    if (![STMFunctions dirExistsOrCreateAtPath:modelDirInDocuments]) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *documentsModelPath = [modelDirInDocuments stringByAppendingPathComponent:bundlePath.lastPathComponent];
    
    NSManagedObjectModel *documentsModel = ([fm fileExistsAtPath:documentsModelPath]) ? [self modelWithPath:documentsModelPath] : nil;
    
    if (!documentsModel) {
        
        [self copyModelToPath:modelDirInDocuments
                     fromPath:bundlePath];
        return nil;
        
    }
    
    NSManagedObjectModel *bundleModel = [self modelWithPath:bundlePath];
    
    if ([bundleModel isEqual:documentsModel]) {
        
        NSLog(@"model have no changes");
        return nil;
        
    }

    NSLog(@"!!! model have changes, old should be replaced with new one !!!");
    
#warning - maybe copy new model to Documents only after successful creating of db with the new model
//    [self copyModelToPath:modelDirInDocuments
//                 fromPath:bundlePath];
    
    NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:documentsModel
                                                                     destinationModel:bundleModel
                                                                                error:error];
    
    if (!mappingModel) {
        NSLog(@"mappingModel error: %@, userInfo: %@", [*error localizedDescription], [*error userInfo]);
    }

    return mappingModel;
    
}

+ (NSManagedObjectModel *)modelWithPath:(NSString *)modelPath {
    
    if (!modelPath) return nil;
    
    NSURL *url = [NSURL fileURLWithPath:modelPath];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];

    return model;
    
}

+ (BOOL)copyModelToPath:(NSString *)newPath fromPath:(NSString *)modelPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *modelInDocuments = [newPath stringByAppendingPathComponent:modelPath.lastPathComponent];
    
    if ([fm fileExistsAtPath:modelInDocuments]) {
        if (![STMFunctions flushDirAtPath:newPath]) return NO;
    }
    
    NSError *error = nil;
    BOOL result = [fm copyItemAtPath:modelPath
                              toPath:modelInDocuments
                               error:&error];
    
    if (!result) {
        
        NSLog(@"can't copy model, error: %@", error.localizedDescription);
        return NO;
        
    } else {
        
        NSLog(@"model copy successfully");
        
    }
    
    result = [STMFunctions enumerateDirAtPath:newPath withBlock:^BOOL(NSString * _Nonnull path, NSError * _Nullable __autoreleasing * _Nullable error) {
        
        BOOL enumResult = [fm setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                               ofItemAtPath:path
                                      error:error];
        
        if (!enumResult) {
            NSLog(@"can't set attributes to %@, error: %@", path, [*error localizedDescription]);
        } else {
            NSLog(@"set attributes to %@", path);
        }
        
        return enumResult;

    }];
    
    return result;
    
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
        cache[entityKey] = @{@"fields"          : entity.attributesByName,
                             @"relationships"   : entity.relationshipsByName};
        
    }
    
    self.allEntitiesCache = cache.copy;
    
    _concreteEntities = [STMFunctions mapDictionary:self.entitiesByName withBlock:^id _Nonnull(NSEntityDescription *entity, NSString *key) {
        return [self isConcreteEntityName:key] ? entity : nil;
    }];
    
    return self;
}


#pragma mark - STMModelling

- (NSManagedObject *)newObjectForEntityName:(NSString *)entityName {
// Override the method in persister to set proper context
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

- (NSDictionary <NSString *,NSRelationshipDescription *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany cascade:(NSNumber *)cascade {
    
    return [self objectRelationshipsForEntityName:entityName
                                         isToMany:isToMany
                                          cascade:cascade
                                         optional:nil];
    
}

- (NSDictionary <NSString *,NSRelationshipDescription *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany cascade:(NSNumber *)cascade optional:(NSNumber *)optional {
    
    if (!entityName) {
        return nil;
    }
    
    NSDictionary *allRelationships = self.allEntitiesCache[entityName][@"relationships"];
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    for (NSString *relationshipName in allRelationships) {
        
        NSRelationshipDescription *relationship = allRelationships[relationshipName];
        
        if (!optional || relationship.optional == optional.boolValue) {
        
            if (!isToMany || relationship.isToMany == isToMany.boolValue) {
                
                BOOL isDeleteRule = (relationship.deleteRule == NSCascadeDeleteRule);
                
                if (!cascade || (cascade.boolValue && isDeleteRule) || (!cascade.boolValue && !isDeleteRule)){
                    result[relationshipName] = relationship;
                }
                
            }

        }
        
    }
    
    return result.copy;
    
}

- (NSDictionary <NSString *,NSString *> *)toOneRelationshipsForEntityName:(NSString *)entityName{
    return [self objectRelationshipsForEntityName:entityName isToMany:@NO];
}

- (NSDictionary <NSString *,NSString *> *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany{
    
    NSDictionary *relationships = [self objectRelationshipsForEntityName:entityName
                                                                isToMany:isToMany
                                                                 cascade:nil];
    
    return [STMFunctions mapDictionary:relationships withBlock:^id _Nonnull(NSRelationshipDescription *value, NSString *key) {
        return value.destinationEntity.name;
    }];
    
}

- (void)setObjectData:(NSDictionary *)objectData toObject:(STMDatum *)object {
    
    return [self setObjectData:objectData
                      toObject:object
                 withRelations:YES];
    
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
            
            if ([STMFunctions isNotNull:value]) {
                
                value = [STMModeller typeConversionForValue:value
                                                        key:key
                                           entityAttributes:entityAttributes];
                
            } else {
                
                value = nil;
                
            }
            
            [object setValue:value forKey:key];
            
        } else {
            
            if ([key hasSuffix:RELATIONSHIP_SUFFIX] && withRelations) {
                
                NSUInteger toIndex = key.length - RELATIONSHIP_SUFFIX.length;
                NSString *localKey = [key substringToIndex:toIndex];
                
                NSString* destinationEntityName = [ownObjectRelationships objectForKey:localKey];
                
                NSString *destinationObjectXid = [value isKindOfClass:[NSNull class]] ? nil : value;
                
                if (destinationEntityName && destinationObjectXid) {
                    
                    STMDatum *destinationObject = (STMDatum *)[self newObjectForEntityName:destinationEntityName];
                    
                    NSObject <STMPersistingFullStack> *persistenceDelegate = [STMSessionManager sharedManager].currentSession.persistenceDelegate;
                    
                    NSDictionary *destinationObjectData = [persistenceDelegate findSync:destinationEntityName
                                                                             identifier:destinationObjectXid
                                                                                options:nil
                                                                                  error:nil];
                    
                    [self setObjectData:destinationObjectData
                               toObject:destinationObject
                          withRelations:false];
//=======
//                    NSString *destinationObjectXid = [value isEqual:[NSNull null]] ? nil : value;
//                    
//                    NSManagedObject *destinationObject = (destinationObjectXid) ? [self findOrCreateManagedObjectOf:ownObjectRelationships[localKey] identifier:destinationObjectXid] : nil;
//>>>>>>> EntityControllerRefactor
                    
                    [object setValue:destinationObject forKey:localKey];
                    
                }
                
            }
            
        }
        
    }
    
    object.isFantom = @(NO);
    
}

- (NSDictionary *)dictionaryFromManagedObject:(NSManagedObject *)object {
    // TODO: remove dependency on STMDatum
    return [self dictionaryForJSWithObject:(STMDatum *)object withNulls:YES withBinaryData:YES];
}

- (NSSet<NSString*>*)hierarchyForEntityName:(NSString*)name{
    
    NSSet *result = [NSSet set];
    
    NSDictionary<NSString*, NSEntityDescription*>* entitiesByName = self.managedObjectModel.entitiesByName;
    
    if ([entitiesByName.allKeys containsObject:name]){
        
        for (NSString* subEntityName in entitiesByName[name].subentitiesByName.allKeys){
            
            result = [result setByAddingObjectsFromSet:[self hierarchyForEntityName:subEntityName]];
            
            if ([self isConcreteEntityName:subEntityName]){
                
                result = [result setByAddingObject:subEntityName];
                
            }
            
        }
        
    }
    
    return result;
}

- (NSPredicate *)phantomPredicateForOptions:(NSDictionary *)options {

    BOOL isFantom = [options[STMPersistingOptionFantoms] boolValue];
    return [NSPredicate predicateWithFormat:@"isFantom == %@", @(isFantom)];

}

- (NSPredicate *)primaryKeyPredicateEntityName:(NSString *)entityName values:(NSArray *)values {
    
    if (values.count == 1) return [NSPredicate predicateWithFormat:@"id == %@", values.firstObject];
        
    return [NSPredicate predicateWithFormat:@"id IN %@", values];
    
}

@end
