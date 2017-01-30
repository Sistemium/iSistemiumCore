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
//#import "STMSocketController.h"
#import "STMScriptMessagesController.h"

#import "STMConstants.h"

#import "STMCoreDataModel.h"

#import "STMCoreNS.h"

#import "STMModeller+Private.h"

//#import "iSistemiumCore-Swift.h"
#import "STMPredicateToSQL.h"


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
@property (nonatomic) BOOL isDefantomizingProcessRunning;

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSArray <UIViewController <STMEntitiesSubscribable> *> *> *entitiesToSubscribe;
@property (nonatomic, strong) NSMutableArray *flushDeclinedObjectsArray;
@property (nonatomic, strong) NSMutableArray *updateRequests;
@property (nonatomic, strong) NSMutableArray <STMDatum *> *subscribedObjects;
//@property (nonatomic, strong) NSMutableArray *fantomsPendingArray;

@end


@implementation STMCoreObjectsController

//- (NSMutableArray *)fantomsPendingArray {
//    
//    if (!_fantomsPendingArray) {
//        _fantomsPendingArray = @[].mutableCopy;
//    }
//    return _fantomsPendingArray;
//    
//}
//
//- (NSMutableArray *)fantomsArray {
//    
//    if (!_fantomsArray) {
//        _fantomsArray = @[].mutableCopy;
//    }
//    return _fantomsArray;
//    
//}
//
//- (NSMutableArray *)notFoundFantomsArray {
//    
//    if (!_notFoundFantomsArray) {
//        _notFoundFantomsArray = @[].mutableCopy;
//    }
//    return _notFoundFantomsArray;
//    
//}

- (NSMutableArray *)updateRequests {
    
    if (!_updateRequests) {
        _updateRequests = @[].mutableCopy;
    }
    return _updateRequests;
    
}

- (NSMutableArray <STMDatum *> *)subscribedObjects {
    
    if (!_subscribedObjects) {
        _subscribedObjects = @[].mutableCopy;
    }
    return _subscribedObjects;
    
}

- (NSMutableDictionary <NSString *, NSArray <UIViewController <STMEntitiesSubscribable> *> *> *)entitiesToSubscribe {
    
    if (!_entitiesToSubscribe) {
        _entitiesToSubscribe = @{}.mutableCopy;
    }
    return _entitiesToSubscribe;
    
}

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
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:nil];

    [nc addObserver:self
           selector:@selector(objectContextDidSave:)
               name:NSManagedObjectContextDidSaveNotification
             object:nil];

    [nc addObserver:self
           selector:@selector(documentSavedSuccessfully)
               name:NOTIFICATION_DOCUMENT_SAVE_SUCCESSFULLY
             object:nil];

    [nc addObserver:self
           selector:@selector(applicationDidBecomeActive)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[STMCoreSession class]]) {
        
        STMCoreSession *session = notification.object;
        
        if (session.status != STMSessionRunning) {

        }
        
    }
    
}

- (void)objectContextDidSave:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[NSManagedObjectContext class]]) {
        
        NSManagedObjectContext *context = (NSManagedObjectContext *)notification.object;
        
        if ([context isEqual:[STMCoreObjectsController document].managedObjectContext]) {

            if (self.isInFlushingProcess) {
                
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                    [STMCoreObjectsController checkObjectsForFlushing];
                } else {
                    self.isInFlushingProcess = NO;
                }
                
            }
            
        }
        
    }
    
}

- (void)documentSavedSuccessfully {
    
    [self checkUpdateRequests];
    [self checkSubscribedObjects];
    
}

- (void)applicationDidBecomeActive {
    if (![STMCoreObjectsController document].isSaving) [self checkSubscribedObjects];
}

- (void)checkUpdateRequests {
    
    NSArray *checkRequests = self.updateRequests.copy;
    self.updateRequests = nil;
    
    for (NSDictionary *updateRequest in checkRequests) {

        NSString *entityName = updateRequest[@"entityName"];
        NSArray *requestData = updateRequest[@"data"];
        
        void (^completionHandler)(BOOL success, NSArray *updatedObjects, NSError *error) = updateRequest[@"completionHandler"];
        
        NSMutableArray *result = @[].mutableCopy;
        
        for (NSDictionary *objectData in requestData) {
            
            NSString *xidString = objectData[@"id"];
            NSError *error = nil;
            
            NSDictionary *object = [STMCoreObjectsController.persistenceDelegate findSync:entityName
                                                                               identifier:xidString
                                                                                  options:nil
                                                                                    error:&error];
            // TODO: check errors
            [result addObject:object];

        }
        
        completionHandler(YES, result, nil);
        
    }
    
}

- (void)checkSubscribedObjects {
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        return;
    }
    
    NSMutableArray *subscribedObjects = self.subscribedObjects.mutableCopy;
    self.subscribedObjects = nil;
    
    for (NSString *entityName in self.entitiesToSubscribe.allKeys) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entity.name == %@", entityName];
        NSArray *bunchOfObjects = [subscribedObjects filteredArrayUsingPredicate:predicate];
        
        if (bunchOfObjects.count > 0) {
        
            [STMCoreObjectsController sendSubscribedBunchOfObjects:bunchOfObjects
                                                        entityName:entityName];

            [subscribedObjects removeObjectsInArray:bunchOfObjects];
            
        }
        
    }

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

