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
#import "STMSocketController.h"
#import "STMScriptMessagesController.h"

#import "STMConstants.h"

#import "STMCoreDataModel.h"

#import "STMCoreNS.h"

//#import "iSistemiumCore-Swift.h"


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

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSArray <UIViewController <STMEntitiesSubscribable> *> *> *entitiesToSubscribe;

@property (nonatomic, strong) NSMutableArray *fantomsArray;
@property (nonatomic, strong) NSData *requestedFantomXid;
@property (nonatomic, strong) NSMutableArray *notFoundFantomsArray;
@property (nonatomic, strong) NSMutableArray *flushDeclinedObjectsArray;


@end


@implementation STMCoreObjectsController

- (NSMutableArray *)fantomsArray {
    
    if (!_fantomsArray) {
        _fantomsArray = @[].mutableCopy;
    }
    return _fantomsArray;
    
}

- (NSMutableArray *)notFoundFantomsArray {
    
    if (!_notFoundFantomsArray) {
        _notFoundFantomsArray = @[].mutableCopy;
    }
    return _notFoundFantomsArray;
    
}

- (NSMutableArray *)flushDeclinedObjectsArray {
    
    if (!_flushDeclinedObjectsArray) {
        _flushDeclinedObjectsArray = @[].mutableCopy;
    }
    return _flushDeclinedObjectsArray;
    
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
               name:@"documentSavedSuccessfully"
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
    
    if (roleName) {
        
        [self setRelationshipsFromArray:array withCompletionHandler:^(BOOL success) {
            completionHandler(success);
        }];
        
    } else {
        
        [self insertObjectsFromArray:array withEntityName:entityName withCompletionHandler:^(BOOL success) {
            completionHandler(success);
        }];
        
    }
    
    [[self document] saveDocument:^(BOOL success) {
        
    }];

}

+ (void)insertObjectsFromArray:(NSArray *)array withEntityName:(NSString *)entityName withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    __block BOOL result = YES;
    
    for (NSDictionary *datum in array) {
        
        [self insertObjectFromDictionary:datum withEntityName:entityName withCompletionHandler:^(BOOL success) {
            
            result &= success;
            
        }];
        
    }
    
    completionHandler(result);

}

+ (void)insertObjectFromDictionary:(NSDictionary *)dictionary withEntityName:(NSString *)entityName withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        NSString *xidString = dictionary[@"id"];
        NSData *xidData = [STMFunctions xidDataFromXidString:xidString];
        
        STMDatum *object = nil;
        
        if ([entityName isEqualToString:NSStringFromClass([STMSetting class])]) {
            
            object = [[[self session] settingsController] settingForDictionary:dictionary];
            
        } else if ([entityName isEqualToString:NSStringFromClass([STMEntity class])]) {
            
            NSString *internalName = dictionary[@"name"];
            object = [STMEntityController entityWithName:internalName];
            
        }
        
        if (!object && xidString) object = [self objectForEntityName:entityName andXidString:xidString];
        
        STMRecordStatus *recordStatus = [STMRecordStatusController existingRecordStatusForXid:xidData];
        
        if (!recordStatus.isRemoved.boolValue) {
        
            if (!object) object = [self newObjectForEntityName:entityName];

            if (![self isWaitingToSyncForObject:object]) {

                [object setValue:@NO forKey:@"isFantom"];
                [self processingOfObject:object withEntityName:entityName fillWithValues:dictionary];

            }
            
        } else {
            
            if (object) {

                NSLog(@"object %@ with xid %@ have recordStatus.isRemoved == YES", entityName, xidString);
                [self removeIsRemovedRecordStatusAffectedObject:object];
                
            }

        }
        
        completionHandler(YES);
        
    } else {
        
        NSLog(@"dataModel have no object's entity with name %@", entityName);
        
        completionHandler(NO);
        
    }

}

