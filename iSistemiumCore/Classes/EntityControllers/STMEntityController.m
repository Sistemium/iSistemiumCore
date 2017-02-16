//
//  STMEntityController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMEntityController.h"

#define STMEC_HAS_CHANGES @"STMEntityController has changes"

@interface STMEntityController()

@property (nonatomic, strong) NSArray *entitiesArray;
@property (nonatomic, strong) NSArray *uploadableEntitiesNames;
@property (nonatomic, strong) NSDictionary *stcEntities;

@property (nonatomic, strong) STMPersistingObservingSubscriptionID entitySubscriptionID;

+ (STMEntityController *)sharedInstance;

@end


@implementation STMEntityController

+ (STMEntityController *)sharedInstance {
    return [super sharedInstance];
}

- (instancetype)init {
    
    self = [super init];
    [self addObservers];
    
    NSLogMethodName;
    return self;
    
}

- (void)addObservers {
    
    self.entitySubscriptionID = [self.class.persistenceDelegate observeEntity:STM_ENTITY_NAME predicate:nil callback:^(NSArray *data) {
        
        [self flushSelf];
        [self postNotificationName:STMEC_HAS_CHANGES];
        
        NSLog(@"checkStcEntities got called back with %@ items", @(data.count));
        
    }];

}

- (void)removeObservers {
    [self.class.persistenceDelegate cancelSubscription:self.entitySubscriptionID];
    self.entitySubscriptionID = nil;
    [super removeObservers];
}

+ (void)addChangesObserver:(STMCoreObject *)anObject selector:(SEL)selector {
    [[self sharedInstance] addObserver:anObject selector:selector name:STMEC_HAS_CHANGES];
}


- (void)flushSelf {
    
    self.entitiesArray = nil;
    self.uploadableEntitiesNames = nil;
    self.stcEntities = nil;
    
}

- (NSArray *)entitiesArray {
    
    if (!_entitiesArray) {
        
        NSError *error;
        NSDictionary *options = @{STMPersistingOptionOrder:@"name"};
        NSArray *result = [self.class.persistenceDelegate findAllSync:STM_ENTITY_NAME
                                                            predicate:nil
                                                              options:options
                                                                error:&error];

        result = [STMFunctions mapArray:result withBlock:^id _Nonnull(id  _Nonnull value) {
            STMEntity *entity = (STMEntity *)[[self.class persistenceDelegate] newObjectForEntityName:STM_ENTITY_NAME];
            [[self.class persistenceDelegate] setObjectData:value toObject:entity];
            return entity;
        }];
        
        _entitiesArray = (result.count > 0) ? result : nil;

    }
    return _entitiesArray;
    
}

- (NSDictionary *)stcEntities {
    
    if (!_stcEntities) {
        
        NSMutableDictionary *stcEntities = [NSMutableDictionary dictionary];
        
        for (STMEntity *entity in self.entitiesArray) {
            
            NSString *capFirstLetter = (entity.name) ? [[entity.name substringToIndex:1] capitalizedString] : nil;
            
            NSString *capEntityName = [entity.name stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                                                           withString:capFirstLetter];
            
            if (capEntityName) {
                stcEntities[[STMFunctions addPrefixToEntityName:capEntityName]] = entity;
            }
            
        }
        
        _stcEntities = (stcEntities.count > 0) ? stcEntities : nil;

    }
    return _stcEntities;
    
}

- (NSArray *)uploadableEntitiesNames {
    
    if (!_uploadableEntitiesNames) {
        
        NSSet *filteredKeys = [self.stcEntities keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
            return ([[obj valueForKey:@"isUploadable"] boolValue] == YES);
        }];
        
        _uploadableEntitiesNames = [filteredKeys sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:nil ascending:YES]]];

    }
    return _uploadableEntitiesNames;
    
}


#pragma mark - class methods

+ (void)flushSelf {
    [[self sharedInstance] flushSelf];
}

+ (NSDictionary *)stcEntities {
    return [self sharedInstance].stcEntities;
}

+ (NSArray *)stcEntitiesArray {
    return [self sharedInstance].entitiesArray;
}

+ (NSArray *)uploadableEntitiesNames {
    return [self sharedInstance].uploadableEntitiesNames;
}

+ (NSArray *)entityNamesWithResolveFantoms {
    
    NSSet *filteredKeys = [self.stcEntities keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ([[obj valueForKey:@"isResolveFantoms"] boolValue] && [obj valueForKey:@"url"] != nil);
    }];
    
    return [filteredKeys sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:nil ascending:YES]]];
    
}

+ (NSSet *)entityNamesWithLifeTime {
    
    NSSet *filteredKeys = [self.stcEntities keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ([[obj valueForKey:@"lifeTime"] doubleValue] > 0);
    }];
    
    return filteredKeys;
    
}

+ (NSArray *)entitiesWithLifeTime {
    
    NSError *error;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lifeTime.intValue > 0"];
    
    return [self.persistenceDelegate findAllSync:STM_ENTITY_NAME
                                       predicate:predicate
                                         options:nil
                                           error:&error];
    
}

+ (NSDictionary *)entityWithName:(NSString *)name {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    NSError *error = nil;
    NSDictionary *entity = [[self persistenceDelegate] findAllSync:NSStringFromClass([STMEntity class])
                                                         predicate:predicate
                                                           options:nil
                                                             error:&error].lastObject;
    
    return entity;
        
}

+ (void)checkEntitiesForDuplicates {
    
    NSArray *names = [[self stcEntitiesArray] valueForKeyPath:@"name"];
    __block NSUInteger totalDuplicates = 0;
    
    [names enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL *stop) {
        
        NSPredicate *byName = [NSPredicate predicateWithFormat:@"name == %@", name];
        NSArray *result = [[self stcEntitiesArray] filteredArrayUsingPredicate:byName];
        
        if (result.count < 2) return;
        
        totalDuplicates += result.count - 1;
        
        NSArray *sortDescriptors = @[
            [NSSortDescriptor sortDescriptorWithKey:@"isFantom" ascending:NO],
            [NSSortDescriptor sortDescriptorWithKey:@"deviceCts" ascending:NO]
        ];
        
        result = [result sortedArrayUsingDescriptors:sortDescriptors];
        
        NSArray *duplicates = [result subarrayWithRange:NSMakeRange(1, result.count - 1)];

        NSString *message = [NSString stringWithFormat:@"Entity %@ have %@ duplicates", name, @(duplicates.count)];
        [self.session.logger saveLogMessageWithText:message type:@"error"];

        NSError *error;
        NSPredicate *duplicatesPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", duplicates];

        NSMutableArray *newStcEntitiesArray = [self stcEntitiesArray].mutableCopy;
        [newStcEntitiesArray removeObjectsInArray:duplicates];
        [self sharedInstance].entitiesArray = newStcEntitiesArray;

        [[self persistenceDelegate] destroyAllSync:STM_ENTITY_NAME
                                         predicate:duplicatesPredicate
                                           options:@{STMPersistingOptionRecordstatuses:@(NO)}
                                             error:&error];
        
    }];

    if (!totalDuplicates) {
        [self.session.logger saveLogMessageWithText:@"stc.entity duplicates not found"];
    }

}


@end