+ (void)processingOfDataArray:(NSArray *)array withEntityName:(NSString *)entityName andRoleName:(NSString *)roleName withCompletionHandler:(void (^)(BOOL success))completionHandler {

    NSDictionary *options;
    
    if (roleName){
        options = @{STMPersistingOptionLts: STMFunctions.stringFromNow,@"roleName":roleName};
    }else{
        options = @{STMPersistingOptionLts: STMFunctions.stringFromNow};
    }
    
    [[self persistenceDelegate] mergeMany:entityName attributeArray:array options:options].then(^(NSArray *result){
        completionHandler(YES);
    }).catch(^(NSError *error){
        completionHandler(NO);
    });

}

+ (void)insertObjectsFromArray:(NSArray *)array withEntityName:(NSString *)entityName withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    BOOL result = YES;
    
    for (NSDictionary *datum in array) {
        
        if (![self insertObjectFromDictionary:datum withEntityName:entityName]) {
            result = NO;
        }
        
    }
    
    completionHandler(result);
    
}

#warning - this method already in STMPersister+CoreData, have to remove it asap
+ (NSDictionary *)insertObjectFromDictionary:(NSDictionary *)dictionary withEntityName:(NSString *)entityName {
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        NSString *xidString = dictionary[@"id"];
        NSData *xidData = [STMFunctions xidDataFromXidString:xidString];
        
        STMDatum *object = nil;
        
        if ([entityName isEqualToString:NSStringFromClass([STMSetting class])]) {
            
            object = [[[self.class session] settingsController] settingForDictionary:dictionary];
            
        } else if ([entityName isEqualToString:NSStringFromClass([STMEntity class])]) {
            
            NSString *internalName = dictionary[@"name"];
            object = [STMEntityController entityWithName:internalName];
            
        }
        
        if (!object && xidData) object = [self objectFindOrCreateForEntityName:entityName andXid:xidData];
        
        NSDictionary *recordStatus = [STMRecordStatusController existingRecordStatusForXid:xidString];
        
        if (!(![recordStatus[@"isRemoved"] isEqual:[NSNull null]] ? [recordStatus[@"isRemoved"] boolValue]: false)) {
            
            if (!object) object = [self newObjectForEntityName:entityName];
            
            if (![self isWaitingToSyncForObject:object]) {
                
                [object setValue:@NO forKey:@"isFantom"];
                [self processingOfObject:object withEntityName:entityName fillWithValues:dictionary];
                
            }
            
        }
        
        return [self dictionaryForJSWithObject:object];
        
    } else {
        
        NSLog(@"dataModel have no object's entity with name %@", entityName);
        
        return nil;
        
    }

}

+ (void)processingOfObject:(NSManagedObject *)object withEntityName:(NSString *)entityName fillWithValues:(NSDictionary *)properties {
    
    NSSet *ownObjectKeys = [self ownObjectKeysForEntityName:entityName];
    ownObjectKeys = [ownObjectKeys setByAddingObject:@"deviceCts"];
    
    STMEntityDescription *currentEntity = (STMEntityDescription *)[object entity];
    NSDictionary *entityAttributes = currentEntity.attributesByName;
    
    for (NSString *key in ownObjectKeys) {
        
        id value = properties[key];
        
        value = (![value isKindOfClass:[NSNull class]]) ? [STMModeller typeConversionForValue:value key:key entityAttributes:entityAttributes] : nil;

        if (value) {

            [object setValue:value forKey:key];

        } else {
            
            if (![object isKindOfClass:[STMCorePicture class]] && ![key isEqualToString:@"deviceAts"]) {
                [object setValue:nil forKey:key];
            }
            
        }
        
    }
    
    if ([object isKindOfClass:[STMCorePicture class]]){
    
        STMCorePicture *picture = (STMCorePicture *)object;
        
        if (picture.imageThumbnail == nil && picture.thumbnailHref != nil){
        
            NSString* thumbnailHref = picture.thumbnailHref;
            NSURL *thumbnailUrl = [NSURL URLWithString: thumbnailHref];
            NSData *thumbnailData = [[NSData alloc] initWithContentsOfURL: thumbnailUrl];
            
            if (thumbnailData) [STMCorePicturesController setThumbnailForPicture:picture fromImageData:thumbnailData];
            
        }
        
    }
    
    [self processingOfRelationshipsForObject:object withEntityName:entityName andValues:properties];
    
    [object setValue:[NSDate date] forKey:STMPersistingOptionLts];

    [self postprocessingForObject:object];
    
    STMCoreObjectsController *coc = [self sharedController];
    
    if ([coc.entitiesToSubscribe objectForKey:entityName]) {
        
        if (object && [object isKindOfClass:[STMDatum class]]) {
            [coc.subscribedObjects addObject:(STMDatum *)object];
        }
        
    }
    
}