+ (void)processingOfObject:(NSManagedObject *)object withEntityName:(NSString *)entityName fillWithValues:(NSDictionary *)properties {
    
    NSSet *ownObjectKeys = [self ownObjectKeysForEntityName:entityName];
    ownObjectKeys = [ownObjectKeys setByAddingObject:@"deviceCts"];
    
    STMEntityDescription *currentEntity = (STMEntityDescription *)[object entity];
    NSDictionary *entityAttributes = [currentEntity attributesByName];
    
    for (NSString *key in ownObjectKeys) {
        
        id value = properties[key];
        
        value = (![value isKindOfClass:[NSNull class]]) ? [self typeConversionForValue:value key:key entityAttributes:entityAttributes] : nil;

        if (value) {

            [object setValue:value forKey:key];

        } else {
            
            if (![object isKindOfClass:[STMCorePicture class]]) {
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
    
    [object setValue:[NSDate date] forKey:@"lts"];

    [self postprocessingForObject:object withEntityName:entityName];
    
    if ([[self sharedController].entitiesToSubscribe.allKeys containsObject:entityName]) {
        if ([object isKindOfClass:[STMDatum class]]) [self sendSubscribedEntityObject:(STMDatum *)object entityName:entityName];
    }
    
}

+ (void)setObjectData:(NSDictionary *)objectData toObject:(STMDatum *)object {
    
    NSEntityDescription *entity = object.entity;
    NSString *entityName = entity.name;
	
    NSSet *ownObjectKeys = [self ownObjectKeysForEntityName:entityName];
    NSDictionary *ownObjectRelationships = [self toOneRelationshipsForEntityName:entityName];

    for (NSString *key in objectData.allKeys) {
        
        if ([ownObjectKeys containsObject:key]) {
            
            id value = objectData[key];
            NSDictionary *entityAttributes = entity.attributesByName;
            
            value = (![value isKindOfClass:[NSNull class]]) ? [STMCoreObjectsController typeConversionForValue:value key:key entityAttributes:entityAttributes] : nil;
            
            [object setValue:value forKey:key];
            
        } else {
        
            NSString *relationshipSuffix = @"Id";
            
            if ([key hasSuffix:relationshipSuffix]) {
                
                NSUInteger toIndex = key.length - relationshipSuffix.length;
                NSString *localKey = [key substringToIndex:toIndex];
            
                if ([ownObjectRelationships.allKeys containsObject:localKey]) {
                    
                    NSString *destinationObjectXid = [objectData[key] isKindOfClass:[NSNull class]] ? nil : objectData[key];

                    NSManagedObject *destinationObject = (destinationObjectXid) ? [self objectForEntityName:ownObjectRelationships[localKey] andXidString:destinationObjectXid] : nil;

                    [object setValue:destinationObject forKey:localKey];
                    
                }

            }
            
        }
        
    }

}

+ (id)typeConversionForValue:(id)value key:(NSString *)key entityAttributes:(NSDictionary *)entityAttributes {
    
    if (!value) return nil;
    
    NSString *valueClassName = [entityAttributes[key] attributeValueClassName];
    
    if ([valueClassName isEqualToString:NSStringFromClass([NSDecimalNumber class])]) {
        
        if (![value isKindOfClass:[NSNumber class]]) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                value = [NSDecimalNumber decimalNumberWithString:value];
                
            } else {
                
                NSLog(@"value %@ is not a number or string, can't convert to decimal number", value);
                value = nil;
                
            }
            
        } else {
            
            value = [NSDecimalNumber decimalNumberWithDecimal:[(NSNumber *)value decimalValue]];
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSDate class])]) {
        
        if (![value isKindOfClass:[NSDate class]]) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                value = [[STMFunctions dateFormatter] dateFromString:value];

            } else {
                
                NSLog(@"value %@ is not a string, can't convert to date", value);
                value = nil;
                
            }
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSNumber class])]) {
        
        if (![value isKindOfClass:[NSNumber class]]) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                value = @([value intValue]);
                
            } else {
                
                NSLog(@"value %@ is not a number or string, can't convert to number", value);
                value = nil;
                
            }
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSData class])]) {
        
        if ([value isKindOfClass:[NSString class]]) {
            
            value = [STMFunctions dataFromString:[value stringByReplacingOccurrencesOfString:@"-" withString:@""]];
            
        } else {
            
            NSLog(@"value %@ is not a string, can't convert to data", value);
            value = nil;
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSString class])]) {
        
        if (![value isKindOfClass:[NSString class]]) {
            
            if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
            
                value = [STMFunctions jsonStringFromObject:value];
                value = [value stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];

            } else if ([value isKindOfClass:[NSObject class]]) {

                value = [value description];

            } else {
                
                NSLog(@"value %@ is not convertable to string", value);
                value = nil;
                
            }
            
        }
        
    }

    return value;
    
}

+ (void)processingOfRelationshipsForObject:(NSManagedObject *)object withEntityName:(NSString *)entityName andValues:(NSDictionary *)properties {
    
    NSDictionary *ownObjectRelationships = [self toOneRelationshipsForEntityName:entityName];
    
    for (NSString *relationship in [ownObjectRelationships allKeys]) {
        
        NSString *relationshipId = [relationship stringByAppendingString:@"Id"];
        
        NSString *destinationObjectXid = [properties[relationshipId] isKindOfClass:[NSNull class]] ? nil : properties[relationshipId];
        
        if (destinationObjectXid) {
            
            NSManagedObject *destinationObject = [self objectForEntityName:ownObjectRelationships[relationship] andXidString:destinationObjectXid];
            
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

+ (void)postprocessingForObject:(NSManagedObject *)object withEntityName:(NSString *)entityName {

    if ([entityName isEqualToString:NSStringFromClass([STMMessage class])]) {
        
        //        [[NSNotificationCenter defaultCenter] postNotificationName:@"gotNewMessage" object:nil];
        
    } else if ([entityName isEqualToString:NSStringFromClass([STMRecordStatus class])]) {
        
        STMRecordStatus *recordStatus = (STMRecordStatus *)object;
        
        STMDatum *affectedObject = [self objectForXid:recordStatus.objectXid];
        
        if (affectedObject) {
            
            if (recordStatus.isRemoved.boolValue) {
                [self removeIsRemovedRecordStatusAffectedObject:affectedObject];
            }
            
        }
        
        if (recordStatus.isTemporary.boolValue) [self removeObject:recordStatus];
        
    } else if ([entityName isEqualToString:NSStringFromClass([STMSetting class])]) {
        
        STMSetting *setting = (STMSetting *)object;
        
        if ([setting.group isEqualToString:@"appSettings"]) {
            [STMClientDataController checkAppVersion];
        }
        
    }

}

+ (void)removeIsRemovedRecordStatusAffectedObject:(STMDatum *)affectedObject {
    
    NSLog(@"object %@ with xid %@ will removed (have recordStatus.isRemoved)", affectedObject.entity.name, affectedObject.xid);
    
    [self removeObject:affectedObject];
    
    if ([affectedObject isKindOfClass:[STMClientEntity class]]) {
        [[self syncer] receiveEntities:@[[(STMClientEntity *)affectedObject name]]];
    }

}


#pragma mark - recieved relationships management

+ (void)setRelationshipsFromArray:(NSArray *)array withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    __block BOOL result = YES;
    
    for (NSDictionary *datum in array) {
        
        [self setRelationshipFromDictionary:datum withCompletionHandler:^(BOOL success) {
            
            result &= success;
            
        }];
        
    }

    completionHandler(result);
    
}

+ (void)setRelationshipFromDictionary:(NSDictionary *)dictionary withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
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
            
            NSManagedObject *ownerObject = [self objectForEntityName:roleOwnerEntityName andXidString:ownerXid];
            NSManagedObject *destinationObject = [self objectForEntityName:destinationEntityName andXidString:destinationXid];
            
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
        
        completionHandler(YES);
        
    } else {
        
        NSLog(@"dataModel have no relationship's entity with name %@", entityName);

        completionHandler(NO);
        
    }
    
}


