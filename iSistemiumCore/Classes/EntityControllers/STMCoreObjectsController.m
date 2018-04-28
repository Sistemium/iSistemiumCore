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
@property (nonatomic, strong) NSArray *coreEntityKeys;
@property (nonatomic) BOOL isInFlushingProcess;

@end


@implementation STMCoreObjectsController

#pragma mark - singleton

+ (STMCoreObjectsController *)sharedController {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedController = nil;
    
    dispatch_once(&pred, ^{
        _sharedController = [[self alloc] init];
    });
    
    return _sharedController;
    
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

+ (NSDictionary *)objectForIdentifier:(NSString *)identifier{
    
    NSString* entityName;
    
    return [self objectForIdentifier:identifier entityName:&entityName];

}

+ (NSDictionary *)objectForIdentifier:(NSString *)identifier entityName:(NSString**)name{
    
    for (NSString *entityName in self.persistenceDelegate.concreteEntities.allKeys) {
        
        if (![[self persistenceDelegate] isConcreteEntityName:entityName]) continue;
        
        NSError *error;
        NSDictionary *object = [[self persistenceDelegate] findSync:entityName identifier:identifier options:nil error:&error];
        
        *name = entityName;
        
        if (object) return object;
        
    }
    
    return nil;
    
}


+ (STMDatum *)newObjectForEntityName:(NSString *)entityName isFantom:(BOOL)isFantom {
    return [self newObjectForEntityName:entityName andXid:nil isFantom:isFantom];
}

+ (STMDatum *)newObjectForEntityName:(NSString *)entityName andXid:(NSData *)xidData isFantom:(BOOL)isFantom {
    
    NSManagedObjectContext *context = self.document.managedObjectContext;
    
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
    
    STMEntityDescription *objectEntity = [STMEntityDescription entityForName:entityName inManagedObjectContext:self.document.managedObjectContext];
    
    NSMutableArray *resultSet = @[].mutableCopy;

    for (NSString *key in objectEntity.attributesByName.allKeys) {
        
        NSAttributeDescription *attribute = objectEntity.attributesByName[key];
        
        if (attribute.attributeType == type) {
            [resultSet addObject:key];
        }
        
    }
    
    return resultSet;

}




+ (NSArray *)coreEntityKeys {
    return [self sharedController].coreEntityKeys;
}

- (NSArray *)coreEntityKeys {
    
    if (!_coreEntityKeys) {
        
        STMEntityDescription *coreEntity = [STMEntityDescription entityForName:NSStringFromClass([STMDatum class])
                                                        inManagedObjectContext:STMCoreObjectsController.document.managedObjectContext];
        
        _coreEntityKeys = coreEntity.attributesByName.allKeys;
        
    }
    return _coreEntityKeys;
    
}

#pragma mark - flushing


+ (void)checkObjectsForFlushing {
    
    NSLogMethodName;

    STMCoreObjectsController *sc = [self sharedController];
    
    sc.isInFlushingProcess = NO;
    
    if (![STMFunctions isAppInBackground]) {
        
        NSLog(@"app is not in background, flushing canceled");
        return;
        
    }
    
    if (!self.session.syncer) return;

    NSDate *startFlushing = [NSDate date];
    
    NSArray *entitiesWithLifeTime = [STMEntityController entitiesWithLifeTime];
    
    for (NSDictionary *entity in entitiesWithLifeTime) {
        
        double lifeTime = [entity[@"lifeTime"] doubleValue];
        NSString *entityName = entity[@"name"];
        NSDate *terminatorDate = [NSDate dateWithTimeInterval:-lifeTime*3600 sinceDate:startFlushing];
        
        NSString *dateField = entity[@"lifeTimeDateField"];
        
        if ([STMFunctions isNull:dateField]) {
            dateField = @"deviceCts";
        }
        
        NSError *error;
        NSString *prefixedName = [STMFunctions addPrefixToEntityName:entityName];
        
        NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"%@ < %@", dateField, terminatorDate];
        NSPredicate *unsyncedPredicate = [self.session.syncer predicateForUnsyncedObjectsWithEntityName:prefixedName];
        
        NSMutableArray *subpredicates = @[datePredicate].mutableCopy;
        
        if (unsyncedPredicate) {
            [subpredicates addObject:[NSCompoundPredicate notPredicateWithSubpredicate:unsyncedPredicate]];
        }
        
        NSDictionary *relations = [self.persistenceDelegate objectRelationshipsForEntityName:prefixedName isToMany:@YES cascade:@NO];
        
        NSMutableDictionary *options = @{STMPersistingOptionRecordstatuses: @NO,
                                         STMPersistingOptionPageSize: @(1500)
                                         }.mutableCopy;
        
        NSMutableArray *denyCascades = [NSMutableArray array];

        [relations enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSRelationshipDescription *relation, BOOL * _Nonnull stop) {
            
            NSString *destinationName = [STMFunctions removePrefixFromEntityName:relation.destinationEntity.name];
            
            if (relation.deleteRule != NSDenyDeleteRule) {
                return;
            }
            
            NSSet <NSString*> *concreteDescendants = [self.persistenceDelegate hierarchyForEntityName:relation.destinationEntity.name];
            
            for (NSString *descendant in concreteDescendants) {
                NSString *denyDelete = [NSString stringWithFormat:@"not exists (select * from %@ where %@Id = %@.id)", [STMFunctions removePrefixFromEntityName:descendant], relation.inverseRelationship.name, entityName];
                
                [denyCascades addObject:denyDelete];
            }

            if (![self.persistenceDelegate isConcreteEntityName:destinationName]) {
                return;
            }
            
            NSString *denyDelete = [NSString stringWithFormat:@"not exists (select * from %@ where %@Id = %@.id)", destinationName, relation.inverseRelationship.name, entityName];
            
            [denyCascades addObject:denyDelete];
            
        }];
        
        if (denyCascades.count) {
            options[STMPersistingOptionWhere] = [denyCascades componentsJoinedByString:@" AND "];
        }
        
        NSCompoundPredicate *predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                     subpredicates:subpredicates];
        
        NSUInteger deletedCount = [self.persistenceDelegate destroyAllSync:entityName
                                                                 predicate:predicate
                                                                   options:options.copy
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

    [STMCorePicturesController checkNotUploadedPhotos];
    
#ifdef DEBUG
    [self logTotalNumberOfObjectsInStorages];
#else

#endif

}