+ (void)processingOfRelationshipsForObject:(NSManagedObject *)object withEntityName:(NSString *)entityName andValues:(NSDictionary *)properties {
    
    NSDictionary *ownObjectRelationships = [self.persistenceDelegate toOneRelationshipsForEntityName:entityName];
    
    for (NSString *relationship in ownObjectRelationships.allKeys) {
        
        NSString *relationshipId = [relationship stringByAppendingString:RELATIONSHIP_SUFFIX];
        
        NSString *destinationObjectXid = [properties[relationshipId] isKindOfClass:[NSNull class]] ? nil : properties[relationshipId];
        
        if (destinationObjectXid) {
            
            NSManagedObject *destinationObject = [self objectFindOrCreateForEntityName:ownObjectRelationships[relationship] andXidString:destinationObjectXid];
            
            if (![[object valueForKey:relationship] isEqual:destinationObject]) {
                
                BOOL waitingForSync = [self isWaitingToSyncForObject:destinationObject];
                
                [object setValue:destinationObject forKey:relationship];
                
                if (!waitingForSync) {
                    
                    [destinationObject addObserver:[self sharedController]
                                        forKeyPath:@"deviceTs"
                                           options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
                                           context:nil];
                    
                }
                
            }
            
        } else {
            
            NSManagedObject *destinationObject = [object valueForKey:relationship];
            
            if (destinationObject) {
                
                BOOL waitingForSync = [self isWaitingToSyncForObject:destinationObject];
                
                [object setValue:nil forKey:relationship];
                
                if (!waitingForSync) {
                    
                    [destinationObject addObserver:[self sharedController]
                                        forKeyPath:@"deviceTs"
                                           options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
                                           context:nil];
                    
                }
                
            }
            
        }
        
    }
    
}

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

+ (void)postprocessingForObject:(NSManagedObject *)object {

    if ([object isKindOfClass:[STMSetting class]]) {
        
        STMSetting *setting = (STMSetting *)object;
        
        if ([setting.group isEqualToString:@"appSettings"]) {
            [STMClientDataController checkAppVersion];
        }
        
    }

}

#warning needs to be removed
+ (void)setObjectData:(NSDictionary *)objectData toObject:(STMDatum *)object {
    [self.persistenceDelegate setObjectData:objectData toObject:object];
}

#pragma mark - recieved relationships management

+ (void)setRelationshipsFromArray:(NSArray *)array withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    BOOL result = YES;
    
    for (NSDictionary *datum in array) {
        
        if (![self setRelationshipFromDictionary:datum]) {
            result = NO;
        }
        
    }

    completionHandler(result);
    
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
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.predicate = [NSPredicate predicateWithFormat:@"xid == %@", xidData];
        
        NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
        
        if (fetchResult.firstObject) return fetchResult.firstObject;

    }
    
    return nil;
    
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

+ (NSArray *)allObjectsFromContext:(NSManagedObjectContext *)context {
    
    if (!context) context = [self document].managedObjectContext;
    
    NSMutableArray *results = @[].mutableCopy;
    
    for (NSString *entityName in [self localDataModelEntityNames]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        
        NSArray *fetchResult = [context executeFetchRequest:request error:nil];
        
        if (fetchResult) [results addObjectsFromArray:fetchResult];
        
    }

    return results;

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

#warning needs to be replaced with isConcrete from modeling
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
    [self totalNumberOfObjectsInCoreData];
    [self totalNumberOfObjectsInFMDB];
#else

#endif
    
    [[self document] saveDocument:^(BOOL success) {

    }];

}

+ (void)totalNumberOfObjectsInCoreData {

    NSArray *entityNames = [self localDataModelEntityNames];
    
    NSUInteger totalCount = 0;
    
    NSMutableString *logMessage = @"".mutableCopy;
    
    for (NSString *entityName in entityNames) {
        
        NSUInteger count = [self numberOfObjectsForEntityNameInCoreData:entityName];
        [logMessage appendString:[NSString stringWithFormat:@"\n%@ count %@", entityName, @(count)]];
        totalCount += count;

    }
    
    NSLog(@"CoreData: number of objects: %@", logMessage);
    NSLog(@"CoreData: fantoms count %lu", (unsigned long)[self numberOfFantoms]);
    NSLog(@"CoreData: total count %lu", (unsigned long)totalCount);

}

+ (void)totalNumberOfObjectsInFMDB {
    
    NSArray *entityNames = [self localDataModelEntityNames];
    
    NSUInteger totalCount = 0;
    NSUInteger fantomsCount = 0;
    
    NSMutableString *logMessage = @"".mutableCopy;
    
    for (NSString *entityName in entityNames) {

        if ([self.persistenceDelegate storageForEntityName:entityName] == STMStorageTypeFMDB) {
            
            NSError *error = nil;
            NSUInteger count = [[self persistenceDelegate] countSync:entityName
                                                            predicate:nil
                                                              options:nil
                                                                error:&error];
            
            NSArray *result = [[self persistenceDelegate] findAllSync:entityName
                                                   predicate:nil
                                                     options:@{STMPersistingOptionFantoms: @YES}
                                                       error:&error];
            count += result.count;
            fantomsCount += result.count;
            
            totalCount += count;
            
            [logMessage appendString:[NSString stringWithFormat:@"\n%@ count %@", entityName, @(count)]];
            
        } else {
            [logMessage appendString:[NSString stringWithFormat:@"\n%@ count 0", entityName]];
        }
        
    }
    
    NSLog(@"FMDB: number of objects: %@", logMessage);
    NSLog(@"FMDB: fantoms count %@", @(fantomsCount));
    NSLog(@"FMDB: total count %@", @(totalCount));

}


#pragma mark - resolving fantoms