#pragma mark - info methods

+ (BOOL)isWaitingToSyncForObject:(NSManagedObject *)object {
    
    if (object.entity.name) {
        
        BOOL isInSyncList = [[STMEntityController uploadableEntitiesNames] containsObject:(NSString * _Nonnull)object.entity.name];
        
        NSDate *lts = [object valueForKey:@"lts"];
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

+ (STMDatum *)objectForEntityName:(NSString *)entityName andXidString:(NSString *)xid {
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        NSData *xidData = [STMFunctions xidDataFromXidString:xid];

        STMDatum *object = [self objectForXid:xidData entityName:entityName];
        
        if (object) {
            
//            if (![object.entity.name isEqualToString:entityName]) {
//                
//                NSLog(@"No %@ object with xid %@, %@ object fetched instead", entityName, xid, object.entity.name);
//                object = nil;
//                
//            }
            
        } else {
            
            object = [self newObjectForEntityName:entityName andXid:xidData];
        
        }
        
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
    
    NSMutableDictionary *entitiesOwnRelationships = [self sharedController].entitiesOwnRelationships;
    NSDictionary *objectRelationships = entitiesOwnRelationships[entityName];
    
    if (!objectRelationships) {

        objectRelationships = [self objectRelationshipsForEntityName:entityName isToMany:nil];
        entitiesOwnRelationships[entityName] = objectRelationships;
        
    }
    
    return objectRelationships;
    
}

+ (NSDictionary *)toOneRelationshipsForEntityName:(NSString *)entityName {
    
    NSMutableDictionary *entitiesToOneRelationships = [self sharedController].entitiesToOneRelationships;
    NSDictionary *objectRelationships = entitiesToOneRelationships[entityName];
    
    if (!objectRelationships) {

        objectRelationships = [self objectRelationshipsForEntityName:entityName isToMany:@(NO)];
        entitiesToOneRelationships[entityName] = objectRelationships;
        
    }

    return objectRelationships;

}

+ (NSDictionary *)toManyRelationshipsForEntityName:(NSString *)entityName {
    
    NSMutableDictionary *entitiesToManyRelationships = [self sharedController].entitiesToManyRelationships;
    NSDictionary *objectRelationships = entitiesToManyRelationships[entityName];
    
    if (!objectRelationships) {
        
        objectRelationships = [self objectRelationshipsForEntityName:entityName isToMany:@(YES)];
        entitiesToManyRelationships[entityName] = objectRelationships;
        
    }
    
    return objectRelationships;

}

+ (NSDictionary *)objectRelationshipsForEntityName:(NSString *)entityName isToMany:(NSNumber *)isToMany {
    
    STMEntityDescription *objectEntity = [STMEntityDescription entityForName:entityName
                                                      inManagedObjectContext:[self document].managedObjectContext];
    
    NSSet *coreRelationshipNames = [NSSet setWithArray:[self coreEntityRelationships]];
    
    NSMutableSet *objectRelationshipNames = [NSMutableSet setWithArray:objectEntity.relationshipsByName.allKeys];
    
    [objectRelationshipNames minusSet:coreRelationshipNames];
    
    NSMutableDictionary *objectRelationships = [NSMutableDictionary dictionary];
    
    for (NSString *relationshipName in objectRelationshipNames) {
        
        NSRelationshipDescription *relationship = objectEntity.relationshipsByName[relationshipName];
        
        if (isToMany) {
        
            if (relationship.isToMany == isToMany.boolValue) {
                objectRelationships[relationshipName] = relationship.destinationEntity.name;
            }
            
        } else {
            objectRelationships[relationshipName] = relationship.destinationEntity.name;
        }
        
    }
    
    return objectRelationships;

}

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

+ (NSArray *)coreEntityRelationships {
    return [self sharedController].coreEntityRelationships;
}

- (NSArray *)coreEntityRelationships {
    
    if (!_coreEntityRelationships) {
        
        STMEntityDescription *coreEntity = [STMEntityDescription entityForName:NSStringFromClass([STMDatum class])
                                                        inManagedObjectContext:[STMCoreObjectsController document].managedObjectContext];
        
        _coreEntityRelationships = coreEntity.relationshipsByName.allKeys;
        
    }
    return _coreEntityRelationships;
    
}


#pragma mark - flushing

+ (void)removeObject:(STMDatum *)object {
    [self removeObject:object inContext:nil];
}

+ (void)removeObject:(NSManagedObject *)object inContext:(NSManagedObjectContext *)context {
    
    if (object) {
        
        if (!context) context = [self document].managedObjectContext;
        
        [context performBlock:^{
            
            [context deleteObject:object];
            
            [[self document] saveDocument:^(BOOL success) {
            }];
            
        }];

    }
    
}

+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(STMDatum *)object {
    return [self createRecordStatusAndRemoveObject:object withComment:nil];
}

+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(STMDatum *)object withComment:(NSString *)commentText {
    
    STMRecordStatus *recordStatus = [STMRecordStatusController recordStatusForObject:object];
    recordStatus.isRemoved = @YES;
    recordStatus.commentText = commentText;
    
    [self removeObject:object];
    
    return recordStatus;
    
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
    
    for (STMEntity *entity in entitiesWithLifeTime) {
        
        if (entity.name) {
            
            NSString *capFirstLetter = [[entity.name substringToIndex:1] capitalizedString];
            NSString *capEntityName = [entity.name stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
            NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];
         
            entityDic[entityName] = @{@"lifeTime": entity.lifeTime,
                                      @"lifeTimeDateField": entity.lifeTimeDateField ? entity.lifeTimeDateField : @"deviceCts"};
            
        }
        
    }
    
    NSManagedObjectContext *context = [self document].managedObjectContext;
    
    NSMutableSet *flushingSet = [NSMutableSet set];
    
    for (NSString *entityName in entityDic.allKeys) {
        
        double lifeTime = [entityDic[entityName][@"lifeTime"] doubleValue];
        NSDate *terminatorDate = [NSDate dateWithTimeInterval:-lifeTime*3600 sinceDate:startFlushing];
        
        NSString *dateField = entityDic[entityName][@"lifeTimeDateField"];
        NSArray *availableDateKeys = [self attributesForEntityName:entityName withType:NSDateAttributeType];
        dateField = ([availableDateKeys containsObject:dateField]) ? dateField : @"deviceCts";
        
        NSError *error;
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:dateField ascending:YES selector:@selector(compare:)]];
        request.fetchLimit = FLUSH_LIMIT;
        
        NSString *predicateString = [dateField stringByAppendingString:@" < %@"];
        NSPredicate *datePredicate = [NSPredicate predicateWithFormat:predicateString, terminatorDate];
        
        NSPredicate *declinedPredicate = [NSPredicate predicateWithFormat:@"NOT (self IN %@)", sc.flushDeclinedObjectsArray];
        
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[declinedPredicate, datePredicate]];

        NSArray *fetchResult = [context executeFetchRequest:request error:&error];
        
        for (STMDatum *object in fetchResult) [self checkObject:object forAddingToFlushingSet:flushingSet];

    }

    if (flushingSet.count > 0) {

        for (NSManagedObject *object in flushingSet) {
            [self removeObject:object inContext:context];
        }
        
        NSTimeInterval flushingTime = [[NSDate date] timeIntervalSinceDate:startFlushing];
        
        NSString *logMessage = [NSString stringWithFormat:@"flush %lu objects with expired lifetime, %f seconds", (unsigned long)flushingSet.count, flushingTime];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"info"];
        
        sc.isInFlushingProcess = YES;

        [[self document] saveDocument:^(BOOL success) {

        }];
        
        
    } else {
        
        NSLog(@"No objects for flushing");
        sc.flushDeclinedObjectsArray = nil;
        
    }
    
}

