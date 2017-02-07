//
//  STMPersister+CoreData.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 26/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "STMCoreSessionManager.h"

#import "STMPersister+CoreData.h"
#import "STMFunctions.h"

#import "STMEntityDescription.h"
#import "STMPredicate.h"
#import "STMCoreObjectsController.h"
#import "STMEntityController.h"
#import "STMRecordStatusController.h"
#import "STMModeller+Private.h"
#import "STMCorePicturesController.h"
#import "STMClientDataController.h"

@implementation STMPersister (CoreData)

#pragma mark methods to remove from STMCoreObjectsController

- (NSSet *)ownObjectKeysForEntityName:(NSString *)entityName {
    return [STMCoreObjectsController ownObjectKeysForEntityName:entityName];
}

#pragma mark - Modelling override

- (NSManagedObject *)findOrCreateManagedObjectOf:(NSString *)entityName identifier:(NSString *)identifier {

    return [self findOrCreateManagedObjectOf:entityName andXid:[STMFunctions xidDataFromXidString:identifier]];
    
}


#pragma mark - Private CoreData helpers

- (BOOL)setRelationshipFromDictionary:(NSDictionary *)dictionary {
    
    NSString *name = dictionary[@"name"];
    NSArray *nameExplode = [name componentsSeparatedByString:@"."];
    NSString *entityName = [ISISTEMIUM_PREFIX stringByAppendingString:nameExplode[1]];
    
    NSDictionary *serverDataModel = STMEntityController.stcEntities;
    STMEntity *entityModel = serverDataModel[entityName];
    
    if (!entityModel) {
        NSLog(@"dataModel have no relationship's entity with name %@", entityName);
        return NO;
    }
    
    NSString *roleOwner = entityModel.roleOwner;
    NSString *roleOwnerEntityName = [STMFunctions addPrefixToEntityName:roleOwner];
    NSString *roleName = entityModel.roleName;
    NSDictionary *ownerRelationships = [STMCoreObjectsController ownObjectRelationshipsForEntityName:roleOwnerEntityName];
    NSString *destinationEntityName = ownerRelationships[roleName];
    NSString *destination = [STMFunctions removePrefixFromEntityName:destinationEntityName];
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
        
        NSManagedObject *ownerObject = [self findOrCreateManagedObjectOf:roleOwnerEntityName identifier:ownerXid];
        NSManagedObject *destinationObject = [self findOrCreateManagedObjectOf:destinationEntityName identifier:destinationXid];
        
        NSSet *destinationSet = [ownerObject valueForKey:roleName];
        
        if ([destinationSet containsObject:destinationObject]) {
            
            NSLog(@"already have relationship %@ %@ — %@ %@", roleOwnerEntityName, ownerXid, destinationEntityName, destinationXid);
            
            
        } else {
            
            BOOL ownerIsWaitingForSync = [STMCoreObjectsController isWaitingToSyncForObject:ownerObject];
            BOOL destinationIsWaitingForSync = [STMCoreObjectsController isWaitingToSyncForObject:destinationObject];
            
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
    
}

- (NSDictionary *)mergeWithoutSave:entityName
                        attributes:(NSDictionary *)attributes
                           options:(NSDictionary *)options
                             error:(NSError **)error
            inManagedObjectContext:(NSManagedObjectContext *)context {
    
    if (options[@"roleName"]) {
        
        BOOL success = [self setRelationshipFromDictionary:attributes];
        if (!success) {
            [STMFunctions error:error
                    withMessage:[NSString stringWithFormat:@"Relationship error %@", entityName]];
        }
        
    } else {
        
        NSDictionary *object = [self insertObjectFromDictionary:attributes
                                                 withEntityName:entityName
                                                        options:options
                                ];
        
        if (object) {
            return object;
        }
        
        [STMFunctions error:error
                withMessage:[NSString stringWithFormat:@"Error inserting %@", entityName]];
        
    }
    
    return attributes;

}

- (NSDictionary *)update:(NSString *)entityName
              attributes:(NSDictionary *)attributes
                 options:(NSDictionary *)options
                   error:(NSError **)error
  inManagedObjectContext:(NSManagedObjectContext *)context {
    
    if (attributes[@"id"] && [attributes[@"id"] length] == 36){
    
        STMDatum *object = [self objectForXid:[STMFunctions xidDataFromXidString:attributes[@"id"]] entityName:entityName];
        
        if (![object isWaitingToSync] || options[STMPersistingOptionLts]) {
            
            [object setValue:@NO forKey:@"isFantom"];
            
            [self processingOfObject:object
                      withEntityName:entityName
                      fillWithValues:attributes
                             options:options
             ];
            
        }
        
        return [self dictionaryFromManagedObject:object];
        
    }
    
    [STMFunctions error:error withMessage:@"Wrong object id"];
    
    return nil;
    
}

- (void)removeObjects:(NSArray*)objects {
    for (id object in objects){
        [self.document.managedObjectContext deleteObject:object];
    }
}

- (NSUInteger)removeObjectForPredicate:(NSPredicate*)predicate entityName:(NSString *)name{
    name = [STMFunctions addPrefixToEntityName:name];
    NSArray *objects = [self objectsForPredicate:predicate entityName:name];
    NSUInteger result = objects.count;
    [self removeObjects:objects];
    return result;
}

- (NSArray *)objectsForPredicate:(NSPredicate *)predicate entityName:(NSString *)entityName {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    
    //    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = predicate;
    NSError *error;
    NSArray *result = [self.document.managedObjectContext executeFetchRequest:request error:&error];
    return result;
    
}


- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms predicate:(NSPredicate *)predicate resultType:(NSFetchRequestResultType)resultType inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {
    
    NSString *errorMessage = nil;
    
    context = (context) ? context : [self document].managedObjectContext;
    
    if (context.hasChanges && fetchOffset > 0) {
        
        [[self document] saveDocument:^(BOOL success) {
            
        }];
        
    }
    
    if ([self isConcreteEntityName:entityName]) {
        
        STMEntityDescription *entity = [STMEntityDescription entityForName:entityName inManagedObjectContext:context];
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        
        request.fetchLimit = fetchLimit;
        request.fetchOffset = fetchOffset;
        request.predicate = (withFantoms) ? predicate : [STMPredicate predicateWithNoFantomsFromPredicate:predicate];
        request.resultType = resultType;
        
        if (resultType == NSDictionaryResultType) {
            
            NSArray *ownKeys = [self fieldsForEntityName:entityName].allKeys;
            NSArray *ownRelationships = [self toOneRelationshipsForEntityName:entityName].allKeys;
            
            request.propertiesToFetch = [ownKeys arrayByAddingObjectsFromArray:ownRelationships];
            
        }
        
        NSAttributeDescription *orderByAttribute = entity.attributesByName[orderBy];
        BOOL isNSString = [NSClassFromString(orderByAttribute.attributeValueClassName) isKindOfClass:[NSString class]];
        
        SEL sortSelector = isNSString ? @selector(caseInsensitiveCompare:) : @selector(compare:);
        
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:orderBy
                                                                         ascending:ascending
                                                                          selector:sortSelector];
        
        BOOL afterRequestSort = NO;
        
        if ([entity.propertiesByName objectForKey:orderBy]) {
            
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
    
    if (errorMessage) [STMFunctions error:error withMessage:errorMessage];
    
    return nil;
    
}

- (NSArray *)arrayForJSWithObjects:(NSArray <STMDatum *> *)objects {
    
    NSMutableArray *dataArray = @[].mutableCopy;
    
    [objects enumerateObjectsUsingBlock:^(STMDatum * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSDictionary *propertiesDictionary = [self dictionaryFromManagedObject:obj];
        [dataArray addObject:propertiesDictionary];
        
    }];
    
    return dataArray;
    
}

- (void)processingOfObject:(NSManagedObject *)object
            withEntityName:(NSString *)entityName
            fillWithValues:(NSDictionary *)properties
                   options:(NSDictionary *)options
{
    
    NSSet *fields =
    [self ownObjectKeysForEntityName:entityName];
    //[self fieldsForEntityName:entityName];
    
    STMEntityDescription *currentEntity = (STMEntityDescription *)[object entity];
    NSDictionary *entityAttributes = currentEntity.attributesByName;
    
    for (NSString *key in fields) {
        
        id value = properties[key];
        
        value = (![value isKindOfClass:[NSNull class]]) ?
        [STMModeller typeConversionForValue:value
                                        key:key
                           entityAttributes:entityAttributes] : nil;
        
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
    
    if (options[STMPersistingOptionLts]) {
        // lts value here must be NSDate
        [object setValue:options[STMPersistingOptionLts]
                  forKey:STMPersistingOptionLts];
    }
    
    [self postprocessingForObject:object];
    
#warning To implement in STMScriptMessageHandler with PersistingObserving
//    STMCoreObjectsController *coc = [self sharedController];
//    
//    if ([coc.entitiesToSubscribe objectForKey:entityName]) {
//        
//        if (object && [object isKindOfClass:[STMDatum class]]) {
//            [coc.subscribedObjects addObject:(STMDatum *)object];
//        }
//        
//    }
    
}

- (void)postprocessingForObject:(NSManagedObject *)object {
#warning This is too specific. Need to remove this dependency on STMClientDataController
    if ([object isKindOfClass:[STMSetting class]]) {
        
        STMSetting *setting = (STMSetting *)object;
        
        if ([setting.group isEqualToString:@"appSettings"]) {
            [STMClientDataController checkAppVersion];
        }
        
    }
    
}

- (STMDatum *)objectForXid:(NSData *)xidData entityName:(NSString *)entityName {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"xid == %@", xidData];
    
    NSArray *fetchResult = [[self document].managedObjectContext executeFetchRequest:request error:nil];
    
    if (fetchResult.firstObject) return fetchResult.firstObject;
    
    return nil;
    
}

- (STMDatum *)findOrCreateManagedObjectOf:(NSString *)entityName andXid:(NSData *)xidData {
    
    STMDatum *object = [self objectForXid:xidData entityName:entityName];
    
    if (!object) object = [self newObjectForEntityName:entityName andXid:xidData];
    
    return object;
    
}

- (STMDatum *)newObjectForEntityName:(NSString *)entityName andXid:(NSData *)xidData {
    
    STMDatum *object = [STMEntityDescription insertNewObjectForEntityForName:entityName
                                                      inManagedObjectContext:self.document.managedObjectContext];
    
    object.isFantom = @(NO);
    
    if (xidData) object.xid = xidData;
    
    return object;
    
}

- (void)processingOfRelationshipsForObject:(NSManagedObject *)object
                            withEntityName:(NSString *)entityName
                                 andValues:(NSDictionary *)properties
{
    
    NSDictionary *ownObjectRelationships = [self toOneRelationshipsForEntityName:entityName];
    
    for (NSString *relationship in ownObjectRelationships.allKeys) {
        
        NSString *relationshipId = [relationship stringByAppendingString:RELATIONSHIP_SUFFIX];
        
        NSString *destinationObjectXid = [properties[relationshipId] isKindOfClass:[NSNull class]] ? nil : properties[relationshipId];
        
        if (destinationObjectXid) {
            
            NSManagedObject *destinationObject = [self findOrCreateManagedObjectOf:ownObjectRelationships[relationship] identifier:destinationObjectXid];
            
            if (![[object valueForKey:relationship] isEqual:destinationObject]) {
                
//                BOOL waitingForSync = [destinationObject isWaitingToSync];
                
                [object setValue:destinationObject forKey:relationship];
#warning what is this for?
//                if (!waitingForSync) {
//                    
//                    [destinationObject addObserver:[self sharedController]
//                                        forKeyPath:@"deviceTs"
//                                           options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
//                                           context:nil];
//                    
//                }
                
            }
            
        } else {
            
            NSManagedObject *destinationObject = [object valueForKey:relationship];
            
            if (destinationObject) {
#warning what is this for?
//                BOOL waitingForSync = [self isWaitingToSyncForObject:destinationObject];
                
                [object setValue:nil forKey:relationship];
                
//                if (!waitingForSync) {
//                
//                    [destinationObject addObserver:[self sharedController]
//                                        forKeyPath:@"deviceTs"
//                                           options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
//                                           context:nil];
//                    
//                }
                
            }
            
        }
        
    }
    
}

- (NSDictionary *)insertObjectFromDictionary:(NSDictionary *)dictionary
                              withEntityName:(NSString *)entityName
                                     options:(NSDictionary *)options
{
    
    if (![self isConcreteEntityName:entityName]) {
        NSLog(@"dataModel have no object's entity with name %@", entityName);
        return nil;
    }
    
    NSString *xidString = dictionary[@"id"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xidString];
    
    STMDatum *object = nil;
    
//    if ([entityName isEqualToString:NSStringFromClass([STMSetting class])]) {
//        
//        STMCoreSession *session = [STMCoreSessionManager sharedManager].currentSession;
//            
//        object = [session.settingsController settingForDictionary:dictionary];
//        
//    } else if ([entityName isEqualToString:NSStringFromClass([STMEntity class])]) {
//        
//        NSString *internalName = dictionary[@"name"];
//        object = [STMEntityController entityWithName:internalName];
//        
//    }
    
    if (!object && xidData) {
        object = [self findOrCreateManagedObjectOf:entityName andXid:xidData];
    }
    
    if (!object) {
        object = [self newObjectForEntityName:entityName andXid:nil];
    }
    
    // TODO: check if lts is equal to deviceTs
    if (![object isWaitingToSync] || options[STMPersistingOptionLts]) {
        
        [object setValue:@NO forKey:@"isFantom"];
        
        [self processingOfObject:object
                  withEntityName:entityName
                  fillWithValues:dictionary
                         options:options
         ];
        
    }
    
    return [self dictionaryFromManagedObject:object];
    
}


@end