/* comment out fantom resolving due to implemeting it in new syncer

+ (BOOL)isDefantomizingProcessRunning {
    return [self sharedController].isDefantomizingProcessRunning;
}

+ (void)fillFantomsArray {
    
    STMCoreObjectsController *objController = [self sharedController];
    
    NSArray *entityNamesWithResolveFantoms = [STMEntityController entityNamesWithResolveFantoms];
    
    for (NSString *entityName in entityNamesWithResolveFantoms) {
        
        NSError *error;
        NSArray *results = [self.persistenceDelegate findAllSync:entityName predicate:nil options:@{STMPersistingOptionFantoms:@YES} error:&error];
        
        if (results.count > 0) {
            
            NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);
            
            STMEntity *entity = [STMEntityController stcEntities][entityName];
            
            if (entity.url) {
                
                for (NSDictionary *fantomObject in results) {
                    
                    NSDictionary *fantomDic = @{@"entityName":entityName, @"id":fantomObject[@"id"]};
                    
                    if (![objController.notFoundFantomsArray containsObject:fantomDic]) {
                        [objController.fantomsArray addObject:fantomDic];
                    }
                    
                }
                
            } else {
                NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
            }
            
        } else {
            NSLog(@"have no fantoms for %@", entityName);
        }
        
    }
    
}

+ (void)resolveFantoms {
    
    STMCoreObjectsController *objController = [self sharedController];
    
    @synchronized (objController) {
        
        if (!objController.isDefantomizingProcessRunning || !objController.fantomsArray.count) {
            [self fillFantomsArray];
        }
    
        if (objController.fantomsArray.count > 0) {
            
            objController.isDefantomizingProcessRunning = YES;

            NSLog(@"DEFANTOMIZING_START");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_START
                                                                object:objController
                                                              userInfo:@{@"fantomsCount": @(objController.fantomsArray.count)}];
            
            for (int i = 1; i<=10 && objController.fantomsArray.count > 0; i++) {
                [self requestNextFantom];
            }
            
        } else {
            [self stopDefantomizing];
        }
        
    }
}

+ (NSDictionary *)requestNextFantom{

    NSDictionary *fantom = [STMFunctions popArray:self.sharedController.fantomsArray];
    
    if (fantom) {
        [self.sharedController.fantomsPendingArray addObject:fantom];
        [self requestFantomObjectWithParameters:fantom];
    }
    
    return fantom;
}

+ (void)requestFantomObjectWithParameters:(NSDictionary *)parameters {
    
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        
        NSString *entityName = parameters[@"entityName"];
        
        if (![entityName hasPrefix:ISISTEMIUM_PREFIX]) {
            entityName = [ISISTEMIUM_PREFIX stringByAppendingString:entityName];
        }
        
        STMEntity *entity = [STMEntityController stcEntities][entityName];
        
        if (!entity.url) {
            
            NSString *errorMessage = [NSString stringWithFormat:@"no url for entity %@", entityName];
            
            [self requestFantomObjectErrorMessage:errorMessage
                                       parameters:parameters];
            return;
            
        }
        
        NSString *resource = entity.url;
        NSString *xidString = parameters[@"id"];
        
        if (!xidString) {
            
            NSString *errorMessage = [NSString stringWithFormat:@"no xid in request parameters %@", parameters];
            
            [self requestFantomObjectErrorMessage:errorMessage
                                       parameters:parameters];
            return;

        }
        
        [STMSocketController sendFantomFindEventToResource:resource
                                                   withXid:xidString
                                                andTimeout:[[self syncer] timeout]];

    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"parameters is not an NSDictionary class: %@", parameters];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
        
        [self requestFantomObjectErrorMessage:logMessage parameters:parameters];

    }

}

+ (void)requestFantomObjectErrorMessage:(NSString *)errorMessage parameters:(NSDictionary *)parameters {

    [self didFinishResolveFantom:parameters successfully:NO];
    NSLog(@"%@", errorMessage);

}

+ (void)didFinishResolveFantom:(NSDictionary *)fantomDic successfully:(BOOL)successfully {
    
    STMCoreObjectsController *objController = [self sharedController];
    
    if (!fantomDic) {
        
        NSString *logMessage = @"fantomDic is nil in didFinishResolveFantom:";
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
        fantomDic = objController.fantomsArray.firstObject;
        
    }
    
    @synchronized (objController.fantomsPendingArray) {
        [objController.fantomsPendingArray removeObject:fantomDic];
    }
    
    NSString *entityName = fantomDic[@"entityName"];
    NSString *fantomXid = fantomDic[@"id"];

    if (successfully) {
        
        NSLog(@"success defantomize %@ %@ pending: %u", entityName, fantomXid, objController.fantomsPendingArray.count);
        
    } else {
        
        [objController.notFoundFantomsArray addObject:fantomDic];
        NSLog(@"bad luck defantomize %@ %@", entityName, fantomXid);
        
    }
    
    @synchronized (objController) {
        if (objController.fantomsArray.count > 0) {
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_UPDATE
                                                                object:objController
                                                              userInfo:@{@"fantomsCount": @(objController.fantomsArray.count)}];

            [self requestNextFantom];
            
        } else {
            if (!objController.fantomsPendingArray.count) {
                [self resolveFantoms];
            }
        }
    }
    
}

+ (void)stopDefantomizing {
    
    STMCoreObjectsController *objController = [self sharedController];
    objController.isDefantomizingProcessRunning = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_FINISH
                                                        object:objController
                                                      userInfo:nil];

    [objController.fantomsArray removeAllObjects];
    [objController.notFoundFantomsArray removeAllObjects];
    [objController.fantomsPendingArray removeAllObjects];

}

*/