+ (void)checkObject:(STMDatum *)object forAddingToFlushingSet:(NSMutableSet *)flushingSet {
    
    if (![self isWaitingToSyncForObject:object]) {
        
        STMCoreObjectsController *sc = [self sharedController];

        BOOL okToFlush = YES;
        
        NSDictionary *relsByName = object.entity.relationshipsByName;
        
        for (NSString *relKey in relsByName.allKeys) {
            
            NSRelationshipDescription *relationship = relsByName[relKey];
            
            if (relationship.inverseRelationship.isToMany) continue;

            id objectPropertyValue = [object valueForKey:relKey];
            
            if (!objectPropertyValue) continue;

            if ([objectPropertyValue respondsToSelector:@selector(count)]) {
                
                okToFlush = ([objectPropertyValue count] == 0);
                
                if (!okToFlush) {
                    
                    NSLog(@"%@ %@ have %@ %@, flush declined", object.entity.name, object.xid, @([objectPropertyValue count]), relKey);
                    [sc.flushDeclinedObjectsArray addObject:object];
                    
                    break;
                    
                }
                
            } else {
                
                okToFlush = NO;
                NSLog(@"%@ %@ have %@, flush declined", object.entity.name, object.xid, relKey);
                [sc.flushDeclinedObjectsArray addObject:object];
                
                break;
                
            }
            
        }
        
        if (okToFlush) [flushingSet addObject:object];
        
    }

}


#pragma mark - finish of recieving objects

+ (void)dataLoadingFinished {
    
    [STMCorePicturesController checkPhotos];
//    [self checkObjectsForFlushing];
    
#ifdef DEBUG
    [self totalNumberOfObjects];
#else

#endif
    
    [self resolveFantoms];

    [[self document] saveDocument:^(BOOL success) {

    }];

}

+ (void)totalNumberOfObjects {

    NSArray *entityNames = [self localDataModelEntityNames];
    
    NSUInteger totalCount = 0;
    
    for (NSString *entityName in entityNames) {
        
        NSUInteger count = [self numberOfObjectsForEntityName:entityName];
        NSLog(@"%@ count %lu", entityName, (unsigned long)count);
        totalCount += count;

    }
    
    NSLog(@"fantoms count %lu", (unsigned long)[self numberOfFantoms]);
    NSLog(@"total count %lu", (unsigned long)totalCount);

}


#pragma mark - resolving fantoms

