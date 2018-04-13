//
//  STMRemotePersisterController.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 28/06/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMRemotePersisterController.h"
#import "STMPersister.h"
#import "STMFmdb+Private.h"
#import "STMFmdbSchema.h"

@implementation STMRemotePersisterController

+ (NSArray *)findAllRemote:(NSDictionary *)data {

    NSError *error = nil;

    NSString *entityName = data[@"entityName"];

    NSString *predicateFormat = data[@"predicateFormat"];

    NSDictionary *options = data[@"options"];

    NSPredicate *predicate = predicateFormat ? [NSPredicate predicateWithFormat:predicateFormat] : nil;

    NSArray *response = nil;

    if (!entityName) {
        [STMFunctions error:&error withMessage:@"No entity name given"];
    } else {
        response = [self.persistenceDelegate findAllSync:entityName predicate:predicate options:options error:&error];
    }

    if (error) {

        [NSException raise:@"findAllRemote exception" format:@"%@", [error localizedDescription]];

    }

    return response;

}

+ (NSNumber *)countRemote:(NSDictionary *)data {

    NSError *error = nil;

    NSString *entityName = data[@"entityName"];

    NSString *predicateFormat = data[@"predicateFormat"];

    NSDictionary *options = data[@"options"];

    NSPredicate *predicate = predicateFormat ? [NSPredicate predicateWithFormat:predicateFormat] : nil;

    NSNumber *response = 0;

    if (!entityName) {
        [STMFunctions error:&error withMessage:@"No entity name given"];
    } else {
        response = [NSNumber numberWithUnsignedInteger:[self.persistenceDelegate countSync:entityName predicate:predicate options:options error:&error]];
    }

    if (error) {

        [NSException raise:@"findAllRemote exception" format:@"%@", [error localizedDescription]];

    }

    return response;

}

+ (NSString *)destroyAllRemote:(NSDictionary *)data {

    NSError *error = nil;

    NSString *entityName = data[@"entityName"];

    NSString *predicateFormat = data[@"predicateFormat"];

    NSDictionary *options = data[@"options"];

    NSPredicate *predicate = predicateFormat ? [NSPredicate predicateWithFormat:predicateFormat] : nil;

    NSUInteger response = 0;

    if (!entityName) {
        [STMFunctions error:&error withMessage:@"No entity name given"];
    } else {
        response = [self.persistenceDelegate destroyAllSync:entityName predicate:predicate options:options error:&error];
    }

    if (error) {

        [NSException raise:@"findAllRemote exception" format:@"%@", [error localizedDescription]];

    }

    return [NSString stringWithFormat:@"%lu rows deleted", (unsigned long) response];

}

+ (NSArray *)syncFMDB {

    NSMutableArray *result = @[].mutableCopy;

    STMPersister *persister = (STMPersister *) self.persistenceDelegate;

    STMFmdb *fmdb = (STMFmdb *) persister.runner.adapters[@(STMStorageTypeFMDB)];

    NSManagedObjectModel *managedObjectModel = self.persistenceDelegate.managedObjectModel;

    STMFmdbSchema *schema = [STMFmdbSchema fmdbSchemaForDatabase:fmdb.database];

    for (NSEntityDescription *entity in managedObjectModel.entities) {

        NSString *tableName = [STMFunctions removePrefixFromEntityName:entity.name];

        if (![fmdb.database tableExists:tableName]) {

            [schema addEntity:entity];
            [result addObject:entity.name];

        } else {
            NSLog(@"%@ not exists", tableName);
        }
    }

    return result;

}


@end