#warning need to do with persister
+ (NSFetchRequest *)isFantomFetchRequestForEntityName:(NSString *)entityName {
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id"
                                                                  ascending:YES
                                                                   selector:@selector(compare:)]];
        request.predicate = [NSPredicate predicateWithFormat:@"isFantom == YES && xid != nil"];
        
        return request;

    } else {
        
        return nil;
        
    }
    
}


#pragma mark - subscribe entities from WKWebView

+ (BOOL)subscribeViewController:(UIViewController <STMEntitiesSubscribable> *)vc toEntities:(NSArray *)entities error:(NSError **)error {
    
    BOOL result = YES;
    NSString *errorMessage;
    NSMutableArray *entitiesToSubscribe = @[].mutableCopy;
    
    for (id item in entities) {
        
        if ([item isKindOfClass:[NSString class]]) {
            
            NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, item];
            
            if ([[self localDataModelEntityNames] containsObject:entityName]) {
            
                [entitiesToSubscribe addObject:entityName];
                
            } else {
                
                errorMessage = [NSString stringWithFormat:@"entity name %@ is not in local data model", entityName];
                result = NO;
                break;
                
            }
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"entities array item %@ is not a NSString", item];
            result = NO;
            break;
            
        }
        
    }
    
    if (result) {

        NSLog(@"subscribeViewController: %@ toEntities: %@", vc, entitiesToSubscribe);

        [self flushSubscribedViewController:vc];

        for (NSString *entityName in entitiesToSubscribe) {
            
            NSArray *vcArray = [self sharedController].entitiesToSubscribe[entityName];
            
            if (vcArray) {
                if (![vcArray containsObject:vc]) {
                    vcArray = [vcArray arrayByAddingObject:vc];
                }
            } else {
                vcArray = @[vc];
            }
            
            [self sharedController].entitiesToSubscribe[entityName] = vcArray;
            
        }
        
    } else {
        
        [STMFunctions error:error withMessage:errorMessage];

    }
    
    return result;
    
}

+ (void)flushSubscribedViewController:(UIViewController <STMEntitiesSubscribable> *)vc {
    
    for (NSString *entityName in [self sharedController].entitiesToSubscribe.allKeys) {
        
        NSMutableArray *vcArray = [self sharedController].entitiesToSubscribe[entityName].mutableCopy;
        
        [vcArray removeObject:vc];
        
        [self sharedController].entitiesToSubscribe[entityName] = vcArray;

    }
    
}

+ (void)sendSubscribedBunchOfObjects:(NSArray *)objectArray entityName:(NSString *)entityName {

    NSArray <UIViewController <STMEntitiesSubscribable> *> *vcArray = [self sharedController].entitiesToSubscribe[entityName];

    if (vcArray.count > 0) {
        
        entityName = [STMFunctions removePrefixFromEntityName:entityName];

        NSMutableArray *resultArray = @[].mutableCopy;

        for (STMDatum *object in objectArray) {
            
            if (object.xid) {
                
                NSDictionary *subscribeDic = @{@"entity"    : entityName,
                                               @"xid"       : [STMFunctions UUIDStringFromUUIDData:(NSData *)object.xid],
                                               @"data"      : [self dictionaryForJSWithObject:object]};
                
                [resultArray addObject:subscribeDic];
                
            }
            
        }
        
        for (UIViewController <STMEntitiesSubscribable> *vc in vcArray) {
            [vc subscribedObjectsArrayWasReceived:resultArray];
        }

    }
    
}

+ (void)unsubscribeViewController:(UIViewController <STMEntitiesSubscribable> *)vc {
    
    NSLog(@"unsubscribeViewController: %@", vc);
    [self flushSubscribedViewController:vc];
    
}


#pragma mark - destroy objects from WKWebView

+ (AnyPromise *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage{

    NSError* error;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [STMFunctions error:&error withMessage:@"message.body is not a NSDictionary class"];
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }
    
    NSDictionary *parameters = scriptMessage.body;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if (![[self localDataModelEntityNames] containsObject:entityName]) {
        
        [STMFunctions error:&error withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }
    
    NSString *xidString = parameters[@"id"];
    
    if (!xidString) {
        
        [STMFunctions error:&error withMessage:@"empty xid"];
        
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];

    }
    
    return [[self persistenceDelegate] destroy:entityName identifier:xidString options:nil].then(^(NSNumber *result){
        return @[@{@"objectXid":xidString}];
    });
    
}


#pragma mark - update objects from WKWebView