+ (void)resolveFantoms {
    
    STMCoreObjectsController *objController = [self sharedController];
    
    NSSet *entityNamesWithResolveFantoms = [STMEntityController entityNamesWithResolveFantoms];
    
    for (NSString *entityName in entityNamesWithResolveFantoms) {
        
        NSFetchRequest *request = [self isFantomFetchRequestForEntityName:entityName];
        
        if (request) {

            NSError *error;
            NSArray *results = [[self document].managedObjectContext executeFetchRequest:request error:&error];
            
            if (results.count > 0) {
                
                NSLog(@"%@ %@ fantom(s)", @(results.count), entityName);

                STMEntity *entity = [STMEntityController stcEntities][entityName];

                if (entity.url) {

                    for (STMDatum *fantomObject in results) {
                        
                        if ([self fantomObjectHaveRelationshipObjects:fantomObject]) {
                        
                            if (fantomObject.xid) {
                                
                                NSDictionary *fantomDic = @{@"entityName":entityName, @"xid":fantomObject.xid/*, @"isFantomResolving": @(YES)*/};
                                
                                if (![objController.notFoundFantomsArray containsObject:fantomDic]) {
                                    [objController.fantomsArray addObject:fantomDic];
                                }
                                
                            }

                        } else {
                            
                            NSString *logMessage = [NSString stringWithFormat:@"fantom object %@ %@ have no relationships objects, remove it", fantomObject.entity.name, fantomObject.xid];
                            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"important"];
                            
                            [self removeObject:fantomObject];
                            
                        }
                        
                    }
                    
                } else {
                    NSLog(@"have no url for entity name: %@, fantoms will not to be resolved", entityName);
                }

            }
            
        }
        
    }

    if (objController.fantomsArray.count > 0) {
        
        [self requestFantomObjectWithParameters:objController.fantomsArray.firstObject];
        
    } else {
        
        [objController.notFoundFantomsArray removeAllObjects];
        [[self document] saveDocument:^(BOOL success) {
            
        }];
        
    }

}

+ (BOOL)fantomObjectHaveRelationshipObjects:(STMDatum *)fantomObject {

    BOOL result = NO;
    
    NSString *entityName = fantomObject.entity.name;
    
    NSDictionary *toOneRelationships = [self toOneRelationshipsForEntityName:entityName];
    
    for (NSString *toOneKey in toOneRelationships.allKeys) {
        
        if ([fantomObject valueForKey:toOneKey]) {
            
            result = YES;
            break;
            
        }
        
    }
    
    if (result) return result;
    
    NSDictionary *toManyRelationships = [self toManyRelationshipsForEntityName:entityName];
    
    for (NSString *toManyKey in toManyRelationships.allKeys) {
        
        NSSet *relObjects = [fantomObject valueForKey:toManyKey];
        
        if (relObjects.count > 0) {

            result = YES;
            break;
            
        }
        
    }
    
    return result;
    
}

+ (void)requestFantomObjectWithParameters:(NSDictionary *)parameters {
    
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        
        NSString *entityName = parameters[@"entityName"];
        
        if (![entityName hasPrefix:ISISTEMIUM_PREFIX]) {
            entityName = [ISISTEMIUM_PREFIX stringByAppendingString:entityName];
        }
        
        __block STMEntity *entity = [STMEntityController stcEntities][entityName];
        
        if (!entity.url) {
            
            NSString *errorMessage = [NSString stringWithFormat:@"no url for entity %@", entityName];
            
            [self requestFantomObjectErrorMessage:errorMessage
                                       parameters:parameters];
            return;
            
        }
        
        NSString *resource = entity.url;
        
        NSString *xidString = nil;
        BOOL isEmptyXid = NO;
        id xidParameter = parameters[@"xid"];
        
        NSData *xid = (NSData *)xidParameter;
        
        if (!xid || xid.length == 0) {
            isEmptyXid = YES;
        } else {
            xidString = [STMFunctions UUIDStringFromUUIDData:xid];
        }
        
        if (isEmptyXid) {
            
            NSString *errorMessage = [NSString stringWithFormat:@"no xid in request parameters %@", parameters];
            
            [self requestFantomObjectErrorMessage:errorMessage
                                       parameters:parameters];
            return;

        }
        
        [self sharedController].requestedFantomXid = xid;
        
        [STMSocketController sendFantomFindEventToResource:resource
                                                   withXid:xidString
                                                andTimeout:[[self syncer] timeout]];

    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"parameters is not an NSDictionary class: %@", parameters];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
        
    }

}

+ (void)requestFantomObjectErrorMessage:(NSString *)errorMessage parameters:(NSDictionary *)parameters {

    [self didFinishResolveFantom:parameters successfully:NO];
    NSLog(@"%@", errorMessage);

}

+ (NSData *)requestedFantomXid {
    return [self sharedController].requestedFantomXid;
}

+ (void)didFinishResolveFantom:(NSDictionary *)fantomDic successfully:(BOOL)successfully {
    
    STMCoreObjectsController *objController = [self sharedController];
    
    objController.requestedFantomXid = nil;
    
    if (!fantomDic) {
        
        NSString *logMessage = @"fantomDic is nil in didFinishResolveFantom:";
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
        fantomDic = objController.fantomsArray.firstObject;
        
    }
    
    [objController.fantomsArray removeObject:fantomDic];
    
    NSString *entityName = fantomDic[@"entityName"];
    NSData *fantomXid = fantomDic[@"xid"];

    if (successfully) {
        NSLog(@"success defantomize %@ %@", entityName, fantomXid);
    } else {
        [objController.notFoundFantomsArray addObject:fantomDic];
        NSLog(@"bad luck defantomize %@ %@", entityName, fantomXid);
    }
    
    if (objController.fantomsArray.count > 0) {
        [self requestFantomObjectWithParameters:objController.fantomsArray.firstObject];
    } else {
        [self resolveFantoms];
    }
    
}

