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
FMDatabasePool *pool;


- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        NSArray *entityNames = STMCoreObjectsController.document.myManagedObjectModel.entitiesByName.allKeys;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        
        queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        pool = [FMDatabasePool databasePoolWithPath:dbPath];
        
        NSMutableDictionary *columnsDictionary = @{}.mutableCopy;
        
        [queue inDatabase:^(FMDatabase *database){
            
            NSString *createIndexFormat = @"CREATE INDEX IF NOT EXISTS FK_%@_%@ on %@ (%@);";
            NSString *fkColFormat = @"%@ TEXT REFERENCES %@(id) ON DELETE %@";
            NSString *createTableFormat = @"CREATE TABLE IF NOT EXISTS %@ (";
            NSString *createLtsTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_check_lts BEFORE UPDATE OF lts ON %@ FOR EACH ROW WHEN OLD.deviceTs > OLD.lts BEGIN SELECT RAISE(ABORT, 'ignored') WHERE OLD.deviceTs <> NEW.lts; END";
            
            NSString *createFantomTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_fantom_%@ BEFORE INSERT ON %@ FOR EACH ROW WHEN NEW.%@ is not null BEGIN INSERT INTO %@ (id, isFantom, lts, deviceTs) SELECT NEW.%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %@ WHERE id = NEW.%@); END";
            NSString *updateFantomTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_fantom_%@_update BEFORE UPDATE OF %@ ON %@ FOR EACH ROW WHEN NEW.%@ is not null BEGIN INSERT INTO %@ (id, isFantom, lts, deviceTs) SELECT NEW.%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %@ WHERE id = NEW.%@); END";
            NSString *fantomIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_isFantom on %@ (isFantom);";
            
            NSString *createCascadeTriggerFormat = @"DROP TRIGGER IF EXISTS %@_cascade_%@; CREATE TRIGGER IF NOT EXISTS %@_cascade_%@ BEFORE DELETE ON %@ FOR EACH ROW BEGIN DELETE FROM %@ WHERE %@ = OLD.id; END";
            
            NSString *isRemovedTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_isRemoved BEFORE INSERT ON %@ FOR EACH ROW BEGIN SELECT RAISE(IGNORE) FROM RecordStatus WHERE isRemoved = 1 AND objectXid = NEW.id LIMIT 1; END";
            
            
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
                    if ([columnName isEqualToString:@"lts"]) {
                        sql_stmt = [sql_stmt stringByAppendingString:@" DEFAULT('')"];
                    }
                }
                
                NSDictionary *relationships = [STMCoreObjectsController toOneRelationshipsForEntityName:entityName];
                
                for (NSString* entityKey in relationships.allKeys){
                    if (first){
                        first = false;
                    }else{
                        sql_stmt = [sql_stmt stringByAppendingString:@", "];
                    }
                    
                    NSString *fkColumn = [entityKey stringByAppendingString:RELATIONSHIP_SUFFIX];
                    NSString *fkTable = [self entityToTableName:[STMCoreObjectsController toOneRelationshipsForEntityName:entityName][entityKey]];
                    
                    NSString *cascadeAction = @"SET NULL";
                    NSString *fkSQL = [NSString stringWithFormat:fkColFormat, fkColumn, fkTable, cascadeAction];
                    
                    [columns addObject:fkColumn];
                    sql_stmt = [sql_stmt stringByAppendingString:fkSQL];
                }
                
                sql_stmt = [sql_stmt stringByAppendingString:@" ); "];
                columnsDictionary[[self entityToTableName:entityName]] = columns.copy;
 
                BOOL res = [database executeStatements:sql_stmt];
                NSLog(@"%@ (%@)",sql_stmt, res ? @"YES" : @"NO");
                
                sql_stmt = [NSString stringWithFormat:fantomIndexFormat, tableName, tableName];
                res = [database executeStatements:sql_stmt];
                NSLog(@"%@ (%@)",sql_stmt, res ? @"YES" : @"NO");

                sql_stmt = [NSString stringWithFormat:createLtsTriggerFormat, tableName, tableName, tableName];
                
                res = [database executeStatements:sql_stmt];
                NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");
                
                sql_stmt = [NSString stringWithFormat:isRemovedTriggerFormat, tableName, tableName];
                
                res = [database executeStatements:sql_stmt];
                NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");
                
                
                for (NSString* entityKey in [STMCoreObjectsController toOneRelationshipsForEntityName:entityName].allKeys){
                    NSString *fkColumn = [entityKey stringByAppendingString:RELATIONSHIP_SUFFIX];
                    
                    NSString *createIndexSQL = [NSString stringWithFormat:createIndexFormat, tableName, entityKey, tableName, fkColumn];
                    res = [database executeStatements:createIndexSQL];
                    NSLog(@"%@ (%@)", createIndexSQL, res ? @"YES" : @"NO");
                    
                    NSString *fkTable = [self entityToTableName:[STMCoreObjectsController toOneRelationshipsForEntityName:entityName][entityKey]];
                    
                    sql_stmt = [NSString stringWithFormat:createFantomTriggerFormat, tableName, fkColumn, tableName, fkColumn, fkTable, fkColumn, fkTable, fkColumn];
                    res = [database executeStatements:sql_stmt];
                    NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");
                    
                    sql_stmt = [NSString stringWithFormat:updateFantomTriggerFormat, tableName, fkColumn, fkColumn, tableName, fkColumn, fkTable, fkColumn, fkTable, fkColumn];
                    res = [database executeStatements:sql_stmt];
                    NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");
                    
                }
                
                NSDictionary <NSString *, NSRelationshipDescription*> *cascadeRelations = [STMCoreObjectsController objectRelationshipsForEntityName:entityName isToMany:@(YES) cascade:true];
                
                for (NSString* relationKey in cascadeRelations.allKeys){
                    
                    NSRelationshipDescription *relation = cascadeRelations[relationKey];
                    NSString *childTableName = [self entityToTableName:relation.destinationEntity.name];
                    NSString *fkColumn = [relation.inverseRelationship.name stringByAppendingString:@"Id"];
                    
                    sql_stmt = [NSString stringWithFormat:createCascadeTriggerFormat, tableName, relationKey,tableName, relationKey,tableName, childTableName, fkColumn];
                    res = [database executeStatements:sql_stmt];
                    NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");
                    
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

- (NSDictionary * _Nullable)mergeIntoAndResponse:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error{
    
    __block NSDictionary *response;
    
    [queue inDatabase:^(FMDatabase *db) {
        
        NSString *pk = [self mergeInto:tablename dictionary:dictionary error:error db:db];
        
        if (!pk) return;
        
        NSArray *results = [self getDataWithEntityName:tablename
                                         withPredicate:[NSPredicate predicateWithFormat:@"id == %@", pk]
                                               orderBy:nil
                                            fetchLimit:0
                                           fetchOffset:0
                                                    db:db];
        
        response = [results firstObject];
        
    }];
    
    return response;
    
}

- (BOOL) mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error {
    
    __block BOOL result;
    
    [queue inDatabase:^(FMDatabase *db) {
        result = !![self mergeInto:tablename
                        dictionary:dictionary
                             error:error
                                db:db];
    }];
    
    return result;
}

- (NSString *) mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error db:(FMDatabase *)db{
    
    tablename = [self entityToTableName:tablename];
    
    NSArray *columns = columnsByTable[tablename];
    NSString *pk = dictionary [@"id"] ? dictionary [@"id"] : [[[NSUUID alloc] init].UUIDString lowercaseString];
    
    NSMutableArray* keys = @[].mutableCopy;
    NSMutableArray* values = @[].mutableCopy;
    
    for(NSString* key in dictionary){
        if ([columns containsObject:key] && ![@[@"id", @"isFantom"] containsObject:key]){
            [keys addObject:key];
            id value = [dictionary objectForKey:key];
            if ([value isKindOfClass:[NSDate class]]) {
                [values addObject:[STMFunctions stringFromDate:(NSDate *)value]];
            } else {
                [values addObject:(NSString*)value];
            }
            
        }
    }
    
    [values addObject:pk];
    
    NSMutableArray* v = @[].mutableCopy;
    for (int i=0;i<[keys count];i++){
        [v addObject:@"?"];
    }
    
    NSString* updateSQL = [NSString stringWithFormat:@"UPDATE %@ SET isFantom = 0, %@ = ? WHERE id = ?", tablename, [keys componentsJoinedByString:@" = ?, "]];
    
    if(![db executeUpdate:updateSQL values:values error:error]){
        if ([[*error localizedDescription] isEqualToString:@"ignored"]){
            *error = nil;
            return pk;
        } else{
            return nil;
        }
    }
    
    if (!db.changes) {
        NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@, isFantom, id) VALUES(%@, 0, ?)", tablename, [keys componentsJoinedByString:@", "], [v componentsJoinedByString:@", "]];
        if (![db executeUpdate:insertSQL values:values error:error]){
            return nil;
        }
    }

    return pk;
}

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset{
    
    __block NSArray* results;
    
    [pool inDatabase:^(FMDatabase *db) {
    
        results = [self getDataWithEntityName:name
                                withPredicate:predicate
                                      orderBy:orderBy
                                   fetchLimit:fetchLimit
                                  fetchOffset:fetchOffset
                                           db:db];
    
    }];
    
    return results;
}

