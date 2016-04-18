//
//  STMCoreObjectsController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 07/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreObjectsController.h"

#import "STMAuthController.h"
#import "STMFunctions.h"
#import "STMSyncer.h"
#import "STMEntityController.h"
#import "STMClientDataController.h"
#import "STMPicturesController.h"
#import "STMRecordStatusController.h"
#import "STMSocketController.h"

#import "STMConstants.h"

#import "STMCoreDataModel.h"

#import "STMNS.h"

#import "iSistemiumCore-Swift.h"


#define FLUSH_LIMIT 17


@interface STMCoreObjectsController()

@property (nonatomic, strong) NSMutableDictionary *timesDic;
@property (nonatomic, strong) NSMutableDictionary *entitiesOwnKeys;
@property (nonatomic, strong) NSMutableDictionary *entitiesOwnRelationships;
@property (nonatomic, strong) NSMutableDictionary *entitiesSingleRelationships;
@property (nonatomic, strong) NSMutableDictionary *objectsCache;
@property (nonatomic, strong) NSArray *localDataModelEntityNames;
@property (nonatomic, strong) NSArray *coreEntityKeys;
@property (nonatomic, strong) NSArray *coreEntityRelationships;
@property (nonatomic) BOOL isInFlushingProcess;

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSArray <UIViewController <STMEntitiesSubscribable> *> *> *entitiesToSubscribe;


@end


@implementation STMCoreObjectsController

- (NSMutableDictionary <NSString *, NSArray <UIViewController <STMEntitiesSubscribable> *> *> *)entitiesToSubscribe {
    
    if (!_entitiesToSubscribe) {
    
        _entitiesToSubscribe = @{}.mutableCopy;
        
    }
    return _entitiesToSubscribe;
    
}

- (NSMutableDictionary *)timesDic {
    
    if (!_timesDic) {
        
        _timesDic = [@{} mutableCopy];
        _timesDic[@"1"] = [@[] mutableCopy];
        _timesDic[@"2"] = [@[] mutableCopy];
        _timesDic[@"3"] = [@[] mutableCopy];
        _timesDic[@"4"] = [@[] mutableCopy];
        _timesDic[@"5"] = [@[] mutableCopy];
        _timesDic[@"6"] = [@[] mutableCopy];
        _timesDic[@"7"] = [@[] mutableCopy];
        _timesDic[@"8"] = [@[] mutableCopy];
        _timesDic[@"9"] = [@[] mutableCopy];
        
    }
    return _timesDic;
    
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

- (NSMutableDictionary *)entitiesSingleRelationships {
    
    if (!_entitiesSingleRelationships) {
        _entitiesSingleRelationships = [@{} mutableCopy];
    }
    return _entitiesSingleRelationships;
    
}

- (NSMutableDictionary *)objectsCache {
    
    if (!_objectsCache) {
        _objectsCache = [@{} mutableCopy];
    }
    return _objectsCache;
    
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
    
    if ([notification.object isKindOfClass:[STMSession class]]) {
        
        STMSession *session = notification.object;
        
        if (![session.status isEqualToString:@"running"]) {
            self.objectsCache = nil;
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

+ (void)processingOfDataArray:(NSArray *)array roleName:(NSString *)roleName withCompletionHandler:(void (^)(BOOL success))completionHandler {

//    NSDate *start = [NSDate date];
//    NSString *startString = [[STMFunctions dateFormatter] stringFromDate:start];
//    NSLog(@"--------------------s %@", startString);
    
    if (roleName) {
        
        [self setRelationshipsFromArray:array withCompletionHandler:^(BOOL success) {
            completionHandler(success);
        }];
        
    } else {
        
        [self insertObjectsFromArray:array withCompletionHandler:^(BOOL success) {
            completionHandler(success);
        }];
        
    }
    
    [[self document] saveDocument:^(BOOL success) {
        
    }];
    
//    NSDate *finish = [NSDate date];
//    NSString *finishString = [[STMFunctions dateFormatter] stringFromDate:finish];
//    NSLog(@"--------------------f %@", finishString);

}

+ (void)insertObjectsFromArray:(NSArray *)array withCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    __block BOOL result = YES;
    
    for (NSDictionary *datum in array) {
        
        [self insertObjectFromDictionary:datum withCompletionHandler:^(BOOL success) {
            
            result &= success;
            
        }];
        
    }

    completionHandler(result);

}

+ (void)insertObjectFromDictionary:(NSDictionary *)dictionary withCompletionHandler:(void (^)(BOOL success))completionHandler {

// time checking
//    NSDate *start = [NSDate date];
// -------------
    
    NSString *name = dictionary[@"name"];
    NSDictionary *properties = dictionary[@"properties"];

    NSArray *nameExplode = [name componentsSeparatedByString:@"."];
    NSString *nameTail = (nameExplode.count > 1) ? nameExplode[1] : name;
    NSString *capEntityName = [nameTail stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[nameTail substringToIndex:1] capitalizedString]];

    NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:capEntityName];
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        NSString *xid = dictionary[@"xid"];
        NSData *xidData = [STMFunctions xidDataFromXidString:xid];
        
        STMRecordStatus *recordStatus = [STMRecordStatusController existingRecordStatusForXid:xidData];
        
        if (![recordStatus.isRemoved boolValue]) {
            
            NSManagedObject *object = nil;
            
            if ([entityName isEqualToString:NSStringFromClass([STMSetting class])]) {
                
                object = [[[self session] settingsController] settingForDictionary:dictionary];
                
            } else if ([entityName isEqualToString:NSStringFromClass([STMEntity class])]) {
                
                NSString *internalName = properties[@"name"];
                object = [STMEntityController entityWithName:internalName];
                
            }

// time checking
//            [[self sharedController].timesDic[@"1"] addObject:@([start timeIntervalSinceNow])];
// -------------
            
            if (!object) {
                object = (xid) ? [self objectForEntityName:entityName andXidString:xid] : [self newObjectForEntityName:entityName];
            }
            
// time checking
//            [[self sharedController].timesDic[@"2"] addObject:@([start timeIntervalSinceNow])];
// -------------
            
            if (![self isWaitingToSyncForObject:object]) {
                
                [object setValue:@NO forKey:@"isFantom"];
                [self processingOfObject:object withEntityName:entityName fillWithValues:properties];
                
            }
            
// time checking
//            [[self sharedController].timesDic[@"3"] addObject:@([start timeIntervalSinceNow])];
// -------------
            
        } else {
            
            NSLog(@"object %@ with xid %@ have recordStatus.isRemoved == YES", entityName, xid);
            
        }
            
        completionHandler(YES);
        
    } else {
        
        NSLog(@"dataModel have no object's entity with name %@", entityName);
        
        completionHandler(NO);
        
    }
    
}