+ (void)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage
                 withCompletionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler {
    
    NSError *resultError = nil;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [STMFunctions error:&resultError withMessage:@"message.body is not a NSDictionary class"];
        completionHandler(NO, nil, resultError);
        return;
        
    }

    NSDictionary *parameters = scriptMessage.body;
    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if (![[self localDataModelEntityNames] containsObject:entityName]) {
        
        [STMFunctions error:&resultError withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        completionHandler(NO, nil, resultError);
        return;
        
    }
    
    id parametersData = parameters[@"data"];
    
    if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE]) {
        
        if (![parametersData isKindOfClass:[NSDictionary class]]) {
            
            [STMFunctions error:&resultError withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSDictionary class", scriptMessage.name]];
            completionHandler(NO, nil, resultError);
            return;
            
        } else {
            
            parametersData = @[parametersData];
            
        }
        
    } else if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE_ALL]) {
        
        if (![parametersData isKindOfClass:[NSArray <NSDictionary *> class]]) {
            
            [STMFunctions error:&resultError withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSArray<NSDictionary> class", scriptMessage.name]];
            completionHandler(NO, nil, resultError);
            return;
            
        }
        
    } else {

        [STMFunctions error:&resultError withMessage:[NSString stringWithFormat:@"unknown update message name: %@", scriptMessage.name]];
        completionHandler(NO, nil, resultError);
        return;

    }
    
    [self handleUpdateMessageData:parametersData
                       entityName:entityName
                completionHandler:completionHandler];
    
}

+ (void)handleUpdateMessageData:(NSArray *)data entityName:(NSString *)entityName completionHandler:(void (^)(BOOL success, NSArray *updatedObjects, NSError *error))completionHandler{
    
    NSError *localError = nil;
    
    NSArray *results = [self.persistenceDelegate mergeManySync:entityName attributeArray:data options:nil error:&localError];

    if (localError) {
        
        completionHandler(NO, nil, localError);
        
    } else {

        // Assuming there's no CoreData
        completionHandler(YES, results, localError);

    }

}

+ (void)updateObjectWithData:(NSDictionary *)objectData entityName:(NSString *)entityName error:(NSError **)error {
    
    NSString *xidString = objectData[@"id"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xidString];

    STMDatum *object = (STMDatum *)[self objectForXid:xidData entityName:entityName];
    
    if (!object) object = (STMDatum *)[self newObjectForEntityName:entityName andXid:xidData isFantom:NO];
    object.isFantom = @(NO);
    
//    if ([object.entity.propertiesByName objectForKey:@"deviceAts"]) {
//        NSLog(@"--------------- object ot update %@", [object valueForKey:@"deviceAts"]);
//    }

    [self processingKeysForUpdatingObject:object withObjectData:objectData error:error];

//    return (*error) ? NO : YES;
//    return (*error) ? nil : [self dictionaryForJSWithObject:object];
    
}

+ (BOOL)processingKeysForUpdatingObject:(STMDatum *)object withObjectData:(NSDictionary *)objectData error:(NSError **)error {
    
    objectData = [self normalizeObjectData:objectData forObject:object error:error];
    
    if (*error) return NO;
    
    NSString *entityName = object.entity.name;
    
    NSSet *ownKeys = [self ownObjectKeysForEntityName:entityName];
    
    for (NSString *key in ownKeys) {
        
        id value = objectData[key];
        
        if (value && ![value isKindOfClass:[NSNull class]]) {
            
            [object setValue:value forKey:key];
            
        } else {
            
            if (![key isEqualToString:@"deviceAts"]) {
                [object setValue:nil forKey:key];
            }

        }
        
    }
    
    NSDictionary *ownRelationships = [self.persistenceDelegate toOneRelationshipsForEntityName:entityName];
    
    for (NSString *key in ownRelationships.allKeys) {
        
        NSString *dicKey = [key stringByAppendingString:RELATIONSHIP_SUFFIX];
        NSString *xidString = objectData[dicKey];

        if (xidString) {
            
            NSString *destinationEntityName = ownRelationships[key];
            
            NSManagedObject *destinationObject = [self objectFindOrCreateForEntityName:destinationEntityName andXidString:xidString];
            
            if (![[object valueForKey:key] isEqual:destinationObject]) {
                
                BOOL waitingForSync = [self isWaitingToSyncForObject:destinationObject];
                
                [object setValue:destinationObject forKey:key];
                
                if (!waitingForSync) {
                    
                    [destinationObject addObserver:[self sharedController]
                                        forKeyPath:@"deviceTs"
                                           options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
                                           context:nil];
                    
                }
                
            }
            
        } else {
            
            NSManagedObject *destinationObject = [object valueForKey:key];
            
            if (destinationObject) {
                
                BOOL waitingForSync = [self isWaitingToSyncForObject:destinationObject];
                
                [object setValue:nil forKey:key];
                
                if (!waitingForSync) {
                    
                    [destinationObject addObserver:[self sharedController]
                                        forKeyPath:@"deviceTs"
                                           options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
                                           context:nil];
                    
                }
                
            }

        }
        
    }
    
    return (error == nil);
    
}

+ (NSDictionary *)normalizeObjectData:(NSDictionary *)objectData forObject:(STMDatum *)object error:(NSError **)error {
    
    NSString *errorMessage = nil;
    
    NSMutableDictionary *resultDic = @{}.mutableCopy;
    
    NSString *entityName = object.entity.name;
    
    NSSet *ownKeys = [self ownObjectKeysForEntityName:entityName];
    
    for (NSString *key in ownKeys) {
        
        id value = objectData[key];
        
        if (value && ![value isKindOfClass:[NSNull class]]) {
            
            value = [self normalizeValue:value forKey:key updatingObject:object];
            
            if (value) resultDic[key] =  value;
            
        }
        
    }
    
    NSDictionary *ownRelationships = [self.persistenceDelegate toOneRelationshipsForEntityName:entityName];
    
    for (NSString *key in ownRelationships.allKeys) {
    
        NSString *dicKey = [key stringByAppendingString:RELATIONSHIP_SUFFIX];
        
        id value = objectData[dicKey];
        
        if (value && [value isKindOfClass:[NSString class]]) {
            resultDic[dicKey] = value;
        }
        
    }
    
    if (errorMessage) {
        
        [STMFunctions error:error withMessage:errorMessage];
        return nil;
        
    } else {
        
        return resultDic;
        
    }

}

