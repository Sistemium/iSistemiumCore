//
//  STMCoreObjectsController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 07/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreObjectsController.h"

#import "STMCoreAuthController.h"
#import "STMFunctions.h"
#import "STMSyncer.h"
#import "STMEntityController.h"
#import "STMClientDataController.h"
#import "STMCorePicturesController.h"
#import "STMRecordStatusController.h"

#import "STMConstants.h"

#import "STMCoreDataModel.h"

#import "STMCoreNS.h"

#import "STMModeller+Private.h"


#define FLUSH_LIMIT MAIN_MAGIC_NUMBER


@interface STMCoreObjectsController()

@property (nonatomic, strong) NSMutableDictionary *entitiesOwnKeys;
@property (nonatomic, strong) NSMutableDictionary *entitiesOwnRelationships;
@property (nonatomic, strong) NSMutableDictionary *entitiesToOneRelationships;
@property (nonatomic, strong) NSMutableDictionary *entitiesToManyRelationships;
@property (nonatomic, strong) NSArray *localDataModelEntityNames;
@property (nonatomic, strong) NSArray *coreEntityKeys;
@property (nonatomic, strong) NSArray *coreEntityRelationships;
@property (nonatomic) BOOL isInFlushingProcess;

@end


@implementation STMCoreObjectsController


- (NSMutableDictionary *)entitiesOwnKeys {
    
    if (!_entitiesOwnKeys) {
        _entitiesOwnKeys = [@{} mutableCopy];
    }
    return _entitiesOwnKeys;
    
}

- (NSMutableDictionary *)entitiesOwnRelationships {
    
    if (!_entitiesOwnRelationships) {
        _entitiesOwnRelationships = [@{} mutableCopy];
    }
    return _entitiesOwnRelationships;
    
}

- (NSMutableDictionary *)entitiesToOneRelationships {
    
    if (!_entitiesToOneRelationships) {
        _entitiesToOneRelationships = [@{} mutableCopy];
    }
    return _entitiesToOneRelationships;
    
}

- (NSMutableDictionary *)entitiesToManyRelationships {
    
    if (!_entitiesToManyRelationships) {
        _entitiesToManyRelationships = [@{} mutableCopy];
    }
    return _entitiesToManyRelationships;
    
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self addObservers];
    }
    return self;
    
}

- (void)addObservers {
    

}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - singleton

+ (STMCoreObjectsController *)sharedController {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedController = nil;
    
    dispatch_once(&pred, ^{
        _sharedController = [[self alloc] init];
    });
    
    return _sharedController;
    
}


#pragma mark - recieved objects management

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    [object removeObserver:self forKeyPath:keyPath];
    
    if ([object isKindOfClass:[NSManagedObject class]]) {
        
        id oldValue = [change valueForKey:NSKeyValueChangeOldKey];
        
        if ([oldValue isKindOfClass:[NSDate class]]) {
            
            [(NSManagedObject *)object setValue:oldValue forKey:keyPath];
            
        } else {
//            CLS_LOG(@"observeValueForKeyPath oldValue class %@ != NSDate / did crashed here earlier", [oldValue class]);
        }
        
    }

}