+ (void)processingOfObject:(NSManagedObject *)object withEntityName:(NSString *)entityName fillWithValues:(NSDictionary *)properties {
    
// time checking
//    NSDate *start = [NSDate date];
// -------------
    
    NSSet *ownObjectKeys = [self ownObjectKeysForEntityName:entityName];
    
    STMEntityDescription *currentEntity = (STMEntityDescription *)[object entity];
    NSDictionary *entityAttributes = [currentEntity attributesByName];
    
    for (NSString *key in ownObjectKeys) {
        
        id value = properties[key];
        
        if (value) {
            
            value = [self typeConversionForValue:value key:key entityAttributes:entityAttributes];
            
            [object setValue:value forKey:key];
            
//            if ([key isEqualToString:@"href"]) [STMPicturesController hrefProcessingForObject:object];
            
        } else {
            
            if (![object isKindOfClass:[STMPicture class]]) {
                [object setValue:nil forKey:key];
            }
            
        }
        
    }
    
    [self processingOfRelationshipsForObject:object withEntityName:entityName andValues:properties];
    
    [object setValue:[NSDate date] forKey:@"lts"];

    [self postprocessingForObject:object withEntityName:entityName];

// time checking
//    [[self sharedController].timesDic[@"4"] addObject:@([start timeIntervalSinceNow])];
// -------------
    
    if ([[self sharedController].entitiesToSubscribe.allKeys containsObject:entityName]) {
        if ([object isKindOfClass:[STMDatum class]]) [self sendSubscribedEntityObject:(STMDatum *)object entityName:entityName];
    }
    
}