<<<<<<< HEAD
- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset db:(FMDatabase *)db {
=======
- (BOOL)destroy:(NSString * _Nonnull)tablename identifier:(NSString*  _Nonnull)idendifier error:(NSError *_Nonnull * _Nonnull)error{
    
    __block BOOL result = YES;
    
    NSString* destroySQL = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id=?", [self entityToTableName:tablename]];
    
    NSArray* values = @[idendifier];
    
    [queue inDatabase:^(FMDatabase *db) {
        if(![db executeUpdate:destroySQL values:values error:error]){
            result = NO;
        }
    }];
    
    return result;
}

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy fetchLimit:(NSUInteger * _Nullable)fetchLimit fetchOffset:(NSUInteger * _Nullable)fetchOffset db:(FMDatabase *)db{
>>>>>>> persisting
    
    NSString* options = @"";
    
    if (orderBy) {
        NSString *order = [NSString stringWithFormat:@" ORDER BY %@", orderBy];
        options = [options stringByAppendingString:order];
    }
    
    if (fetchLimit) {
        NSString *limit = [NSString stringWithFormat:@" LIMIT %@", @(fetchLimit)];
        options = [options stringByAppendingString:limit];
    }
    
    if (fetchOffset) {
        NSString *offset = [NSString stringWithFormat:@" OFFSET %@", @(fetchOffset)];
        options = [options stringByAppendingString:offset];
    }
    
    name = [self entityToTableName:name];
    
    NSString* where = @"";
    
    if (predicate){
        where = [[STMPredicateToSQL sharedInstance] SQLFilterForPredicate:predicate entityName:name];
        if ([where isEqualToString:@"( )"] || [where isEqualToString:@"()"]){
            where = @"";
        }else{
            where = [@" WHERE " stringByAppendingString:where];
        }
    }
    
    where = [where stringByReplacingOccurrencesOfString:@" AND ()"
                                             withString:@""];
    where = [where stringByReplacingOccurrencesOfString:@"?uncapitalizedTableName?"
                                             withString:[STMFunctions lowercaseFirst:name]];
    where = [where stringByReplacingOccurrencesOfString:@"?capitalizedTableName?"
                                             withString:name];
    
    NSMutableArray *rez = @[].mutableCopy;

    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@%@%@", name, where, options];
    
    FMResultSet *s = [db executeQuery:query];
    
    while ([s next]) {
        [rez addObject:s.resultDictionary];
    }
    
    // there will be memory warnings loading catalogue on an old device if no copy
    return rez.copy;

}

- (BOOL) hasTable:(NSString * _Nonnull)name {
    name = [self entityToTableName:name];
    if ([columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

- (NSArray * _Nonnull) allKeysForObject:(NSString * _Nonnull)obj {
    obj = [self entityToTableName:obj];
    return columnsByTable[obj];
}

- (BOOL) commit {
    __block BOOL result = YES;
    [queue inDatabase:^(FMDatabase *db) {
        if ([db inTransaction]){
            result = [db commit];
        }
    }];
    return result;
}

- (BOOL) startTransaction {
    __block BOOL result = YES;
    [queue inDatabase:^(FMDatabase *db){
        if (![db inTransaction]){
            result = [db beginTransaction];
        }
    }];
    return result;
}
     
- (BOOL) rollback {
    __block BOOL result = YES;
    [queue inDatabase:^(FMDatabase *db){
        [db rollback];
    }];
    return result;
}

@end
