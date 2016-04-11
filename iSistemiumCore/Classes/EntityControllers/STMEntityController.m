//
//  STMEntityController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMEntityController.h"
#import "STMObjectsController.h"

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
             object:[STMAuthController authController]];

}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)authStateChanged {
    
    if ([STMAuthController authController].controllerState != STMAuthSuccess) {
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
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMEntity class])];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]];
        request.predicate = [STMPredicate predicateWithNoFantoms];
        
        NSError *error;
        NSArray *result = [[STMEntityController document].managedObjectContext executeFetchRequest:request error:&error];

        _entitiesArray = (result.count > 0) ? result : nil;

    }
    return _entitiesArray;
    
}

- (NSDictionary *)stcEntities {
    
    if (!_stcEntities) {
        
        NSMutableDictionary *stcEntities = [NSMutableDictionary dictionary];
        
        NSArray *stcEntitiesArray = self.entitiesArray.copy;
        
        for (STMEntity *entity in stcEntitiesArray) {
            
            NSString *capFirstLetter = (entity.name) ? [[entity.name substringToIndex:1] capitalizedString] : nil;
            
            NSString *capEntityName = [entity.name stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:capFirstLetter];
            
            if (capEntityName) {
                stcEntities[[ISISTEMIUM_PREFIX stringByAppendingString:capEntityName]] = entity;
            }
            
        }
        
        _stcEntities = (stcEntities.count > 0) ? stcEntities : nil;

    }
    return _stcEntities;
    
}

- (NSArray *)uploadableEntitiesNames {
    
    if (!_uploadableEntitiesNames) {
        
        NSMutableDictionary *stcEntities = [self.stcEntities mutableCopy];
        
        NSSet *filteredKeys = [stcEntities keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
            return ([[obj valueForKey:@"isUploadable"] boolValue] == YES);
        }];
        
        _uploadableEntitiesNames = filteredKeys.allObjects;

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

+ (NSSet *)entityNamesWithLifeTime {
    
    NSMutableDictionary *stcEntities = [[self stcEntities] mutableCopy];
    
    NSSet *filteredKeys = [stcEntities keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ([[obj valueForKey:@"lifeTime"] doubleValue] > 0);
    }];
    
    return filteredKeys;
    
}

+ (NSArray *)entitiesWithLifeTime {
    
    NSArray *stcEntitiesArray = [self stcEntitiesArray];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lifeTime.intValue > 0"];
    NSArray *result = [stcEntitiesArray filteredArrayUsingPredicate:predicate];
    
    return result;
    
}

+ (STMEntity *)entityWithName:(NSString *)name {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMEntity class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    
    NSError *error;
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    return [result lastObject];
    
}

+ (void)deleteEntityWithName:(NSString *)name {
    
    __weak STMEntity *entityToDelete = ([self stcEntities])[name];
    
    if (entityToDelete) {
        
        __weak NSManagedObjectContext *context = entityToDelete.managedObjectContext;
        
        [context performBlock:^{
            
            [context deleteObject:entityToDelete];
            
        }];
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"where is no entity with name %@ to delete", name];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage];
        
    }
    
}

+ (void)checkEntitiesForDuplicates {
    
/* next two lines is for generating duplicates
 
    NSArray *entitiesArray = [self stcEntitiesArray];
    NSLog(@"entitiesArray.count %d", entitiesArray.count);
 
*/
    NSString *entityName = NSStringFromClass([STMEntity class]);
    NSString *property = @"name";
    
    STMEntityDescription *entity = [STMEntityDescription entityForName:entityName inManagedObjectContext:self.document.managedObjectContext];
    
    NSPropertyDescription *entityProperty = entity.propertiesByName[property];
    
    if (entityProperty) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
        
        NSExpression *expression = [NSExpression expressionForKeyPath:property];
        NSExpression *countExpression = [NSExpression expressionForFunction:@"count:" arguments:@[expression]];
        NSExpressionDescription *ed = [[NSExpressionDescription alloc] init];
        ed.expression = countExpression;
        ed.expressionResultType = NSInteger64AttributeType;
        ed.name = @"count";
        
        request.propertiesToFetch = @[entityProperty, ed];
        request.propertiesToGroupBy = @[entityProperty];
        request.resultType = NSDictionaryResultType;
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:property ascending:YES]];
        
        NSArray *result = [self.document.managedObjectContext executeFetchRequest:request error:nil];
        
        result = [result filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"count > 1"]];

        if (result.count > 0) {
            
            for (NSDictionary *entity in result) {
                
                NSString *message = [NSString stringWithFormat:@"Entity %@ have %@ duplicates", entity[property], entity[ed.name]];
                [[STMLogger sharedLogger] saveLogMessageWithText:message type:@"error"];
                
                [self removeDuplicatesWithName:entity[property]];
                
            }
            
        } else {
            [[STMLogger sharedLogger] saveLogMessageWithText:@"stc.entity duplicates not found"];
        }
        
    }
    
}

+ (void)removeDuplicatesWithName:(NSString *)name {
    
    NSLog(@"remove entity duplicates for %@", name);
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMEntity class])];
    
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"deviceCts" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    
    NSError *error;
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    STMEntity *actualEntity = [result lastObject];
    NSMutableArray *mutableResult = result.mutableCopy;
    [mutableResult removeObject:actualEntity];
    
    for (STMEntity *entity in mutableResult) {
        [STMObjectsController removeObject:entity];
    }
    
    [[self document] saveDocument:^(BOOL success) {}];
    
}


@end