+ (id)normalizeValue:(id)value forKey:(NSString *)key updatingObject:(STMDatum *)object {
    
    NSString *valueClassName = object.entity.attributesByName[key].attributeValueClassName;
    Class valueClass = NSClassFromString(valueClassName);
    NSAttributeType attributeType = object.entity.attributesByName[key].attributeType;
    
    if ([valueClass isSubclassOfClass:[NSNumber class]]) {
        
        if ([value isKindOfClass:[NSString class]]) {
            
            NSString *stringValue = (NSString *)value;
            
            switch (attributeType) {
                case NSInteger16AttributeType:
                case NSInteger32AttributeType:
                case NSInteger64AttributeType: {
                    value = @(stringValue.integerValue);
                    break;
                }
                case NSDecimalAttributeType: {
                    value = [NSDecimalNumber decimalNumberWithString:stringValue];
                    break;
                }
                case NSDoubleAttributeType: {
                    value = @(stringValue.doubleValue);
                    break;
                }
                case NSFloatAttributeType: {
                    value = @(stringValue.floatValue);
                    break;
                }
                case NSBooleanAttributeType: {
                    value = @(stringValue.boolValue);
                    break;
                }
                default: {
                    return nil;
                }
            }
            
        } else if (![value isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        
    } else if ([valueClass isSubclassOfClass:[NSString class]]) {

        if (![value isKindOfClass:[NSString class]]) {

            if ([value respondsToSelector:@selector(stringValue)]) {
                value = (NSString *)[value stringValue];
            } else {
                return nil;
            }

        }
        
    } else {
        
        if (![value isKindOfClass:[NSString class]]) return nil;
        
        if ([valueClass isSubclassOfClass:[NSDate class]]) {
            
            value = [STMFunctions dateFromString:value];
            
        } else if ([valueClass isSubclassOfClass:[NSData class]]) {
            
            if ([key.lowercaseString hasSuffix:@"uuid"] || [key.lowercaseString hasSuffix:@"xid"]) {
                value = [STMFunctions xidDataFromXidString:value];
            } else {
                value = [STMFunctions dataFromString:value];
            }
            
        }

    }
    
    return value;
    
}

#pragma mark - find objects for WKWebView

+ (AnyPromise *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage{
    
    NSError* error = nil;
    
    NSArray *result = nil;

    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [STMFunctions error:&error withMessage:@"message.body is not a NSDictionary class"];
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
        
    }

    NSDictionary *parameters = scriptMessage.body;
    
    if ([scriptMessage.name isEqualToString:WK_MESSAGE_FIND]) {
        result = [self findObjectInCacheWithParameters:parameters error:&error];
        if (error) {
            return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
                resolve(error);
            }];
        };
        if (result) {
            return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
                resolve(result);
            }];
            
        }

    }
    
    NSLog(@"find %@", @([NSDate timeIntervalSinceReferenceDate]));

//    NSLog(@"find predicate created %@", @([NSDate timeIntervalSinceReferenceDate]));

    if (error) {
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
            resolve(error);
        }];
    }

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    NSDictionary *options = parameters[@"options"];
    
    NSPredicate *predicate = [STMScriptMessagesController predicateForScriptMessage:scriptMessage error:&error];
    
    return [[self persistenceDelegate] findAll:entityName predicate:predicate options:options];

}

#warning needs to be removed
+ (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    return [STMFunctions error:error withMessage:errorMessage];

}

+ (NSArray *)findObjectInCacheWithParameters:(NSDictionary *)parameters error:(NSError **)error {
    
    NSString *errorMessage = nil;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSString *xidString = parameters[@"id"];
        
        if (xidString) {
            
            NSDictionary* object = [[self persistenceDelegate] findSync:entityName
                                                             identifier:xidString
                                                                options:nil
                                                                  error:error];
            
            if (object) {

                if (object[@"isFantom"] != [NSNull null] && [object[@"isFantom"] boolValue]) {
                    errorMessage = [NSString stringWithFormat:@"object with xid %@ and entity name %@ is fantom", xidString, entityName];
                } else {
#warning - replace it with arrayForJSWithObjectsDics ?
                    return @[object];
                }
                
            } else {
                errorMessage = [NSString stringWithFormat:@"no object with xid %@ and entity name %@", xidString, entityName];
            }
            
        } else {
            errorMessage = @"empty xid";
        }
        
    } else {
        errorMessage = [entityName stringByAppendingString:@": not found in data model"];
    }

    if (errorMessage) [STMFunctions error:error withMessage:errorMessage];

    return nil;

}


#pragma mark - generate arrayForJS

