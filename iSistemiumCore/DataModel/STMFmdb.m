//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMFmdb.h"
#import "STMFunctions.h"
#import "FMDB.h"
#import "STMCoreObjectsController.h"
#import "STMPredicateToSQL.h"

@implementation STMFmdb

FMDatabase *database;
NSDictionary* columnsByTable;
FMDatabaseQueue *queue;

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray* entityNames = STMCoreObjectsController.document.myManagedObjectModel.entitiesByName.allKeys;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        database = [FMDatabase databaseWithPath:dbPath];
        queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        NSMutableDictionary *columnsDictionary = @{}.mutableCopy;
        
        if ([database open]){
            [database beginTransaction];
            NSString *sql_stmt = @"";
            for (NSString* entityName in entityNames){
                if ([entityName isEqualToString:@"STMSetting"] || [entityName isEqualToString:@"STMEntity"] ){
                    continue;
                }
                NSMutableArray *columns = @[].mutableCopy;
                sql_stmt = [sql_stmt stringByAppendingString:@"CREATE TABLE IF NOT EXISTS "];
                sql_stmt = [sql_stmt stringByAppendingString:[self entityToTableName:entityName]];
                sql_stmt = [sql_stmt stringByAppendingString:@" ("];
                BOOL first = true;
                for (NSString* entityKey in [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName].allKeys){
                    if (first){
                        first = false;
                    }else{
                        sql_stmt = [sql_stmt stringByAppendingString:@", "];
                    }
                    [columns addObject:entityKey];
                    sql_stmt = [sql_stmt stringByAppendingString:entityKey];
                    NSAttributeDescription* atribute= [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName][entityKey];
                    if ([entityKey isEqualToString:@"id"]){
                        sql_stmt = [sql_stmt stringByAppendingString:@" TEXT PRIMARY KEY"];
                        continue;
                    }
                    switch (atribute.attributeType) {
                        case NSStringAttributeType:
                        case NSDateAttributeType:
                        case NSUndefinedAttributeType:
                        case NSBinaryDataAttributeType:
                        case NSTransformableAttributeType:
                            sql_stmt = [sql_stmt stringByAppendingString:@" TEXT"];
                            break;
                        case NSInteger64AttributeType:
                        case NSBooleanAttributeType:
                        case NSObjectIDAttributeType:
                        case NSInteger16AttributeType:
                        case NSInteger32AttributeType:
                            sql_stmt = [sql_stmt stringByAppendingString:@" INTEGER"];
                            break;
                        case NSDecimalAttributeType:
                        case NSFloatAttributeType:
                        case NSDoubleAttributeType:
                            sql_stmt = [sql_stmt stringByAppendingString:@" NUMERIC"];
                            break;
                        default:
                            break;
                    }
                }
                for (NSString* entityKey in [STMCoreObjectsController toOneRelationshipsForEntityName:entityName].allKeys){
                    if (first){
                        first = false;
                    }else{
                        sql_stmt = [sql_stmt stringByAppendingString:@", "];
                    }
                    [columns addObject:[entityKey stringByAppendingString:@"Id"]];
                    sql_stmt = [sql_stmt stringByAppendingString:entityKey];
                    sql_stmt = [sql_stmt stringByAppendingString:@"Id TEXT REFERENCES "];
                    sql_stmt = [sql_stmt stringByAppendingString:[self entityToTableName:[STMCoreObjectsController toOneRelationshipsForEntityName:entityName][entityKey]]];
                    sql_stmt = [sql_stmt stringByAppendingString:@"(id)"];
                }
                sql_stmt = [sql_stmt stringByAppendingString:@" ); "];
                columnsDictionary[[self entityToTableName:entityName]] = columns.copy;
            }
            NSLog(@"%@",sql_stmt);
            columnsByTable = columnsDictionary.copy;
            [database executeStatements:sql_stmt];
            
            [database commit];
            [database close];
        }
    }
    return self;
}

