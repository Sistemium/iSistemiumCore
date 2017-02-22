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
        
        [self copyModelToDocumentsFromPath:path];
        
        NSURL *url = [NSURL fileURLWithPath:path];
        
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        
        return model;
        
    }
        
    NSLog(@"there is no path for data model with name %@", modelName);
    return nil;
    
}

+ (void)copyModelToDocumentsFromPath:(NSString *)modelPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *modelDirInDocuments = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:@"model"];
    
    if (![fm fileExistsAtPath:modelDirInDocuments]) {
        
        NSError *error = nil;
        BOOL result = [fm createDirectoryAtPath:modelDirInDocuments
                    withIntermediateDirectories:YES
                                     attributes:ATTRIBUTE_FILE_PROTECTION_NONE
                                          error:&error];
        
        if (!result) {
            
            NSLog(@"can't create directory at path: %@, error: %@", modelDirInDocuments, error.localizedDescription);
            return;
            
        }
        
    }
    
    NSString *modelInDocuments = [modelDirInDocuments stringByAppendingPathComponent:modelPath.lastPathComponent];
    
    if (![fm fileExistsAtPath:modelInDocuments]) {
        
        NSError *error = nil;
        BOOL result = [fm copyItemAtPath:modelPath
                                  toPath:modelInDocuments
                                   error:&error];
        
        if (!result) {
            
            NSLog(@"can't copy model, error: %@", error.localizedDescription);
            return;
            
        } else {
            
            NSLog(@"model copy successfully");
            
        }
        
        NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:modelDirInDocuments];
        
        for (NSString *thePath in dirEnum) {

            NSError *error = nil;
            
            NSString *fullPath = [modelDirInDocuments stringByAppendingPathComponent:thePath];
            
            BOOL result = [fm setAttributes:ATTRIBUTE_FILE_PROTECTION_NONE
                               ofItemAtPath:fullPath
                                      error:&error];
            
            if (!result) {
                
                NSLog(@"can't set attributes to %@, error: %@", fullPath, error.localizedDescription);
                break;
                
            } else {
                
                NSLog(@"set attributes to %@", thePath);
                
            }
            
        }
        return;

    }
    
    NSURL *url = [NSURL fileURLWithPath:modelPath];
    NSManagedObjectModel *bundleModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    url = [NSURL fileURLWithPath:modelInDocuments];
    NSManagedObjectModel *documentsModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
    if ([bundleModel isEqual:documentsModel]) {
        
        NSLog(@"model have no changes");
        
    } else {
        
        NSLog(@"!!! model have changes, old should be replaced with new one !!!");
        
    }

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
    
    return result;
    
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