+ (void)logTotalNumberOfObjectsInStorages {
    
    NSArray *entityNames = [[self.persistenceDelegate entitiesByName].allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    NSUInteger totalCountFMDB = 0;
    NSUInteger totalFantoms = 0;
    
    for (NSString *entityName in entityNames) {
        
        if (![self.persistenceDelegate isConcreteEntityName:entityName]) continue;
        
        NSError *error = nil;
        
        NSUInteger countFMDB =
        [self.persistenceDelegate countSync:entityName
                                  predicate:nil
                                    options:@{STMPersistingOptionForceStorageFMDB}
                                      error:&error];
        
        NSUInteger countFantoms =
        [self.persistenceDelegate countSync:entityName
                                  predicate:nil
                                    options:@{STMPersistingOptionPhantoms:@YES}
                                      error:&error];
        
        NSLog(@"%@ count: %u%@",
              entityName, countFMDB,
              countFantoms ? [NSString stringWithFormat:@" (+ %@ fantoms)", @(countFantoms)] : @""
              );
        
        totalCountFMDB += countFMDB;
        totalFantoms += countFantoms;
        
    }
    
    NSLog(@"Total count: %u", totalCountFMDB);
    NSLog(@"Fantoms total count: %@", @(totalFantoms));
    
}

@end