+ (void)stopDefantomizing {
    
    STMCoreObjectsController *objController = [self sharedController];
    
    objController.fantomsArray = nil;
    objController.notFoundFantomsArray = nil;

}

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
        
        [self error:error withMessage:errorMessage];

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

+ (void)sendSubscribedEntityObject:(STMDatum *)object entityName:(NSString *)entityName {
    
    NSArray <UIViewController <STMEntitiesSubscribable> *> *vcArray = [self sharedController].entitiesToSubscribe[entityName];
    
    for (UIViewController <STMEntitiesSubscribable> *vc in vcArray) {
    
        entityName = ([entityName hasPrefix:ISISTEMIUM_PREFIX]) ? [entityName substringFromIndex:ISISTEMIUM_PREFIX.length] : entityName;
    
        if (object.xid) {
            
            NSDictionary *subscribeDic = @{@"entity"    : entityName,
                                           @"xid"       : [STMFunctions UUIDStringFromUUIDData:(NSData *)object.xid],
                                           @"data"      : [self dictionaryForJSWithObject:object]};
            
            [vc subscribedEntitiesObjectWasReceived:subscribeDic];

        }

    }
    
}


#pragma mark - destroy objects from WKWebView

+ (NSArray *)destroyObjectFromScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error {

    NSString *errorMessage = nil;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [self error:error withMessage:@"message.body is not a NSDictionary class"];
        return nil;
        
    }
    
    NSDictionary *parameters = scriptMessage.body;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if (![[self localDataModelEntityNames] containsObject:entityName]) {
        
        [self error:error withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        return nil;
        
    }
    
    NSString *xidString = parameters[@"id"];
    
    if (!xidString) {
        
        [self error:error withMessage:@"empty xid"];
        return nil;

    }
            
    NSData *xid = [STMFunctions xidDataFromXidString:xidString];
    
    STMDatum *object = (STMDatum *)[self objectForXid:xid entityName:entityName];
    
    if (object) {
        
            STMRecordStatus *recordStatus = [self createRecordStatusAndRemoveObject:object];
            return [self arrayForJSWithObjects:@[recordStatus]];
            
    } else {
        
        errorMessage = [NSString stringWithFormat:@"no object for destroy with xid %@ and entity name %@", xidString, entityName];
        [self error:error withMessage:errorMessage];
        return nil;

    }
    
}


#pragma mark - update objects from WKWebView

+ (NSArray *)updateObjectsFromScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error {
    
    NSMutableArray *result = @[].mutableCopy;
    
    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [self error:error withMessage:@"message.body is not a NSDictionary class"];
        return nil;
        
    }
    
    NSDictionary *parameters = scriptMessage.body;
    
    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if (![[self localDataModelEntityNames] containsObject:entityName]) {
        
        [self error:error withMessage:[entityName stringByAppendingString:@": not found in data model"]];
        return nil;

    }

    if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE]) {
        
        if (![parameters[@"data"] isKindOfClass:[NSDictionary class]]) {
            
            [self error:error withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSDictionary class", scriptMessage.name]];
            return nil;
            
        } else {
            
            NSDictionary *updatedData = [self updateObjectWithData:parameters[@"data"] entityName:entityName error:error];
            if (*error) return nil;
            
            [result addObject:updatedData];

        }

    } else if ([scriptMessage.name isEqualToString:WK_MESSAGE_UPDATE_ALL]) {
        
        if (![parameters[@"data"] isKindOfClass:[NSArray <NSDictionary *> class]]) {
            
            [self error:error withMessage:[NSString stringWithFormat:@"message.body.data for %@ message is not a NSArray[NSDictionary] class", scriptMessage.name]];
            return nil;
            
        } else {
            
            NSArray *data = parameters[@"data"];
            
            NSString *errorMessage = nil;
            
            for (NSDictionary *objectData in data) {
                
                NSError *localError = nil;
                
                NSDictionary *updatedData = [self updateObjectWithData:objectData entityName:entityName error:&localError];
                
                if (updatedData) {
                    [result addObject:updatedData];
                } else {
                    errorMessage = (errorMessage) ? [errorMessage stringByAppendingString:localError.localizedDescription] : localError.localizedDescription;
                }
                
            }
            
            if (errorMessage) [self error:error withMessage:errorMessage];
            
        }
        
    }
    
    [[self document] saveDocument:^(BOOL success) {
        
    }];
    
    return result;
    
}