+ (BOOL)setRelationshipFromDictionary:(NSDictionary *)dictionary {
    
    NSString *name = dictionary[@"name"];
    NSArray *nameExplode = [name componentsSeparatedByString:@"."];
    NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:nameExplode[1]];
    
    NSDictionary *serverDataModel = [[STMEntityController stcEntities] copy];
    
    if ([[serverDataModel allKeys] containsObject:entityName]) {
        
        STMEntity *entityModel = serverDataModel[entityName];
        NSString *roleOwner = entityModel.roleOwner;
        NSString *roleOwnerEntityName = [ISISTEMIUM_PREFIX stringByAppendingString:roleOwner];
        NSString *roleName = entityModel.roleName;
        NSDictionary *ownerRelationships = [self ownObjectRelationshipsForEntityName:roleOwnerEntityName];
        NSString *destinationEntityName = ownerRelationships[roleName];
        NSString *destination = [destinationEntityName stringByReplacingOccurrencesOfString:ISISTEMIUM_PREFIX withString:@""];
        NSDictionary *properties = dictionary[@"properties"];
        NSDictionary *ownerData = properties[roleOwner];
        NSDictionary *destinationData = properties[destination];
        NSString *ownerXid = ownerData[@"xid"];
        NSString *destinationXid = destinationData[@"xid"];
        BOOL ok = YES;
        
        if (!ownerXid || [ownerXid isEqualToString:@""] || !destinationXid || [destinationXid isEqualToString:@""]) {
            
            ok = NO;
            NSLog(@"Not ok relationship dictionary %@", dictionary);
            
        }
        
        if (ok) {
            
            NSManagedObject *ownerObject = [self objectFindOrCreateForEntityName:roleOwnerEntityName andXidString:ownerXid];
            NSManagedObject *destinationObject = [self objectFindOrCreateForEntityName:destinationEntityName andXidString:destinationXid];
            
            NSSet *destinationSet = [ownerObject valueForKey:roleName];
            
            if ([destinationSet containsObject:destinationObject]) {
                
                NSLog(@"already have relationship %@ %@ — %@ %@", roleOwnerEntityName, ownerXid, destinationEntityName, destinationXid);
                
                
            } else {
                
                BOOL ownerIsWaitingForSync = [self isWaitingToSyncForObject:ownerObject];
                BOOL destinationIsWaitingForSync = [self isWaitingToSyncForObject:destinationObject];
                
                NSDate *ownerDeviceTs = [ownerObject valueForKey:@"deviceTs"];
                NSDate *destinationDeviceTs = [destinationObject valueForKey:@"deviceTs"];
                
                [[ownerObject mutableSetValueForKey:roleName] addObject:destinationObject];
                
                if (!ownerIsWaitingForSync) {
                    [ownerObject setValue:ownerDeviceTs forKey:@"deviceTs"];
                }
                
                if (!destinationIsWaitingForSync) {
                    [destinationObject setValue:destinationDeviceTs forKey:@"deviceTs"];
                }
                
            }
            
            
        }
        
        return YES;
        
    } else {
        
        NSLog(@"dataModel have no relationship's entity with name %@", entityName);
        
        return NO;
        
    }

}


#pragma mark - info methods

+ (BOOL)isWaitingToSyncForObject:(NSManagedObject *)object {
    
    if (object.entity.name) {
        
        BOOL isInSyncList = [[STMEntityController uploadableEntitiesNames] containsObject:(NSString * _Nonnull)object.entity.name];
        
        NSDate *lts = [object valueForKey:STMPersistingOptionLts];
        NSDate *deviceTs = [object valueForKey:@"deviceTs"];
        
        return (isInSyncList && lts && [lts compare:deviceTs] == NSOrderedAscending);

    } else {
        return NO;
    }
    
}


#pragma mark - getting specified objects

+ (STMDatum *)objectForXid:(NSData *)xidData {
    
    for (NSString *entityName in [self localDataModelEntityNames]) {
        
        STMDatum *object = [self objectForXid:xidData entityName:entityName];
        
        if (object) return object;
        
    }

    return nil;

}

+ (STMDatum *)objectForXid:(NSData *)xidData entityName:(NSString *)entityName {
#warning moved to Persister+CoreData 
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.predicate = [NSPredicate predicateWithFormat:@"xid == %@", xidData];
        
        NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
        
        if (fetchResult.firstObject) return fetchResult.firstObject;

    }
    
    return nil;
    
}


#warning Need to move it somewhere
+ (void)setObjectData:(NSDictionary *)objectData toObject:(STMDatum *)object {
    [self.persistenceDelegate setObjectData:objectData toObject:object];
}

+ (STMDatum *)objectFindOrCreateForEntityName:(NSString *)entityName andXid:(NSData *)xidData {
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        STMDatum *object = [self objectForXid:xidData entityName:entityName];
        
        if (!object) object = [self newObjectForEntityName:entityName andXid:xidData];
        
        return object;
        
    } else {
        
        return nil;
        
    }
    
}