+ (id)typeConversionForValue:(id)value key:(NSString *)key entityAttributes:(NSDictionary *)entityAttributes {
    
    NSString *valueClassName = [entityAttributes[key] attributeValueClassName];
    
    if ([valueClassName isEqualToString:NSStringFromClass([NSDecimalNumber class])]) {
        
        value = [NSDecimalNumber decimalNumberWithString:value];
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSDate class])]) {
        
        value = [[STMFunctions dateFormatter] dateFromString:value];
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSNumber class])]) {
        
        value = @([value intValue]);
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSData class])]) {
        
        value = [STMFunctions dataFromString:[value stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        
    }

    return value;
    
}

+ (void)processingOfRelationshipsForObject:(NSManagedObject *)object withEntityName:(NSString *)entityName andValues:(NSDictionary *)properties {
    
    NSDictionary *ownObjectRelationships = [self singleRelationshipsForEntityName:entityName];
    
    for (NSString *relationship in [ownObjectRelationships allKeys]) {
        
        if ([properties[relationship] isKindOfClass:[NSDictionary class]]) {
            
            NSDictionary *relationshipDictionary = properties[relationship];
            NSString *destinationObjectXid = relationshipDictionary[@"xid"];
            
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

        } else {
            
            if (properties[relationship]) {
                
                NSString *logMessage = [NSString stringWithFormat:@"not correct %@ relationship dictionary for %@ %@", relationship, entityName, [object valueForKey:@"xid"]];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];

            }
            
        }
        
    }
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

//    if ([[change valueForKey:NSKeyValueChangeOldKey] isKindOfClass:[NSNull class]]) {
//        
//        if ([object isKindOfClass:[NSManagedObject class]]) {
//            
//            NSManagedObjectContext *context = [STMObjectsController document].managedObjectContext;
//            NSManagedObjectContext *parentContext = context.parentContext;
//            
//            CLS_LOG(@"context %@", context);
//            CLS_LOG(@"parentContext %@", parentContext);
//            CLS_LOG(@"object.context %@", [(NSManagedObject *)object managedObjectContext]);
//            CLS_LOG(@"object isDeleted %d", [(NSManagedObject *)object isDeleted]);
//            
//        }
//
//        CLS_LOG(@"applicationState %ld", (long)[UIApplication sharedApplication].applicationState);
//        CLS_LOG(@"object %@", object);
//        CLS_LOG(@"change %@", change);
//        
//    }
    
    [object removeObserver:self forKeyPath:keyPath];
    
    if ([object isKindOfClass:[NSManagedObject class]]) {
        
        id oldValue = [change valueForKey:NSKeyValueChangeOldKey];
        
        if ([oldValue isKindOfClass:[NSDate class]]) {
            
            [(NSManagedObject *)object setValue:oldValue forKey:keyPath];
            
        } else {
            CLS_LOG(@"observeValueForKeyPath oldValue class %@ != NSDate / did crashed here earlier", [oldValue class]);
        }
        
    }

}

