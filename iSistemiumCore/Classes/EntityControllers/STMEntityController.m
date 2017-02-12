//
//  STMEntityController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMEntityController.h"

@interface STMEntityController()

@property (nonatomic, strong) NSArray *entitiesArray;
@property (nonatomic, strong) NSArray *uploadableEntitiesNames;
@property (nonatomic, strong) NSDictionary *stcEntities;

@end


@implementation STMEntityController

+ (STMEntityController *)sharedInstance {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
    
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) [self addObservers];
    return self;
    
}

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(authStateChanged)
               name:@"authControllerStateChanged"
             object:[STMCoreAuthController authController]];

}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)authStateChanged {
    
    if ([STMCoreAuthController authController].controllerState != STMAuthSuccess) {
        [self flushSelf];
    }
    
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
    
    NSArray *names = [self.stcEntitiesArray valueForKeyPath:@"name"];
    __block NSUInteger totalDuplicates = 0;
    
    [names enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL *stop) {
        
        NSPredicate *byName = [NSPredicate predicateWithFormat:@"name == %@", name];
        NSArray *result = [self.stcEntitiesArray filteredArrayUsingPredicate:byName];
        
        if (result.count < 2) return;
        
        totalDuplicates += result.count - 1;
        
        NSArray *sortDescriptors = @[
            [NSSortDescriptor sortDescriptorWithKey:@"isFantom" ascending:NO],
            [NSSortDescriptor sortDescriptorWithKey:@"deviceCts" ascending:NO]
        ];
        
        result = [result sortedArrayUsingDescriptors:sortDescriptors];
        
        NSArray *duplicates = [result subarrayWithRange:NSMakeRange(1, result.count - 1)];

        NSString *message = [NSString stringWithFormat:@"Entity %@ have %@ duplicates", name, @(duplicates.count)];
        [[STMLogger sharedLogger] saveLogMessageWithText:message type:@"error"];

        NSError *error;
        NSPredicate *duplicatesPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", duplicates];
        
        [[self persistenceDelegate] destroyAllSync:STM_ENTITY_NAME
                                         predicate:duplicatesPredicate
                                           options:@{STMPersistingOptionRecordstatuses:@(NO)}
                                             error:&error];
    }];

    if (!totalDuplicates) {
        [[STMLogger sharedLogger] saveLogMessageWithText:@"stc.entity duplicates not found"];
    }

}


@end