+ (STMDatum *)objectFindOrCreateForEntityName:(NSString *)entityName andXidString:(NSString *)xid {
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        NSData *xidData = [STMFunctions xidDataFromXidString:xid];

        STMDatum *object = [self objectForXid:xidData entityName:entityName];
        
        if (!object) object = [self newObjectForEntityName:entityName andXid:xidData];
        
        return object;
        
    } else {
        
        return nil;
        
    }
    
}

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName {
    return [self newObjectForEntityName:entityName andXid:nil isFantom:YES];
}

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName isFantom:(BOOL)isFantom {
    return [self newObjectForEntityName:entityName andXid:nil isFantom:isFantom];
}

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName andXid:(NSData *)xidData {
    return [self newObjectForEntityName:entityName andXid:xidData isFantom:YES];
}

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName andXid:(NSData *)xidData isFantom:(BOOL)isFantom {
    
    NSManagedObjectContext *context = [self document].managedObjectContext;
    
    if (context) {
    
        STMDatum *object = [STMEntityDescription insertNewObjectForEntityForName:entityName
                                                          inManagedObjectContext:context];
        
        object.isFantom = @(isFantom);
        
        if (xidData) object.xid = xidData;
        
        return object;

    } else {
        
        return nil;
        
    }
    
}


#pragma mark - getting entity properties

+ (NSArray *)attributesForEntityName:(NSString *)entityName withType:(NSAttributeType)type {
    
    STMEntityDescription *objectEntity = [STMEntityDescription entityForName:entityName inManagedObjectContext:[self document].managedObjectContext];
    
    NSMutableArray *resultSet = @[].mutableCopy;

    for (NSString *key in objectEntity.attributesByName.allKeys) {
        
        NSAttributeDescription *attribute = objectEntity.attributesByName[key];
        
        if (attribute.attributeType == type) {
            [resultSet addObject:key];
        }
        
    }
    
    return resultSet;

}

+ (NSSet *)ownObjectKeysForEntityName:(NSString *)entityName {
    
    if (!entityName) {
        return nil;
    }
    
    NSMutableDictionary *entitiesOwnKeys = [self sharedController].entitiesOwnKeys;
    NSMutableSet *objectKeys = entitiesOwnKeys[entityName];
    
    if (!objectKeys) {

        STMEntityDescription *objectEntity = [STMEntityDescription entityForName:entityName
                                                          inManagedObjectContext:[self document].managedObjectContext];
        
        NSSet *coreKeys = [NSSet setWithArray:[self coreEntityKeys]];

        objectKeys = [NSMutableSet setWithArray:objectEntity.attributesByName.allKeys];
        [objectKeys minusSet:coreKeys];
        
        entitiesOwnKeys[entityName] = objectKeys;
        
    }
    
    return objectKeys;
    
}

+ (NSDictionary *)ownObjectRelationshipsForEntityName:(NSString *)entityName {
    
    return [self.persistenceDelegate objectRelationshipsForEntityName:entityName isToMany:nil];
    
}

+ (NSDictionary *)toManyRelationshipsForEntityName:(NSString *)entityName {
    
    return [self.persistenceDelegate objectRelationshipsForEntityName:entityName isToMany:@YES];

}

#warning deprecated - use STMModeling (isConcreteEntityName etc)
+ (NSArray <NSString *> *)localDataModelEntityNames {
    return [self sharedController].localDataModelEntityNames;
}

- (NSArray *)localDataModelEntityNames {
    
    if (!_localDataModelEntityNames) {
        
        NSArray *entities = [[self class] document].managedObjectModel.entitiesByName.allValues;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"abstract == NO"];
        
        _localDataModelEntityNames = [[entities filteredArrayUsingPredicate:predicate] valueForKeyPath:@"name"];
        
    }
    return _localDataModelEntityNames;
    
}

+ (NSArray *)coreEntityKeys {
    return [self sharedController].coreEntityKeys;
}