+ (void)postprocessingForObject:(NSManagedObject *)object withEntityName:(NSString *)entityName {
    
#warning should override?
    if /*([entityName isEqualToString:NSStringFromClass([STMMessage class])]) {
        
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"gotNewMessage" object:nil];
        
    } else if ([entityName isEqualToString:NSStringFromClass([STMCampaignPicture class])]) {
        
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"gotNewCampaignPicture" object:nil];
        
    } else if ([entityName isEqualToString:NSStringFromClass([STMCampaign class])]) {
        
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"gotNewCampaign" object:nil];
        
    } else if */([entityName isEqualToString:NSStringFromClass([STMRecordStatus class])]) {
        
        STMRecordStatus *recordStatus = (STMRecordStatus *)object;
        
        NSManagedObject *affectedObject = [self objectForXid:recordStatus.objectXid];
        
        if (affectedObject) {
            
//            if ([recordStatus.isRead boolValue]) [[NSNotificationCenter defaultCenter] postNotificationName:@"messageIsRead" object:nil];
            if ([recordStatus.isRemoved boolValue]) [self removeObject:affectedObject];
            
        }
        
        if (recordStatus.isTemporary.boolValue) [self removeObject:recordStatus];
        
    } else if ([entityName isEqualToString:NSStringFromClass([STMSetting class])]) {
        
        STMSetting *setting = (STMSetting *)object;
        
        if ([setting.group isEqualToString:@"appSettings"]) {
            
            [STMClientDataController checkAppVersion];
            
        }
        
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
    
// time checking
//    NSDate *start = [NSDate date];
// -------------
    
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

// time checking
//        [[self sharedController].timesDic[@"5"] addObject:@([start timeIntervalSinceNow])];
// -------------
        
        if (ok) {
            
            NSManagedObject *ownerObject = [self objectForEntityName:roleOwnerEntityName andXidString:ownerXid];
            NSManagedObject *destinationObject = [self objectForEntityName:destinationEntityName andXidString:destinationXid];
            
// time checking
//            [[self sharedController].timesDic[@"6"] addObject:@([start timeIntervalSinceNow])];
// -------------
            
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
        
// time checking
//        [[self sharedController].timesDic[@"7"] addObject:@([start timeIntervalSinceNow])];
// -------------
        
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

+ (NSManagedObject *)objectForXid:(NSData *)xidData {
    
    id cachedObject = [self sharedController].objectsCache[xidData];
    return (NSManagedObject *)cachedObject;
    
//    for (NSString *entityName in [self localDataModelEntityNames]) {
//        
//        NSManagedObject *object = [self objectForXid:xidData entityName:entityName];
//        
//        if (object) return object;
//        
//    }
//
//    return nil;

}

+ (NSManagedObject *)objectForXid:(NSData *)xidData entityName:(NSString *)entityName {
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.predicate = [NSPredicate predicateWithFormat:@"xid == %@", xidData];
        
        NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
        
        if (fetchResult.firstObject) return fetchResult.firstObject;

    }
    
    return nil;
    
}

+ (NSManagedObject *)objectForEntityName:(NSString *)entityName andXidString:(NSString *)xid {
    
    NSArray *dataModelEntityNames = [self localDataModelEntityNames];
    
    if ([dataModelEntityNames containsObject:entityName]) {
        
        NSData *xidData = [STMFunctions xidDataFromXidString:xid];

        NSManagedObject *object = [self objectForXid:xidData entityName:entityName];
        
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

+ (NSManagedObject *)newObjectForEntityName:(NSString *)entityName {
    return [self newObjectForEntityName:entityName andXid:nil isFantom:YES];
}

+ (NSManagedObject *)newObjectForEntityName:(NSString *)entityName isFantom:(BOOL)isFantom {
    return [self newObjectForEntityName:entityName andXid:nil isFantom:isFantom];
}

+ (NSManagedObject *)newObjectForEntityName:(NSString *)entityName andXid:(NSData *)xidData {
    return [self newObjectForEntityName:entityName andXid:xidData isFantom:YES];
}

+ (NSManagedObject *)newObjectForEntityName:(NSString *)entityName andXid:(NSData *)xidData isFantom:(BOOL)isFantom {
    
    if ([self document].managedObjectContext) {
    
        NSManagedObject *object = [STMEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:[self document].managedObjectContext];
        [object setValue:@(isFantom) forKey:@"isFantom"];
        
        if (xidData) {
            [object setValue:xidData forKey:@"xid"];
        } else {
            xidData = [object valueForKey:@"xid"];
        }
        
        [self sharedController].objectsCache[xidData] = object;
        
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

+ (void)initObjectsCacheWithCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    TICK;
    NSLog(@"initObjectsCache tick");
    
    [self sharedController].objectsCache = nil;

    NSArray *allObjects = [self allObjectsFromContext:[self document].managedObjectContext];

//    for (NSManagedObject *object in allObjects) {
//        
//        if ([object isKindOfClass:[STMShippingLocation class]]) {
//            [self removeObject:object];
//        }
//        
//    }
//    
//    allObjects = [self allObjectsFromContext:[self document].managedObjectContext];
    
    NSLog(@"fetch existing objects for initObjectsCache");
    TOCK;
    
    NSArray *keys = [allObjects valueForKeyPath:@"xid"];
    NSDictionary *objectsCache = [NSDictionary dictionaryWithObjects:allObjects forKeys:keys];
    
    [[self sharedController].objectsCache addEntriesFromDictionary:objectsCache];

    NSLog(@"finish initObjectsCache");
    TOCK;
    
    [[self document] saveDocument:^(BOOL success) {
        completionHandler(YES);
    }];
    
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
    NSMutableDictionary *objectRelationships = entitiesOwnRelationships[entityName];
    
    if (!objectRelationships) {

        STMEntityDescription *objectEntity = [STMEntityDescription entityForName:entityName
                                                          inManagedObjectContext:[self document].managedObjectContext];

        NSSet *coreRelationshipNames = [NSSet setWithArray:[self coreEntityRelationships]];
        
        NSMutableSet *objectRelationshipNames = [NSMutableSet setWithArray:objectEntity.relationshipsByName.allKeys];
        
        [objectRelationshipNames minusSet:coreRelationshipNames];
        
        objectRelationships = [NSMutableDictionary dictionary];
        
        for (NSString *relationshipName in objectRelationshipNames) {
            
            NSRelationshipDescription *relationship = objectEntity.relationshipsByName[relationshipName];
            objectRelationships[relationshipName] = relationship.destinationEntity.name;
            
        }
    
        entitiesOwnRelationships[entityName] = objectRelationships;
        
    }

//    NSLog(@"objectRelationships %@", objectRelationships);
    
    return objectRelationships;
    
}

+ (NSDictionary *)singleRelationshipsForEntityName:(NSString *)entityName {
    
    NSMutableDictionary *entitiesSingleRelationships = [self sharedController].entitiesSingleRelationships;
    NSMutableDictionary *objectRelationships = entitiesSingleRelationships[entityName];
    
    if (!objectRelationships) {

        STMEntityDescription *objectEntity = [STMEntityDescription entityForName:entityName
                                                          inManagedObjectContext:[self document].managedObjectContext];
        
        NSSet *coreRelationshipNames = [NSSet setWithArray:[self coreEntityRelationships]];
        
        NSMutableSet *objectRelationshipNames = [NSMutableSet setWithArray:[[objectEntity relationshipsByName] allKeys]];
        
        [objectRelationshipNames minusSet:coreRelationshipNames];
        
        objectRelationships = [NSMutableDictionary dictionary];
        
        for (NSString *relationshipName in objectRelationshipNames) {
            
            NSRelationshipDescription *relationship = [objectEntity relationshipsByName][relationshipName];
            
            if (![relationship isToMany]) {
                objectRelationships[relationshipName] = [relationship destinationEntity].name;
            }
            
        }
    
        entitiesSingleRelationships[entityName] = objectRelationships;
        
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

+ (void)removeObject:(NSManagedObject *)object {
    [self removeObject:object inContext:nil];
}

+ (void)removeObject:(NSManagedObject *)object inContext:(NSManagedObjectContext *)context {
    
    if (object) {
        
        if (!context) context = [self document].managedObjectContext;
        
        if ([object valueForKey:@"xid"]) {
            [[self sharedController].objectsCache removeObjectForKey:(id _Nonnull)[object valueForKey:@"xid"]];
        }
        
        [context performBlock:^{
            
            [context deleteObject:object];
            
            [[self document] saveDocument:^(BOOL success) {
            }];
            
        }];

    }
    
}

+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(NSManagedObject *)object {
    return [self createRecordStatusAndRemoveObject:object withComment:nil];
}

+ (STMRecordStatus *)createRecordStatusAndRemoveObject:(NSManagedObject *)object withComment:(NSString *)commentText {
    
    STMRecordStatus *recordStatus = [STMRecordStatusController recordStatusForObject:object];
    recordStatus.isRemoved = @YES;
    recordStatus.commentText = commentText;
    
    [self removeObject:object];
    
    return recordStatus;
    
}

+ (void)checkObjectsForFlushing {
    
    NSLogMethodName;

    [self sharedController].isInFlushingProcess = NO;
    
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
    
    NSMutableSet *objectsSet = [NSMutableSet set];
    
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
        request.predicate = [NSPredicate predicateWithFormat:predicateString, terminatorDate];

        NSArray *fetchResult = [context executeFetchRequest:request error:&error];
        
        for (NSManagedObject *object in fetchResult) [self checkObject:object forAddingTo:objectsSet];

    }

    if (objectsSet.count > 0) {

        for (NSManagedObject *object in objectsSet) {
            [self removeObject:object inContext:context];
        }
        
        NSTimeInterval flushingTime = [[NSDate date] timeIntervalSinceDate:startFlushing];
        
        NSString *logMessage = [NSString stringWithFormat:@"flush %lu objects with expired lifetime, %f seconds", (unsigned long)objectsSet.count, flushingTime];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"info"];
        
        [self sharedController].isInFlushingProcess = YES;

        [[self document] saveDocument:^(BOOL success) {

        }];
        
        
    } else {
        
        NSLog(@"No objects for flushing");
        
    }
    
}

+ (void)checkObject:(NSManagedObject *)object forAddingTo:(NSMutableSet *)objectsSet {
    
#warning should override

//    if ([object isKindOfClass:[STMTrack class]]) {
//    
//        STMTrack *track = (STMTrack *)object;
//
//        if (![track.objectID isEqual:[self session].locationTracker.currentTrack.objectID]) {
//            [objectsSet addObject:object];
//        } else {
//            NSLog(@"track %@ is current track now, flush declined", track.xid);
//        }
//        
//    } else {
    
        if (![self isWaitingToSyncForObject:object]) {
            
            if ([object isKindOfClass:[STMLocation class]]) {
        
                STMLocation *location = (STMLocation *)object;
                
#warning should override
                if (location.photos.count == 0 /*&& location.shippings.count == 0 && location.shipmentRoutePoint == nil*/) {
                    [objectsSet addObject:object];
                } else {
                    NSLog(@"location %@ linked with (picture|shipping|routePoint), flush declined", location.xid);
                }

//            } else if ([object isKindOfClass:[STMTrack class]]) {
//                
//                STMTrack *track = (STMTrack *)object;
//                
//                if (![track.objectID isEqual:[self session].locationTracker.currentTrack.objectID]) {
//                    [objectsSet addObject:object];
//                } else {
//                    NSLog(@"track %@ is in use now, flush declined", track.xid);
//                }
                
            } else {

                [objectsSet addObject:object];

            }

        }
//        
//    }

}

#pragma mark - finish of recieving objects

+ (void)avgTimesCalc {
    
    NSArray *first = [self sharedController].timesDic[@"1"];
    NSArray *second = [self sharedController].timesDic[@"2"];
    NSArray *third = [self sharedController].timesDic[@"3"];
    NSArray *fourth = [self sharedController].timesDic[@"4"];
    NSArray *fifth = [self sharedController].timesDic[@"5"];
    NSArray *sixth = [self sharedController].timesDic[@"6"];
    NSArray *seventh = [self sharedController].timesDic[@"7"];
    NSArray *eighth = [self sharedController].timesDic[@"8"];
    NSArray *nineth = [self sharedController].timesDic[@"9"];
    
    NSNumber *avgFirst = [first valueForKeyPath:@"@avg.self"];
    NSNumber *avgSecond = [second valueForKeyPath:@"@avg.self"];
    NSNumber *avgThird = [third valueForKeyPath:@"@avg.self"];
    NSNumber *avgFourth = [fourth valueForKeyPath:@"@avg.self"];
    NSNumber *avgFifth = [fifth valueForKeyPath:@"@avg.self"];
    NSNumber *avgSixth = [sixth valueForKeyPath:@"@avg.self"];
    NSNumber *avgSeventh = [seventh valueForKeyPath:@"@avg.self"];
    NSNumber *avgEighth = [eighth valueForKeyPath:@"@avg.self"];
    NSNumber *avgNineth = [nineth valueForKeyPath:@"@avg.self"];
    
    NSLog(@"avgFirst %@", avgFirst);
    NSLog(@"avgSecond %@", avgSecond);
    NSLog(@"avgThird %@", avgThird);
    NSLog(@"avgFourth %@", avgFourth);
    NSLog(@"avgFifth %@", avgFifth);
    NSLog(@"avgSixth %@", avgSixth);
    NSLog(@"avgSeventh %@", avgSeventh);
    NSLog(@"avgEighth %@", avgEighth);
    NSLog(@"avgNineth %@", avgNineth);
    
    NSLog(@"eighth.count %d", eighth.count);
    NSLog(@"nineth.count %d", nineth.count);
    
}

+ (void)dataLoadingFinished {
    
//    [self avgTimesCalc];
    
    [STMPicturesController checkPhotos];
//    [self checkObjectsForFlushing];
    
#ifdef DEBUG
    [self totalNumberOfObjects];
#else

#endif
    
    [[self document] saveDocument:^(BOOL success) {

    }];

}

+ (void)totalNumberOfObjects {

    NSArray *entityNames = [self localDataModelEntityNames];
    
    NSUInteger totalCount = 0;
    
    for (NSString *entityName in entityNames) {
        
        NSUInteger count = [self numberOfObjectsForEntityName:entityName];
        NSLog(@"%@ count %d", entityName, count);
        totalCount += count;

    }
    
    NSLog(@"fantoms count %d", [self numberOfFantoms]);
    NSLog(@"total count %d", totalCount);

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

+ (void)sendSubscribedEntityObject:(STMDatum *)object entityName:(NSString *)entityName {
    
    NSArray <UIViewController <STMEntitiesSubscribable> *> *vcArray = [self sharedController].entitiesToSubscribe[entityName];
    
    for (UIViewController <STMEntitiesSubscribable> *vc in vcArray) {
    
        [vc subscribedEntitiesObjectWasReceived:[self dictionaryForJSWithObject:object]];

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
    
    STMDatum *object = [self sharedController].objectsCache[xid];
    
    if (object) {
        
        if (![object.entity.name isEqualToString:entityName]) {
            
            errorMessage = [NSString stringWithFormat:@"object with xid %@ have entity name %@, not %@", xidString, object.entity.name, entityName];
            [self error:error withMessage:errorMessage];
            return nil;
            
        } else {
            
            STMRecordStatus *recordStatus = [self createRecordStatusAndRemoveObject:object];
            return [self arrayForJSWithObjects:@[recordStatus]];
            
        }
        
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entity.name == %@ && xid == %@", entityName, xid];
    
    NSArray *objectsArray = [self objectsForEntityName:entityName
                                               orderBy:@"id"
                                             ascending:YES
                                            fetchLimit:0
                                           fetchOffset:0
                                           withFantoms:NO
                                             predicate:predicate
                                inManagedObjectContext:[self document].managedObjectContext
                                                 error:error];
    
    if (objectsArray.count == 0) {
        
        errorMessage = [NSString stringWithFormat:@"no object for destroy with xid %@ and entity name %@", xidString, entityName];
        [self error:error withMessage:errorMessage];
        return nil;

    }
    
    if (objectsArray.count > 1) {
        
        errorMessage = [NSString stringWithFormat:@"more than 1 object for destroy with xid %@ and entity name %@", xidString, entityName];
        [self error:error withMessage:errorMessage];
        return nil;
        
    }

    object = objectsArray.firstObject;
    
    STMRecordStatus *recordStatus = [self createRecordStatusAndRemoveObject:object];
    return [self arrayForJSWithObjects:@[recordStatus]];
    
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
                
                if (localError) {
                    errorMessage = (errorMessage) ? [errorMessage stringByAppendingString:localError.localizedDescription] : localError.localizedDescription;
                } else {
                    [result addObject:updatedData];
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

    [self processingKeysForUpdatingObject:object withObjectData:objectData error:error];

    return (*error) ? nil : [self dictionaryForJSWithObject:object];
    
}

+ (void)processingKeysForUpdatingObject:(STMDatum *)object withObjectData:(NSDictionary *)objectData error:(NSError **)error {
    
    objectData = [self normalizeObjectData:objectData forObject:object error:error];
    
    if (*error) return;
    
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
    
    NSDictionary *ownRelationships = [self singleRelationshipsForEntityName:entityName];
    
    for (NSString *key in ownRelationships.allKeys) {
        
        NSString *xidString = objectData[key];

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
                
            } else {
                
                NSString *message = [NSString stringWithFormat:@"%@ object %@ can't update value %@ for key %@\n", entityName, object.xid, value, key];
                
                errorMessage = (errorMessage) ? [errorMessage stringByAppendingString:message] : message;
                
                continue;
                
            }
            
        }
        
    }
    
    NSArray *ownRelationships = [self singleRelationshipsForEntityName:entityName].allKeys;
    
    for (NSString *key in ownRelationships) {
        
        id value = objectData[key];
        
        if (value) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                NSString *xidString = (NSString *)value;
                
                NSManagedObject *destinationObject = [self objectForEntityName:entityName andXidString:xidString];
                
                if (![[object valueForKey:key] isEqual:destinationObject]) {
                    resultDic[key] = value;
                }
                
            } else {
                
                NSString *message = [NSString stringWithFormat:@"%@ object %@ relationship value %@ is not a String for key %@, can't get xid\n", entityName, object.xid, value, key];
                
                errorMessage = (errorMessage) ? [errorMessage stringByAppendingString:message] : message;
                
                continue;
                
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
    
    NSPredicate *predicate = [STMScriptMessageController predicateForScriptMessage:scriptMessage error:error];
    
    if (*error) return nil;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    NSDictionary *options = parameters[@"options"];
    NSUInteger pageSize = [options[@"pageSize"] integerValue];
    NSUInteger startPage = [options[@"startPage"] integerValue] - 1;
    
    NSArray *objectsArray = [self objectsForEntityName:entityName
                                               orderBy:@"id"
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

+ (void)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    if (bundleId && error) *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                        code:1
                                                    userInfo:@{NSLocalizedDescriptionKey: errorMessage}];

}

+ (NSArray *)findObjectInCacheWithParameters:(NSDictionary *)parameters error:(NSError **)error {
    
    NSString *errorMessage = nil;

    NSString *entityName = [NSString stringWithFormat:@"%@%@", ISISTEMIUM_PREFIX, parameters[@"entity"]];
    
    if ([[self localDataModelEntityNames] containsObject:entityName]) {
        
        NSString *xidString = parameters[@"id"];
        
        if (xidString) {
            
            NSData *xid = [STMFunctions xidDataFromXidString:xidString];
            
            STMDatum *object = [self sharedController].objectsCache[xid];
            
            if (object) {
                
                if (object.isFantom.boolValue) {
                    
                    errorMessage = [NSString stringWithFormat:@"object with xid %@ is fantom", xidString];
                    
                } else if (![object.entity.name isEqualToString:entityName]) {
                    
                    errorMessage = [NSString stringWithFormat:@"object with xid %@ have entity name %@, not %@", xidString, object.entity.name, entityName];
                    
                } else {
                    
                    return [self arrayForJSWithObjects:@[object]];
                    
                }
                
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
    
    NSMutableDictionary *propertiesDictionary = @{}.mutableCopy;
    
    if (object.xid) propertiesDictionary[@"id"] = [STMFunctions UUIDStringFromUUIDData:(NSData *)object.xid];
    if (object.deviceTs) propertiesDictionary[@"ts"] = [[STMFunctions dateFormatter] stringFromDate:(NSDate *)object.deviceTs];
    
    NSArray *ownKeys = [self ownObjectKeysForEntityName:object.entity.name].allObjects;
    NSArray *ownRelationships = [self singleRelationshipsForEntityName:object.entity.name].allKeys;
    
    [propertiesDictionary addEntriesFromDictionary:[object propertiesForKeys:ownKeys]];
    [propertiesDictionary addEntriesFromDictionary:[object relationshipXidsForKeys:ownRelationships]];
    
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
        
        if ([entity.propertiesByName.allKeys containsObject:orderBy]) {
            
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:orderBy ascending:ascending selector:@selector(compare:)]];
            request.fetchLimit = fetchLimit;
            request.fetchOffset = fetchOffset;
            
            request.predicate = (withFantoms) ? predicate : [STMPredicate predicateWithNoFantomsFromPredicate:predicate];
            
            NSError *fetchError;
            NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&fetchError];
            
            if (!fetchError) {
                return result;
            } else {
                errorMessage = fetchError.localizedDescription;
            }
            
        } else {
            
            errorMessage = [NSString stringWithFormat:@"%@: property %@ not found", entityName, orderBy];
            
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
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.predicate = [NSPredicate predicateWithFormat:@"isFantom == YES"];

        NSUInteger result = [[self document].managedObjectContext countForFetchRequest:request error:nil];
        
        resultCount += result;

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
        
        BOOL sessionIsRunning = [[self.session status] isEqualToString:@"running"];
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
                
                for (NSManagedObject *object in objects)
                    [jsonObjectsArray addObject:[STMCoreObjectsController dictionaryForObject:object]];
                
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

+ (NSDictionary *)dictionaryForObject:(NSManagedObject *)object {
    
    if ([object isKindOfClass:[STMDatum class]]) {
        
        NSString *entityName = object.entity.name;
        NSString *name = [@"stc." stringByAppendingString:[entityName stringByReplacingOccurrencesOfString:ISISTEMIUM_PREFIX withString:@""]];
        NSData *xidData = [object valueForKey:@"xid"];
        NSString *xid = [STMFunctions UUIDStringFromUUIDData:xidData];
        
        NSDictionary *propertiesDictionary = [self propertiesDictionaryForObject:(STMDatum *)object];
        
        return @{@"name":name, @"xid":xid, @"properties":propertiesDictionary};

    } else {
        return nil;
    }
    
}

+ (NSDictionary *)propertiesDictionaryForObject:(STMDatum *)object {
    
    NSMutableArray *allKeys;
    
    if ([object.entity.name isEqualToString:NSStringFromClass([STMEntity class])]) {
        allKeys = @[@"eTag", @"name", @"deviceCts", @"deviceTs"].mutableCopy;
    } else {
        allKeys = object.entity.attributesByName.allKeys.mutableCopy;
    }
    
    NSArray *notSyncableProperties = @[@"xid", @"resizedImagePath", @"imageThumbnail"];
    
    [allKeys removeObjectsInArray:notSyncableProperties];
    
    NSMutableDictionary *propertiesDictionary = [NSMutableDictionary dictionaryWithDictionary:[object propertiesForKeys:allKeys]];
    
    for (NSString *key in object.entity.relationshipsByName.allKeys) {
        
        NSRelationshipDescription *relationshipDescription = [object.entity.relationshipsByName valueForKey:key];
        
        if (![relationshipDescription isToMany]) {
            
            NSManagedObject *relationshipObject = [object valueForKey:key];
            
            if (relationshipObject) {
                
                NSData *xidData = [relationshipObject valueForKey:@"xid"];
                
                if (xidData.length != 0) {
                    
                    NSString *xid = [STMFunctions UUIDStringFromUUIDData:xidData];
                    NSString *entityName = key;
                    propertiesDictionary[key] = @{@"name": entityName, @"xid": xid};
                    
                }
                
            }
            
        }
        
    }
    
    return propertiesDictionary;
    
}


#pragma mark - sync object

+ (void)syncObject:(NSDictionary *)objectDictionary {
    
    NSString *result = [objectDictionary valueForKey:@"result"];
    NSString *xid = [objectDictionary valueForKey:@"xid"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xid];
    
    if (!result || ![result isEqualToString:@"ok"]) {
        
        NSString *errorMessage = [NSString stringWithFormat:@"Sync result not ok xid: %@", xid];
        [[self session].logger saveLogMessageWithText:errorMessage type:@"error"];
        
    } else {

        NSManagedObject *syncedObject = [self objectForXid:xidData];
        
        if ([syncedObject isKindOfClass:[STMDatum class]]) {
            
            STMDatum *object = (STMDatum *)syncedObject;
            
            if (object) {
                
                [object.managedObjectContext performBlockAndWait:^{
                
                    if ([object isKindOfClass:[STMRecordStatus class]] && [[(STMRecordStatus *)object valueForKey:@"isRemoved"] boolValue]) {
                        
                        [self removeObject:object];
                        
                    } else {
                        
                        NSDate *deviceTs = [STMSocketController deviceTsForSyncedObjectXid:xidData];
                        object.lts = deviceTs;
                        [object willChangeValueForKey:@"lts"];
                        [object setPrimitiveValue:deviceTs forKey:@"lts"];
                        [object didChangeValueForKey:@"lts"];
                        
                    }
                    
                    //                [STMSocketController successfullySyncObjectWithXid:xidData];
                    
                    NSString *entityName = object.entity.name;
                    
                    NSString *logMessage = [NSString stringWithFormat:@"successefully sync %@ with xid %@", entityName, xid];
                    NSLog(logMessage);

                }];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"Sync: no object with xid: %@", xid];
                NSLog(logMessage);
                
            }

        }
        
    }

}


@end