+ (NSDictionary *)updateObjectWithData:(NSDictionary *)objectData entityName:(NSString *)entityName error:(NSError **)error {
    
    NSString *xidString = objectData[@"id"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xidString];

    STMDatum *object = (STMDatum *)[self objectForXid:xidData entityName:entityName];
    
    if (!object) object = (STMDatum *)[self newObjectForEntityName:entityName andXid:xidData isFantom:NO];
    object.isFantom = @(NO);

    [self processingKeysForUpdatingObject:object withObjectData:objectData error:error];

    return (*error) ? nil : [self dictionaryForJSWithObject:object];
    
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
            [object setValue:nil forKey:key];
        }
        
    }
    
    NSDictionary *ownRelationships = [self toOneRelationshipsForEntityName:entityName];
    
    for (NSString *key in ownRelationships.allKeys) {
        
        NSString *dicKey = [key stringByAppendingString:@"Id"];
        NSString *xidString = objectData[dicKey];

        if (xidString) {
            
            NSString *destinationEntityName = ownRelationships[key];
            
            NSManagedObject *destinationObject = [self objectForEntityName:destinationEntityName andXidString:xidString];
            
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
            
            if (value) {
                
                resultDic[key] =  value;
                
//            } else {
//                
//                NSString *message = [NSString stringWithFormat:@"%@ object %@ can't update value %@ for key %@\n", entityName, object.xid, value, key];
//                
//                errorMessage = (errorMessage) ? [errorMessage stringByAppendingString:message] : message;
//                
//                continue;
                
            }
            
        }
        
    }
    
    NSDictionary *ownRelationships = [self toOneRelationshipsForEntityName:entityName];
    
    for (NSString *key in ownRelationships.allKeys) {
    
        NSString *dicKey = [key stringByAppendingString:@"Id"];
        
        id value = objectData[dicKey];
        
        if (value) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
//                NSString *xidString = (NSString *)value;
//                
//                NSString *destinationEntityName = ownRelationships[key];
//                
//                NSManagedObject *destinationObject = [self objectForEntityName:destinationEntityName andXidString:xidString];
//                
//                if (![[object valueForKey:key] isEqual:destinationObject]) {
                    resultDic[dicKey] = value;
//                }
                
//            } else {
//                
//                NSString *message = [NSString stringWithFormat:@"%@ object %@ relationship value %@ is not a String for key %@, can't get xid\n", entityName, object.xid, value, key];
//                
//                errorMessage = (errorMessage) ? [errorMessage stringByAppendingString:message] : message;
//                
//                continue;
                
            }
            
        }
        
    }
    
    if (errorMessage) {
        
        [self error:error withMessage:errorMessage];
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
            
            value = [[STMFunctions dateFormatter] dateFromString:value];
            
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

+ (NSArray *)arrayOfObjectsRequestedByScriptMessage:(WKScriptMessage *)scriptMessage error:(NSError **)error {
    
    NSArray *result = nil;

    if (![scriptMessage.body isKindOfClass:[NSDictionary class]]) {
        
        [self error:error withMessage:@"message.body is not a NSDictionary class"];
        return nil;
        
    }

    NSDictionary *parameters = scriptMessage.body;

    if ([scriptMessage.name isEqualToString:WK_MESSAGE_FIND]) {
        
        result = [self findObjectInCacheWithParameters:parameters error:error];

        if (*error) return nil;
        if (result) return result;

    }
    
    NSPredicate *predicate = [STMScriptMessagesController predicateForScriptMessage:scriptMessage error:error];
    
    if (*error) return nil;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    NSDictionary *options = parameters[@"options"];
    NSUInteger pageSize = [options[@"pageSize"] integerValue];
    NSUInteger startPage = [options[@"startPage"] integerValue] - 1;
    NSString *orderBy = options[@"sortBy"];
    if (!orderBy) orderBy = @"id";
    
    NSArray *objectsArray = [self objectsForEntityName:entityName
                                               orderBy:orderBy
                                             ascending:YES
                                            fetchLimit:pageSize
                                           fetchOffset:(pageSize * startPage)
                                           withFantoms:NO
                                             predicate:predicate
                                inManagedObjectContext:[self document].managedObjectContext
                                                 error:error];
    
    if (*error) {
        return nil;
    } else {
        return [self arrayForJSWithObjects:objectsArray];
    }

}

+ (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    if (bundleId && error) *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                        code:1
                                                    userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
    
    return (error == nil);

}

+ (NSArray *)findObjectInCacheWithParameters:(NSDictionary *)parameters error:(NSError **)error {
    
    NSString *errorMessage = nil;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSString *xidString = parameters[@"id"];
        
        if (xidString) {
            
            NSData *xid = [STMFunctions xidDataFromXidString:xidString];
            
            STMDatum *object = (STMDatum *)[self objectForXid:xid entityName:entityName];
            
            if (object) {
                
                if (object.isFantom.boolValue) {
                    errorMessage = [NSString stringWithFormat:@"object with xid %@ and entity name %@ is fantom", xidString, entityName];
                } else {
                    return [self arrayForJSWithObjects:@[object]];
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

    if (errorMessage) [self error:error withMessage:errorMessage];

    return nil;

}

+ (NSArray *)arrayForJSWithObjects:(NSArray <STMDatum *> *)objects {

    NSMutableArray *dataArray = @[].mutableCopy;
    
    for (STMDatum *object in objects) {
        
        NSDictionary *propertiesDictionary = [self dictionaryForJSWithObject:object];
        [dataArray addObject:propertiesDictionary];
        
    }
    
    return dataArray;
    
}

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object {
    return [self dictionaryForJSWithObject:object withNulls:YES];
}

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object withNulls:(BOOL)withNulls {
    return [self dictionaryForJSWithObject:object withNulls:withNulls withBinaryData:YES];
}

+ (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object withNulls:(BOOL)withNulls withBinaryData:(BOOL)withBinaryData {

    NSMutableDictionary *propertiesDictionary = @{}.mutableCopy;
    
    if (object.xid) propertiesDictionary[@"id"] = [STMFunctions UUIDStringFromUUIDData:(NSData *)object.xid];
    if (object.deviceTs) propertiesDictionary[@"ts"] = [[STMFunctions dateFormatter] stringFromDate:(NSDate *)object.deviceTs];
    
    NSArray *ownKeys = [self ownObjectKeysForEntityName:object.entity.name].allObjects;
    NSArray *ownRelationships = [self toOneRelationshipsForEntityName:object.entity.name].allKeys;
    
    ownKeys = [ownKeys arrayByAddingObjectsFromArray:@[/*@"deviceTs", */@"deviceCts"]];
    
    [propertiesDictionary addEntriesFromDictionary:[object propertiesForKeys:ownKeys withNulls:withNulls withBinaryData:withBinaryData]];
    [propertiesDictionary addEntriesFromDictionary:[object relationshipXidsForKeys:ownRelationships withNulls:withNulls]];
    
    return propertiesDictionary;

}

#pragma mark - fetching objects

+ (NSArray *)objectsForEntityName:(NSString *)entityName {

    return [self objectsForEntityName:entityName
                              orderBy:@"id"
                            ascending:YES
                           fetchLimit:0
                          withFantoms:NO
               inManagedObjectContext:[self document].managedObjectContext
                                error:nil];
    
}

+ (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit withFantoms:(BOOL)withFantoms inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {

    return [self objectsForEntityName:entityName
                              orderBy:orderBy
                            ascending:ascending
                           fetchLimit:fetchLimit
                          fetchOffset:0
                          withFantoms:withFantoms
               inManagedObjectContext:context
                                error:error];

}

+ (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {
    
    return [self objectsForEntityName:entityName
                              orderBy:orderBy
                            ascending:ascending
                           fetchLimit:fetchLimit
                          fetchOffset:fetchOffset
                          withFantoms:withFantoms
                            predicate:nil
               inManagedObjectContext:context
                                error:error];

}

+ (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms predicate:(NSPredicate *)predicate inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {
    
    NSString *errorMessage = nil;
    
    context = (context) ? context : [self document].managedObjectContext;
    
    if (context.hasChanges && fetchOffset > 0) {
        
        [[self document] saveDocument:^(BOOL success) {
            
        }];
        
    }
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        STMEntityDescription *entity = [STMEntityDescription entityForName:entityName inManagedObjectContext:context];

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];

        request.fetchLimit = fetchLimit;
        request.fetchOffset = fetchOffset;
        request.predicate = (withFantoms) ? predicate : [STMPredicate predicateWithNoFantomsFromPredicate:predicate];
        
        NSAttributeDescription *orderByAttribute = entity.attributesByName[orderBy];
        BOOL isNSString = [NSClassFromString(orderByAttribute.attributeValueClassName) isKindOfClass:[NSString class]];
        
        SEL sortSelector = isNSString ? @selector(caseInsensitiveCompare:) : @selector(compare:);
        
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:orderBy
                                                         ascending:ascending
                                                          selector:sortSelector];
        
        BOOL afterRequestSort = NO;

        if ([entity.propertiesByName.allKeys containsObject:orderBy]) {
            
            request.sortDescriptors = @[sortDescriptor];
            
        } else if ([NSClassFromString(entity.managedObjectClassName) instancesRespondToSelector:NSSelectorFromString(orderBy)]) {
            
            afterRequestSort = YES;
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"%@: property or method '%@' not found, sort by 'id' instead", entityName, orderBy];
            
            sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id"
                                                           ascending:ascending
                                                            selector:@selector(compare:)];
            request.sortDescriptors = @[sortDescriptor];

        }
        
        NSError *fetchError;
        NSArray *result = [[self document].managedObjectContext executeFetchRequest:request
                                                                              error:&fetchError];
        
        if (result) {
            
            if (afterRequestSort) {
                result = [result sortedArrayUsingDescriptors:@[sortDescriptor]];
            }

            return result;
            
        } else {
            errorMessage = fetchError.localizedDescription;
        }

        
    } else {
        
        errorMessage = [NSString stringWithFormat:@"%@: not found in data model", entityName];
        
    }
    
    if (errorMessage) [self error:error withMessage:errorMessage];
    
    return nil;

}

+ (NSUInteger)numberOfObjectsForEntityName:(NSString *)entityName {

    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        NSError *error;
        NSUInteger result = [[self document].managedObjectContext countForFetchRequest:request error:&error];
        
        return result;
        
    } else {
        
        return 0;
        
    }

}

+ (NSUInteger)numberOfFantoms {
    
    NSUInteger resultCount = 0;
    
    for (NSString *entityName in [self localDataModelEntityNames]) {
        
        NSFetchRequest *request = [self isFantomFetchRequestForEntityName:entityName];
        
        if (request) {

        NSUInteger result = [[self document].managedObjectContext countForFetchRequest:request error:nil];
        
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
        NSUInteger size = [parameters[@"size"] integerValue];
        NSString *orderBy = parameters[@"orderBy"];
        BOOL ascending = [[parameters[@"order"] lowercaseString] isEqualToString:@"asc"];
        
        BOOL sessionIsRunning = (self.session.status == STMSessionRunning);
        if (sessionIsRunning && self.document) {
            
            NSError *fetchError;
            NSArray *objects = [self objectsForEntityName:entityName
                                                  orderBy:orderBy
                                                ascending:ascending
                                               fetchLimit:size
                                              withFantoms:YES
                                   inManagedObjectContext:[self document].managedObjectContext
                                                    error:&fetchError];
            
            if (fetchError) {

                errorMessage = fetchError.localizedDescription;
                
            } else {
                
                NSMutableArray *jsonObjectsArray = [NSMutableArray array];
                
                for (STMDatum *object in objects)
                    [jsonObjectsArray addObject:[STMCoreObjectsController dictionaryForJSWithObject:object]];
                
                return jsonObjectsArray;

            }
            
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