- (NSArray *)coreEntityKeys {
    
    if (!_coreEntityKeys) {
        
        STMEntityDescription *coreEntity = [STMEntityDescription entityForName:NSStringFromClass([STMDatum class])
                                                        inManagedObjectContext:[STMCoreObjectsController document].managedObjectContext];
        
        _coreEntityKeys = coreEntity.attributesByName.allKeys;
        
    }
    return _coreEntityKeys;
    
}

#pragma mark - flushing

#warning should use some syncer method
+ (NSPredicate *)notUnsyncedPredicateForEntityName:(NSString*)entityName {
    
    BOOL isInSyncList = [STMEntityController.uploadableEntitiesNames containsObject:entityName];
    
    if (!isInSyncList) return nil;
    
    NSPredicate *predicate1 = [NSCompoundPredicate notPredicateWithSubpredicate:[NSPredicate predicateWithFormat:@"lts < deviceTs"]];
    
    NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"deviceTs == nil"];
    
    return [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType
                                       subpredicates:@[predicate1, predicate2]];
}

+ (void)checkObjectsForFlushing {
    
    NSLogMethodName;

    STMCoreObjectsController *sc = [self sharedController];
    
    sc.isInFlushingProcess = NO;
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        
        NSLog(@"app is not in background, flushing canceled");
        return;
        
    }

    NSDate *startFlushing = [NSDate date];
    
    NSArray *entitiesWithLifeTime = [STMEntityController entitiesWithLifeTime];

    NSMutableDictionary *entityDic = [NSMutableDictionary dictionary];
    
    for (NSDictionary *entity in entitiesWithLifeTime) {
        
        if (entity[@"name"] && ![entity[@"name"] isEqual:[NSNull null]]) {
            
            NSString *capFirstLetter = [[entity[@"name"] substringToIndex:1] capitalizedString];
            NSString *capEntityName = [entity[@"name"] stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
            NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];
         
            entityDic[entityName] = @{@"lifeTime": entity[@"lifeTime"],
                                      @"lifeTimeDateField": entity[@"lifeTimeDateField"] ? entity[@"lifeTimeDateField"] : @"deviceCts"};
            
        }
        
    }
    
    for (NSString *entityName in entityDic.allKeys) {
        
        double lifeTime = [entityDic[entityName][@"lifeTime"] doubleValue];
        NSDate *terminatorDate = [NSDate dateWithTimeInterval:-lifeTime*3600 sinceDate:startFlushing];
        
        NSString *dateField = entityDic[entityName][@"lifeTimeDateField"];
        NSArray *availableDateKeys = [self attributesForEntityName:entityName withType:NSDateAttributeType];
        dateField = ([availableDateKeys containsObject:dateField]) ? dateField : @"deviceCts";
        
        NSError *error;
        
        NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"%@ < %@", dateField, terminatorDate];
        NSPredicate *notUnsyncedPredicate = [self notUnsyncedPredicateForEntityName:entityName];
        NSMutableArray *subpredicates = @[datePredicate].mutableCopy;
        
        if (notUnsyncedPredicate) [subpredicates addObject:notUnsyncedPredicate];
        
        NSCompoundPredicate *predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                     subpredicates:subpredicates];
        
        NSUInteger deletedCount = [self.persistenceDelegate destroyAllSync:entityName
                                                                 predicate:predicate
                                                                   options:@{STMPersistingOptionRecordstatuses:@NO}
                                                                     error:&error];
        
        if (error) {
            NSLog(@"Error deleting: %@", error);
        } else {
            NSLog(@"Flushed %d of %@", deletedCount, entityName);
        }
       
    }
    
}

#pragma mark - finish of recieving objects

+ (void)dataLoadingFinished {
    
    [STMCorePicturesController checkPhotos];
//    [self checkObjectsForFlushing];
    
#ifdef DEBUG
    [self logTotalNumberOfObjectsInStorages];
#else

#endif
    
    [[self document] saveDocument:^(BOOL success) {

    }];

}

