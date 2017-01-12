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

NSDictionary* columnsByTable;
FMDatabaseQueue *queue;


- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray* entityNames = STMCoreObjectsController.document.myManagedObjectModel.entitiesByName.allKeys;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        NSMutableDictionary *columnsDictionary = @{}.mutableCopy;
        
        [queue inDatabase:^(FMDatabase *database){
            
            NSString *createIndexFormat = @"CREATE INDEX IF NOT EXISTS FK_%@_%@ on %@ (%@);";
            NSString *fkColFormat = @"%@ TEXT REFERENCES %@(id)";
            NSString *createTableFormat = @"CREATE TABLE IF NOT EXISTS %@ (";
            NSString *createLtsTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_check_lts BEFORE UPDATE OF lts ON %@ FOR EACH ROW WHEN OLD.deviceTs > OLD.lts BEGIN SELECT RAISE(IGNORE) WHERE OLD.deviceTs <> NEW.lts; END";
            
            for (NSString* entityName in entityNames){
                
                if ([entityName isEqualToString:@"STMSetting"] || [entityName isEqualToString:@"STMEntity"] ){
                    continue;
                }
                
                NSString *tableName = [self entityToTableName:entityName];
                NSMutableArray *columns = @[].mutableCopy;
                NSString *sql_stmt = [NSString stringWithFormat:createTableFormat, tableName];
                
                BOOL first = true;
                
                for (NSString* columnName in [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName].allKeys){
                    
                    if ([columnName isEqualToString:@"xid"]) continue;
                    
                    if (first){
                        first = false;
                    }else{
                        sql_stmt = [sql_stmt stringByAppendingString:@", "];
                    }
                    
                    [columns addObject:columnName];
                    sql_stmt = [sql_stmt stringByAppendingString:columnName];
                    
                    NSAttributeDescription* atribute= [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName][columnName];
                    
                    if ([columnName isEqualToString:@"id"]){
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
                    
                    if ([columnName isEqualToString:@"deviceCts"]) {
                        sql_stmt = [sql_stmt stringByAppendingString:@" DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW'))"];
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
 
                BOOL res = [database executeStatements:sql_stmt];
                NSLog(@"%@ (%@)",sql_stmt, res ? @"YES" : @"NO");
                
                sql_stmt = [NSString stringWithFormat:createLtsTriggerFormat, tableName, tableName];
                
                res = [database executeStatements:sql_stmt];
                NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");

                
                for (NSString* entityKey in [STMCoreObjectsController toOneRelationshipsForEntityName:entityName].allKeys){
                    NSString *fkColumn = [entityKey stringByAppendingString:@"Id"];
                    
                    NSString *createIndexSQL = [NSString stringWithFormat:createIndexFormat, tableName, entityKey, tableName, fkColumn];
                    res = [database executeStatements:createIndexSQL];
                    NSLog(@"%@ (%@)", createIndexSQL, res ? @"YES" : @"NO");
                    
                }
            }
            columnsByTable = columnsDictionary.copy;
        
        }];
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

- (NSDictionary * _Nonnull)mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary{
#warning need to handle errors
    tablename = [self entityToTableName:tablename];
    
    NSArray *columns = columnsByTable[tablename];
    NSString *pk = dictionary [@"id"];
    
    [queue inDatabase:^(FMDatabase *db) {
        
        NSMutableArray* keys = @[].mutableCopy;
        NSMutableArray* values = @[].mutableCopy;
        
        for(NSString* key in dictionary){
            if ([columns containsObject:key] && ![key isEqualToString:@"id"]){
                [keys addObject:key];
                [values addObject:[dictionary objectForKey:key]];
            }
        }
        
        [values addObject:pk];
        
        NSMutableArray* v = @[].mutableCopy;
        for (int i=0;i<[keys count];i++){
            [v addObject:@"?"];
        }
        
        NSString* updateSQL = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? WHERE id = ?", tablename, [keys componentsJoinedByString:@" = ?, "]];
        
        [db executeUpdate:updateSQL withArgumentsInArray:values];
        
        #warning need to check if the update was ignored or errored then don't insert
        
        if (!db.changes) {
            NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@, id) VALUES(%@, ?)", tablename, [keys componentsJoinedByString:@", "], [v componentsJoinedByString:@", "]];
            [db executeUpdate:insertSQL withArgumentsInArray:values];
        }
        
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

- (BOOL)startTransaction{
    __block BOOL result = YES;
    [queue inDatabase:^(FMDatabase *db){
        if (![db inTransaction]){
            result = [db beginTransaction];
        }
    }];
    return result;
}
     
- (BOOL)roleback{
    __block BOOL result = YES;
    [queue inDatabase:^(FMDatabase *db){
        [db rollback];
    }];
    return result;
}

@end