- (NSString *)entityToTableName:(NSString *)entity{
    if ([entity hasPrefix:@"STM"]){
        return [entity substringFromIndex:3];
    }
    return entity ;
}

+ (STMFmdb *)sharedInstance {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
    
}

- (AnyPromise * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename array:(NSArray<NSDictionary<NSString *, id> *> * _Nonnull)array{
    tablename = [self entityToTableName:tablename];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSLog(@"Started inserting %@", tablename);
                NSMutableArray* promises = @[].mutableCopy;
                for (NSDictionary* dict in array){
                    [promises addObject:[self insertWithTablename:tablename dictionary:dict database:db]];
                }
                PMKJoin(promises).then(^(NSArray *resultingValues){
                    resolve(nil);
                }).catch(^(NSError *error){
                    resolve(error);
                });
                NSLog(@"Done inserting %@", tablename);
            }];
        });
    }];
}

- (AnyPromise * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary database:(FMDatabase * _Nonnull)database {
    tablename = [self entityToTableName:tablename];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        NSMutableArray* keys = @[].mutableCopy;
        
        NSMutableArray* values = @[].mutableCopy;
        
        for(NSString* key in dictionary){
            if ([columnsByTable[tablename] containsObject:key]){
                [keys addObject:key];
                [values addObject:[dictionary objectForKey:key]];
            }
        }
        
        [keys addObject:@"lts"];
        [values addObject:[STMFunctions stringFromDate:[NSDate date]]];
        NSMutableArray* v = @[].mutableCopy;
        for (int i=0;i<[keys count];i++){
            [v addObject:@"?"];
        }
        NSString* insertSQL = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) VALUES (%@)",tablename,[keys componentsJoinedByString:@", "], [v componentsJoinedByString:@", "]];
        
        [database executeUpdate:insertSQL withArgumentsInArray:values];
        resolve(nil);
    }];
    
}

- (AnyPromise * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary{
    tablename = [self entityToTableName:tablename];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                [self insertWithTablename:tablename dictionary:dictionary database:db].then(^{
                    resolve(nil);
                });
            }];
        });
    }];
}

-(AnyPromise * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name PK:(NSString * _Nonnull)PK{
    name = [self entityToTableName:name];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *rez = @[].mutableCopy;
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE id = '%@'",name,PK];
                FMResultSet *s = [db executeQuery:query];
                while ([s next]) {
                    [rez addObject:[s resultDictionary]];
                }
                resolve(rez.copy);
            }];
        });
    }];
}

- (AnyPromise * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate{
    NSString* where = [[STMPredicateToSQL sharedInstance] SQLFilterForPredicate:predicate];
    if ([where isEqualToString:@"( )"] || [where isEqualToString:@""] || [where isEqualToString:@"()"]){
        return [self getDataWithEntityName:name];
    }
    name = [self entityToTableName:name];
    where = [where stringByReplacingOccurrencesOfString:@"?uncapitalizedTableName?" withString:[STMFunctions lowercaseFirst:name]];
    where = [where stringByReplacingOccurrencesOfString:@"?capitalizedTableName?" withString:name];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *rez = @[].mutableCopy;
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@",name,where];
                FMResultSet *s = [db executeQuery:query];
                while ([s next]) {
                    [rez addObject:[s resultDictionary]];
                }
                resolve(rez.copy);
            }];
        });
    }];
}

-(AnyPromise * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name{
    name = [self entityToTableName:name];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *rez = @[].mutableCopy;
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                FMResultSet *s = [db executeQuery:[@"SELECT * FROM " stringByAppendingString:name]];
                while ([s next]) {
                    [rez addObject:[s resultDictionary]];
                }
                resolve(rez.copy);
            }];
        });
    }];
}

- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name{
    name = [self entityToTableName:name];
    if ([columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

- (NSArray * _Nonnull) allKeysForObject:(NSString * _Nonnull)obj{
    obj = [self entityToTableName:obj];
    return columnsByTable[obj];
}

@end