+ (void)logTotalNumberOfObjectsInStorages {
    
    NSArray *entityNames = [self.persistenceDelegate entitiesByName].allKeys;
    
    NSUInteger totalCountFMDB = 0;
    NSUInteger totalCountCoreData = 0;
    NSUInteger totalFantoms = 0;
    
    for (NSString *entityName in entityNames) {
        
        if (![self.persistenceDelegate isConcreteEntityName:entityName]) continue;
        
        NSError *error = nil;
        
        NSUInteger countFMDB =
        [self.persistenceDelegate countSync:entityName
                                  predicate:nil
                                    options:@{STMPersistingOptionForceStorageFMDB}
                                      error:&error];
        
        NSUInteger countCoreData =
        [self.persistenceDelegate countSync:entityName
                                  predicate:nil
                                    options:@{STMPersistingOptionForceStorageCoreData}
                                      error:&error];
        
        NSUInteger countFantoms =
        [self.persistenceDelegate countSync:entityName
                                  predicate:nil
                                    options:@{STMPersistingOptionFantoms:@YES}
                                      error:&error];
        
        NSLog(@"%@ count: %u + %u%@",
              entityName, countFMDB, countCoreData,
              countFantoms ? [NSString stringWithFormat:@" (+ %@ fantoms)", @(countFantoms)] : @""
              );
        
        totalCountFMDB += countFMDB;
        totalCountCoreData += countCoreData;
        totalFantoms += countFantoms;
        
    }
    
    NSLog(@"Total count: %u + %u", totalCountFMDB, totalCountCoreData);
    NSLog(@"Fantoms total count: %@", @(totalFantoms));
    
}

#warning needs to be removed
+ (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    return [STMFunctions error:error withMessage:errorMessage];

}


#pragma mark - generate arrayForJS


+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object {
    return [self dictionaryForJSWithObject:object withNulls:YES];
}

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object withNulls:(BOOL)withNulls {
    return [self dictionaryForJSWithObject:object withNulls:withNulls withBinaryData:YES];
}

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object withNulls:(BOOL)withNulls withBinaryData:(BOOL)withBinaryData {

    if (!object) {
        return @{};
    }
    
    NSMutableDictionary *propertiesDictionary = @{}.mutableCopy;
    
    if (object.xid) propertiesDictionary[@"id"] = [STMFunctions UUIDStringFromUUIDData:(NSData *)object.xid];
    if (object.deviceTs) propertiesDictionary[@"ts"] = [STMFunctions stringFromDate:(NSDate *)object.deviceTs];
    
    NSArray *ownKeys = [self ownObjectKeysForEntityName:object.entity.name].allObjects;
    NSArray *ownRelationships = [self.persistenceDelegate toOneRelationshipsForEntityName:object.entity.name].allKeys;
    
    ownKeys = [ownKeys arrayByAddingObjectsFromArray:@[STMPersistingOptionLts]];
    
    [propertiesDictionary addEntriesFromDictionary:[object propertiesForKeys:ownKeys withNulls:withNulls withBinaryData:withBinaryData]];
    [propertiesDictionary addEntriesFromDictionary:[object relationshipXidsForKeys:ownRelationships withNulls:withNulls]];
    
//    NSLog(@"--------------- updated object %@", propertiesDictionary[@"deviceAts"]);

    return propertiesDictionary;

}

#pragma mark - create dictionary from object

+ (NSArray *)jsonForObjectsWithParameters:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error {
    
    NSString *errorMessage = nil;
    
    if ([parameters isKindOfClass:[NSDictionary class]] && parameters[@"entityName"] && [parameters[@"entityName"] isKindOfClass:[NSString class]]) {
        
        NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:(NSString * _Nonnull)parameters[@"entityName"]];
        
        BOOL sessionIsRunning = (self.session.status == STMSessionRunning);
        if (sessionIsRunning && self.document) {
            
            return [self.persistenceDelegate findAllSync:entityName predicate:nil options:parameters error:error];
            
            
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"session is not running, please try later"];
            
        }
        
    } else {
        
        errorMessage = [NSString stringWithFormat:@"requestObjects: parameters is not NSDictionary"];
        
    }

    if (errorMessage) [self error:error withMessage:errorMessage];
    
    return nil;
    
}


@end
