//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

//Note: The calls to FMDatabaseQueue's methods are blocking. So even though you are passing along blocks, they will not be run on another thread.

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
            
            NSString *createIndexFormat = @"CREATE INDEX IF NOT EXISTS FK_%@_%@ on %@ (%@);";
            NSString *fkColFormat = @"%@ TEXT REFERENCES %@(id)";
            NSString *createTableFormat = @"CREATE TABLE IF NOT EXISTS %@ (";
            
            for (NSString* entityName in entityNames){
                
                if ([entityName isEqualToString:@"STMSetting"] || [entityName isEqualToString:@"STMEntity"] ){
                    continue;
                }
                
                NSString *tableName = [self entityToTableName:entityName];
                NSMutableArray *columns = @[].mutableCopy;
                NSString *sql_stmt = [NSString stringWithFormat:createTableFormat, tableName];
                
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
                    
                    NSString *fkColumn = [entityKey stringByAppendingString:@"Id"];
                    NSString *fkTable = [self entityToTableName:[STMCoreObjectsController toOneRelationshipsForEntityName:entityName][entityKey]];
                    NSString *fkSQL = [NSString stringWithFormat:fkColFormat, fkColumn, fkTable];
                    
                    [columns addObject:fkColumn];
                    sql_stmt = [sql_stmt stringByAppendingString:fkSQL];
                }
                
                sql_stmt = [sql_stmt stringByAppendingString:@" ); "];
                columnsDictionary[[self entityToTableName:entityName]] = columns.copy;
 
                [database executeStatements:sql_stmt];
                NSLog(@"%@",sql_stmt);
                
                for (NSString* entityKey in [STMCoreObjectsController toOneRelationshipsForEntityName:entityName].allKeys){
                    NSString *fkColumn = [entityKey stringByAppendingString:@"Id"];
                    
                    NSString *createIndexSQL = [NSString stringWithFormat:createIndexFormat, tableName, entityKey, tableName, fkColumn];
                    NSLog(@"%@", createIndexSQL);
                    [database executeStatements:createIndexSQL];
                }
            }
            columnsByTable = columnsDictionary.copy;
        
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

- (NSDictionary * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary{
    tablename = [self entityToTableName:tablename];
    [queue inDatabase:^(FMDatabase *db) {
        if (![db inTransaction]){
            [db beginTransaction];
        }
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
        
        [db executeUpdate:insertSQL withArgumentsInArray:values];
    }];
    return dictionary;
}

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate{
    name = [self entityToTableName:name];
    NSString* where = @"";
    if (predicate){
        where = [[STMPredicateToSQL sharedInstance] SQLFilterForPredicate:predicate];
        if ([where isEqualToString:@"( )"] || [where isEqualToString:@"()"]){
            where = @"";
        }else{
            where = [@" WHERE " stringByAppendingString:where];
        }
    }
    where = [where stringByReplacingOccurrencesOfString:@"?uncapitalizedTableName?" withString:[STMFunctions lowercaseFirst:name]];
    where = [where stringByReplacingOccurrencesOfString:@"?capitalizedTableName?" withString:name];
    NSMutableArray *rez = @[].mutableCopy;
    [queue inDatabase:^(FMDatabase *db) {
        NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@%@",name,where];
        FMResultSet *s = [db executeQuery:query];
        while ([s next]) {
            [rez addObject:[s resultDictionary]];
        }
    }];
    return rez;
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

- (BOOL)commit{
    __block BOOL result = YES;
    [queue inDatabase:^(FMDatabase *db) {
        if ([db inTransaction]){
            result = [db commit];
        }
    }];
    return result;
}

@end
