//
//  STMPersister+CoreData.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 26/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "STMPersister+CoreData.h"
#import "STMFunctions.h"

#import "STMEntityDescription.h"
#import "STMPredicate.h"
#import "STMCoreObjectsController.h"
#import "STMEntityController.h"
#import "STMRecordStatusController.h"


@implementation STMPersister (CoreData)

#pragma mark - Private CoreData helpers

- (NSDictionary *)mergeWithoutSave:entityName
                        attributes:(NSDictionary *)attributes
                           options:(NSDictionary *)options
                             error:(NSError **)error
            inManagedObjectContext:(NSManagedObjectContext *)context {
    
    if (options[@"roleName"]) {
        
        BOOL success = [STMCoreObjectsController setRelationshipFromDictionary:attributes];
        if (!success) {
            [STMFunctions error:error
                    withMessage:[NSString stringWithFormat:@"Relationship error %@", entityName]];
        }
        
    } else {
        
        id object = [self insertObjectFromDictionary:attributes
                                      withEntityName:entityName];
        if (!object) {
            [STMFunctions error:error
                    withMessage:[NSString stringWithFormat:@"Error inserting %@", entityName]];
        }
        
    }
    
    return attributes;

}


- (void)removeObjects:(NSArray*)objects {
    for (id object in objects){
        [self.document.managedObjectContext deleteObject:object];
    }
}

- (void)removeObjectForPredicate:(NSPredicate*)predicate entityName:(NSString *)name{
    name = [STMFunctions addPrefixToEntityName:name];
    [self removeObjects:[self objectsForPredicate:predicate entityName:name]];
}

- (NSArray *)objectsForPredicate:(NSPredicate *)predicate entityName:(NSString *)entityName {
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    
    //    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = predicate;
    
    return [self.document.managedObjectContext executeFetchRequest:request error:nil];
    
}

- (NSArray *)objectsForEntityName:(NSString *)entityName {
    
    return [self objectsForEntityName:entityName
                              orderBy:@"id"
                            ascending:YES
                           fetchLimit:0
                          withFantoms:NO
               inManagedObjectContext:[self document].managedObjectContext
                                error:nil];
    
}

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit withFantoms:(BOOL)withFantoms inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {
    
    return [self objectsForEntityName:entityName
                              orderBy:orderBy
                            ascending:ascending
                           fetchLimit:fetchLimit
                          fetchOffset:0
                          withFantoms:withFantoms
               inManagedObjectContext:context
                                error:error];
    
}

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {
    
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

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms predicate:(NSPredicate *)predicate inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error {
    
    return [self objectsForEntityName:entityName
                              orderBy:orderBy
                            ascending:ascending
                           fetchLimit:fetchLimit
                          fetchOffset:fetchOffset
                          withFantoms:withFantoms
                            predicate:nil
                           resultType:NSManagedObjectResultType
               inManagedObjectContext:context
                                error:error];
    
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

- (STMDatum *)insertObjectFromDictionary:(NSDictionary *)dictionary withEntityName:(NSString *)entityName {
    
    NSArray *dataModelEntityNames = [STMCoreObjectsController localDataModelEntityNames];
    
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
        
        if (!object && xidData) object = [STMCoreObjectsController objectFindOrCreateForEntityName:entityName 
                                                                                            andXid:xidData];
        
        NSDictionary *recordStatus = [STMRecordStatusController existingRecordStatusForXid:xidString];
        
        if (!(![recordStatus[@"isRemoved"] isEqual:[NSNull null]] ? [recordStatus[@"isRemoved"] boolValue]: false)) {
            
            if (!object) object = [STMCoreObjectsController newObjectForEntityName:entityName];
            
            if (![object isWaitingToSync]) {
                
                [object setValue:@NO forKey:@"isFantom"];
                [STMCoreObjectsController processingOfObject:object
                                              withEntityName:entityName
                                              fillWithValues:dictionary];
                
            }
            
        }
        
        return object;
        
    } else {
        
        NSLog(@"dataModel have no object's entity with name %@", entityName);
        
        return nil;
        
    }
    
}


@end
