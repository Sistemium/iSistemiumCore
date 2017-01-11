//
//  STMSyncerHelper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncerHelper.h"

#import "STMCoreObjectsController.h"
#import "STMEntityController.h"


@interface STMSyncerHelper() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSArray <STMDatum *> *unsyncedObjectsArray;
@property (nonatomic, strong) NSMutableArray *resultsControllers;


@end


@implementation STMSyncerHelper

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)customInit {
    [self reloadResultsControllers];
}


#pragma mark - NSFetchedResultsController

- (void)reloadResultsControllers {
    
    self.resultsControllers = nil;
    [self performFetches];
    
}

- (void)performFetches {
    
    NSArray *entityNamesForSending = [STMEntityController uploadableEntitiesNames];
    
    self.resultsControllers = @[].mutableCopy;
    
    for (NSString *entityName in entityNamesForSending) {
        
        NSFetchedResultsController *rc = [self resultsControllerForEntityName:entityName];
        
        if (rc) {
            
            [self.resultsControllers addObject:rc];
            [rc performFetch:nil];
            
        }
        
    }
    
}

- (nullable NSFetchedResultsController *)resultsControllerForEntityName:(NSString *)entityName {
    
    if ([[STMCoreObjectsController localDataModelEntityNames] containsObject:entityName]) {
        
        STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:entityName];
        
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id"
                                                                  ascending:YES
                                                                   selector:@selector(compare:)]];
        request.includesSubentities = YES;
        
        NSMutableArray *subpredicates = @[].mutableCopy;
        
        if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
            
            NSArray *logMessageSyncTypes = [[STMLogger sharedLogger] syncingTypesForSettingType:[self uploadLogType]];
            
            [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
            
        }
        
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"(lts == %@ || deviceTs > lts)", nil]];
        
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
        
        NSManagedObjectContext *context = [STMCoreObjectsController document].managedObjectContext;
        
        NSFetchedResultsController *rc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                             managedObjectContext:context
                                                                               sectionNameKeyPath:nil
                                                                                        cacheName:nil];
        rc.delegate = self;
        
        return rc;
        
    } else {
        
        return nil;
        
    }
    
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_DID_CHANGE_CONTENT
                                                        object:self];
    
//    self.controllersDidChangeContent = YES;
    
}

- (NSString *)uploadLogType {
    
    NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                       forGroup:@"syncer"];
    return uploadLogType;
    
}

- (NSArray <STMDatum *> *)unsyncedObjectsArray {
    
    if (!_unsyncedObjectsArray) {
        
        NSArray <STMDatum *> *fetchedObjects = [self.resultsControllers valueForKeyPath:@"@distinctUnionOfArrays.fetchedObjects"];
        _unsyncedObjectsArray = (fetchedObjects.count > 0) ? fetchedObjects : nil;
        
    }
    return _unsyncedObjectsArray;
    
}


@end