+ (NSArray <NSDictionary *> *)arrayForJSWithObjectsDics:(NSArray <NSDictionary *> *)objectsDics entityName:(NSString *)entityName {
    
    NSMutableArray *dataArray = @[].mutableCopy;

    NSArray *ownKeys = [self ownObjectKeysForEntityName:entityName].allObjects;
    ownKeys = [ownKeys arrayByAddingObjectsFromArray:@[/*@"deviceTs", */@"deviceCts"]];

    NSArray *ownRelationships = [self.persistenceDelegate toOneRelationshipsForEntityName:entityName].allKeys;
    
    [objectsDics enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSDictionary *propertiesDictionary = [self dictionaryForJSWithObjectDic:obj
                                                                        ownKeys:ownKeys
                                                               ownRelationships:ownRelationships];
        [dataArray addObject:propertiesDictionary];

    }];
    
//    NSLog(@"find prepare objectsDics array %@", @([NSDate timeIntervalSinceReferenceDate]));
    
    return dataArray;

}

+ (NSDictionary *)dictionaryForJSWithObjectDic:(NSDictionary *)objectDic ownKeys:(NSArray *)ownKeys ownRelationships:(NSArray *)ownRelationships {
    
    NSUInteger capacity = ownKeys.count + ownRelationships.count + 2;

    NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionaryWithCapacity:capacity];
    
    if (objectDic[@"xid"]) {
        propertiesDictionary[@"id"] = [STMFunctions UUIDStringFromUUIDData:(NSData *)objectDic[@"xid"]];
    }

    if (objectDic[@"deviceTs"]) {
        propertiesDictionary[@"ts"] = [STMFunctions stringFromDate:(NSDate *)objectDic[@"deviceTs"]];
    }
    
    for (NSString *key in ownKeys) {
        propertiesDictionary[key] = [self convertValue:objectDic[key] forKey:key];
    }
    
    for (NSString *relationship in ownRelationships) {
        
        NSString *resultKey = [relationship stringByAppendingString:@".xid"];
        NSString *dictKey = [relationship stringByAppendingString:RELATIONSHIP_SUFFIX];
        
        NSData *xidData = objectDic[resultKey];
        
        propertiesDictionary[dictKey] = (xidData.length != 0) ? [STMFunctions UUIDStringFromUUIDData:xidData] : [NSNull null];

    }
    
    return propertiesDictionary;
    
}

+ (id)convertValue:(id)value forKey:(NSString *)key {
    
    if (value) {
        
        if ([value isKindOfClass:[NSDate class]]) {
            
            value = [STMFunctions stringFromDate:value];
            
        } else if ([value isKindOfClass:[NSData class]]) {
            
            if ([key isEqualToString:@"deviceUUID"] || [key hasSuffix:@"Xid"]) {
                
                value = [STMFunctions UUIDStringFromUUIDData:value];
                
            } else if ([key isEqualToString:@"deviceToken"]) {
                
                value = [STMFunctions hexStringFromData:value];
                
            } else {
                
                value = [STMFunctions base64HexStringFromData:value];
                
            }
            
        }
        
        value = [NSString stringWithFormat:@"%@", value];
        
    } else {
        
        value = [NSNull null];
        
    }
    
    return value;

}

#warning - replace it with arrayForJSWithObjectsDics ?
+ (NSArray *)arrayForJSWithObjects:(NSArray <STMDatum *> *)objects {

    NSMutableArray *dataArray = @[].mutableCopy;
    
    [objects enumerateObjectsUsingBlock:^(STMDatum * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {

        NSDictionary *propertiesDictionary = [self dictionaryForJSWithObject:obj];
        [dataArray addObject:propertiesDictionary];

    }];
    
//    for (STMDatum *object in objects) {
//        
//        NSDictionary *propertiesDictionary = [self dictionaryForJSWithObject:object];
//        [dataArray addObject:propertiesDictionary];
//        
//    }
    
//    NSLog(@"find prepare objects array %@", @([NSDate timeIntervalSinceReferenceDate]));

    return dataArray;
    
}

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
    
    ownKeys = [ownKeys arrayByAddingObjectsFromArray:@[/*@"deviceTs", */@"deviceCts"]];
    
    [propertiesDictionary addEntriesFromDictionary:[object propertiesForKeys:ownKeys withNulls:withNulls withBinaryData:withBinaryData]];
    [propertiesDictionary addEntriesFromDictionary:[object relationshipXidsForKeys:ownRelationships withNulls:withNulls]];
    
//    NSLog(@"--------------- updated object %@", propertiesDictionary[@"deviceAts"]);

    return propertiesDictionary;

}

#pragma mark - fetching objects

+ (NSUInteger)numberOfObjectsForEntityNameInCoreData:(NSString *)entityName {

    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
#warning temporary disable count via persistenceDelegate
// old implementation
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        NSError *error;
        NSUInteger result = [[self document].managedObjectContext countForFetchRequest:request error:&error];
        
        return result;

// new implementation
//        NSError *error;
//        
//        return [[self persistenceDelegate] countSync:entityName
//                                           predicate:nil
//                                             options:nil
//                                               error:&error];
        
    } else {
        
        return 0;
        
    }

}

+ (NSUInteger)numberOfFantoms {
    
    NSUInteger resultCount = 0;
    
    for (NSString *entityName in [self localDataModelEntityNames]) {
        
        NSFetchRequest *request = [self isFantomFetchRequestForEntityName:entityName];
        
        if (request) {

        NSUInteger result = [[self document].managedObjectContext countForFetchRequest:request
                                                                                 error:nil];
        
        resultCount += result;

    }
    
    }
    
    return resultCount;

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
