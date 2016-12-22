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

@implementation STMFmdb

FMDatabase *database;
NSArray* tableNames;
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
        
        if ([database open]){
            [database beginTransaction];
            NSString *sql_stmt = @"CREATE TABLE IF NOT EXISTS STMPrice (id TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, price NUMERIC, articleId TEXT REFERENCES STMArticle(id), priceTypeId TEXT REFERENCES STMPriceType(id) ) ";
            for (NSString* entityName in entityNames){
                sql_stmt = [sql_stmt stringByAppendingString:@"CREATE TABLE IF NOT EXISTS "];
                sql_stmt = [sql_stmt stringByAppendingString:entityName];
                sql_stmt = [sql_stmt stringByAppendingString:@" ("];
                NSLog(@"TableName %@", entityName);
                NSArray* keys = [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName].allKeys;
                for (NSString* entityKey in keys){
                    NSAttributeDescription* atribute= [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName][entityKey];
                    switch (atribute.attributeType) {
                        case NSStringAttributeType:

                            break;
                            
                        default:
                            break;
                    }
                }
            }
            [database executeStatements:sql_stmt];
            
            NSMutableArray* names = @[].mutableCopy;
            sql_stmt = @"SELECT name FROM sqlite_master WHERE type='table'";
            FMResultSet* rs =[database executeQuery:sql_stmt];
            while ([rs next]) {
                [names addObject:[rs stringForColumn:@"name"]];
            }
            tableNames = names;
            [database commit];
            [database close];
        }
    }
    return self;
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
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
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
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        NSMutableArray* keys = @[].mutableCopy;
        
        NSMutableArray* values = @[].mutableCopy;
        
        for(NSString* key in dictionary){
            NSString* keyWithoutId = [key substringToIndex:[key length] - 2];
            if ([[STMCoreObjectsController allObjectsWithTypeForEntityName:tablename].allKeys containsObject:key] || [[STMCoreObjectsController toOneRelationshipsForEntityName:tablename].allKeys containsObject:keyWithoutId]){
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
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [self insertWithTablename:tablename dictionary:dictionary database:db].then(^{
                resolve(nil);
            });
        }];
    }];
}

-(AnyPromise * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name{
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve){
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSMutableArray *rez = @[].mutableCopy;
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                FMResultSet *s = [db executeQuery:[@"SELECT * FROM " stringByAppendingString:name]];
                while ([s next]) {
                    [rez addObject:[s resultDictionary]];
                }
                resolve(rez);
            }];
        });
    }];
    
    
    
    
}

- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name{
    if ([tableNames containsObject:name]){
        return true;
    }
    return false;
}

@end
