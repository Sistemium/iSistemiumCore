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

@interface STMFmdb()

@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, strong) FMDatabasePool *pool;
@property (nonatomic, strong) NSDictionary *columnsByTable;
@property (nonatomic, strong) STMPredicateToSQL *predicateToSQL;

@end

@implementation STMFmdb


- (instancetype _Nonnull)initWithModelling:(id <STMModelling> _Nonnull)modelling {
    
    self = [super init];
    self.predicateToSQL = [[STMPredicateToSQL alloc] init];
    self.predicateToSQL.modellingDelegate = modelling;
    
    if (self) {
        
        NSDictionary <NSString *, NSEntityDescription *> *entities = modelling.entitiesByName;
        NSArray *entityNames = entities.allKeys;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        
        NSArray *ignoredAttributes = @[@"xid", @"id"];
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        
        self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        self.pool = [FMDatabasePool databasePoolWithPath:dbPath];
        
        NSMutableDictionary *columnsDictionary = @{}.mutableCopy;
        
        [self.queue inDatabase:^(FMDatabase *database){
            
            NSString *createIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_%@ on %@ (%@);";
            NSString *fkColFormat = @"%@ TEXT REFERENCES %@(id) ON DELETE %@";
            NSString *createTableFormat = @"CREATE TABLE IF NOT EXISTS %@ (id TEXT PRIMARY KEY";
            NSString *createLtsTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_check_lts BEFORE UPDATE OF lts ON %@ FOR EACH ROW WHEN OLD.deviceTs > OLD.lts BEGIN SELECT RAISE(ABORT, 'ignored') WHERE OLD.deviceTs <> NEW.lts; END";
            
            NSString *createFantomTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_fantom_%@ BEFORE INSERT ON %@ FOR EACH ROW WHEN NEW.%@ is not null BEGIN INSERT INTO %@ (id, isFantom, lts, deviceTs) SELECT NEW.%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %@ WHERE id = NEW.%@); END";
            NSString *updateFantomTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_fantom_%@_update BEFORE UPDATE OF %@ ON %@ FOR EACH ROW WHEN NEW.%@ is not null BEGIN INSERT INTO %@ (id, isFantom, lts, deviceTs) SELECT NEW.%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %@ WHERE id = NEW.%@); END";
            NSString *fantomIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_isFantom on %@ (isFantom);";
            
            NSString *createCascadeTriggerFormat = @"DROP TRIGGER IF EXISTS %@_cascade_%@; CREATE TRIGGER IF NOT EXISTS %@_cascade_%@ BEFORE DELETE ON %@ FOR EACH ROW BEGIN DELETE FROM %@ WHERE %@ = OLD.id; END";
            
            NSString *isRemovedTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_isRemoved BEFORE INSERT ON %@ FOR EACH ROW BEGIN SELECT RAISE(IGNORE) FROM RecordStatus WHERE isRemoved = 1 AND objectXid = NEW.id LIMIT 1; END";
            
            
            for (NSString* entityName in entityNames){
                
                NSString *storeOption = [entities[entityName] userInfo][@"STORE"];
                
                if ((storeOption && ![storeOption isEqualToString:@"FMDB"]) || entities[entityName].abstract){
                    NSLog(@"STMFmdb ignore entity: %@", entityName);
                    continue;
                }
                
                NSString *tableName = [self entityToTableName:entityName];
                NSMutableArray *columns = @[].mutableCopy;
                NSString *sql_stmt = [NSString stringWithFormat:createTableFormat, tableName];
                
                NSDictionary *tableColumns = [STMCoreObjectsController allObjectsWithTypeForEntityName:entityName];
                
                for (NSString* columnName in tableColumns.allKeys){
                    
                    if ([ignoredAttributes containsObject:columnName]) continue;
                    
                    sql_stmt = [sql_stmt stringByAppendingString:@", "];
                    
                    [columns addObject:columnName];
                    sql_stmt = [sql_stmt stringByAppendingString:columnName];
                    
                    NSAttributeDescription* atribute = tableColumns[columnName];
                    
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
                    
                    NSString* unique = [atribute.userInfo valueForKey:@"UNIQUE"];
                    
                    if (unique) {
                        sql_stmt = [sql_stmt stringByAppendingFormat:@" UNIQUE ON CONFLICT %@", unique];
                    }
                    
                }
                
                NSDictionary *relationships = [STMCoreObjectsController toOneRelationshipsForEntityName:entityName];
                
                for (NSString* entityKey in relationships.allKeys){
                    
                    sql_stmt = [sql_stmt stringByAppendingString:@", "];
                    
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
                
                NSDictionary <NSString *, NSRelationshipDescription*> *cascadeRelations = [STMCoreObjectsController objectRelationshipsForEntityName:entityName isToMany:@(YES) cascade:@YES];
                
                for (NSString* relationKey in cascadeRelations.allKeys){
                    
                    NSRelationshipDescription *relation = cascadeRelations[relationKey];
                    NSString *childTableName = [self entityToTableName:relation.destinationEntity.name];
                    NSString *fkColumn = [relation.inverseRelationship.name stringByAppendingString:@"Id"];
                    
                    sql_stmt = [NSString stringWithFormat:createCascadeTriggerFormat, tableName, relationKey,tableName, relationKey,tableName, childTableName, fkColumn];
                    res = [database executeStatements:sql_stmt];
                    NSLog(@"%@ (%@)", sql_stmt, res ? @"YES" : @"NO");
                    
                }
                
                for (NSString* columnName in tableColumns.allKeys){
                    
                    NSAttributeDescription* atribute = tableColumns[columnName];
                    
                    if (!atribute.indexed || [ignoredAttributes containsObject:columnName]) continue;
                    
                    NSString *createIndexSQL = [NSString stringWithFormat:createIndexFormat, tableName, atribute.name, tableName, atribute.name];
                    res = [database executeStatements:createIndexSQL];
                    NSLog(@"%@ (%@)", createIndexSQL, res ? @"YES" : @"NO");
                    
                }
                
            }
            
            self.columnsByTable = columnsDictionary.copy;
            
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


- (NSDictionary * _Nullable)mergeIntoAndResponse:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error{
    
    __block NSDictionary *response;
    
    [self.queue inDatabase:^(FMDatabase *db) {
        
        NSString *pk = [self mergeInto:tablename dictionary:dictionary error:error db:db];
        
        if (!pk) return;
        
        NSArray *results = [self getDataWithEntityName:tablename
                                         withPredicate:[NSPredicate predicateWithFormat:@"id == %@", pk]
                                               orderBy:nil
                                             ascending:NO
                                            fetchLimit:nil
                                           fetchOffset:nil
                                                    db:db];
        
        response = [results firstObject];
        
    }];
    
    return response;
    
}

- (BOOL) mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error {
    
    __block BOOL result;
    
    [self.queue inDatabase:^(FMDatabase *db) {
        result = !![self mergeInto:tablename
                        dictionary:dictionary
                             error:error
                                db:db];
    }];
    
    return result;
}

- (NSString *) mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error db:(FMDatabase *)db{
    
    tablename = [self entityToTableName:tablename];
    
    NSArray *columns = self.columnsByTable[tablename];
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

- (NSUInteger) count:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate {
    
    __block NSUInteger rez;
    
    [self.pool inDatabase:^(FMDatabase *db) {
        
        NSString* query = [NSString stringWithFormat:@"SELECT count(*) FROM %@", [self entityToTableName:name]];
        
        FMResultSet *s = [db executeQuery:query];
        
        while ([s next]) {
            rez = (NSUInteger)[s.resultDictionary[@"count(*)"] integerValue];
        }
        
    }];
    
    return rez;
}

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger * _Nullable)fetchLimit fetchOffset:(NSUInteger * _Nullable)fetchOffset{
    
    __block NSArray* results;
    
    [self.pool inDatabase:^(FMDatabase *db) {
        
        results = [self getDataWithEntityName:name
                                withPredicate:predicate
                                      orderBy:orderBy
                                    ascending:ascending
                                   fetchLimit:fetchLimit
                                  fetchOffset:fetchOffset
                                           db:db];
        
    }];
    
    return results;
}

- (NSUInteger)destroy:(NSString * _Nonnull)tablename predicate:(NSPredicate* _Nonnull)predicate error:(NSError *_Nonnull * _Nonnull)error{
    
    NSString *where = [self.predicateToSQL SQLFilterForPredicate:predicate];
    
    if ([where isEqualToString:@"( )"] || [where isEqualToString:@"()"]){
        where = @"";
    }else{
        where = [@" WHERE " stringByAppendingString:where];
    }
    
    __block NSUInteger result = 0;
    
    NSString* destroySQL = [NSString stringWithFormat:@"DELETE FROM %@%@", [self entityToTableName:tablename],where];
    
    [self.queue inDatabase:^(FMDatabase *db) {
        if([db executeUpdate:destroySQL values:nil error:error]){
            result = [db changes];
        }
    }];
    
    return result;
}

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger * _Nullable)fetchLimit fetchOffset:(NSUInteger * _Nullable)fetchOffset db:(FMDatabase *)db{
    
    NSString* options = @"";
    
    if (orderBy) {
        NSString *order = [NSString stringWithFormat:@" ORDER BY %@ %@", orderBy, ascending ? @"ASC" : @"DESC"];
        options = [options stringByAppendingString:order];
    }
    
    if (fetchLimit) {
        NSString *limit = [NSString stringWithFormat:@" LIMIT %lu", (unsigned long)*fetchLimit];
        options = [options stringByAppendingString:limit];
    }
    
    if (fetchOffset) {
        NSString *offset = [NSString stringWithFormat:@" OFFSET %lu", (unsigned long)*fetchOffset];
        options = [options stringByAppendingString:offset];
    }
    
    name = [self entityToTableName:name];
    
    NSString* where = @"";
    
    if (predicate){
        where = [self.predicateToSQL SQLFilterForPredicate:predicate];
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
    if ([self.columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

- (NSArray * _Nonnull) allKeysForObject:(NSString * _Nonnull)obj {
    obj = [self entityToTableName:obj];
    return self.columnsByTable[obj];
}

- (BOOL) commit {
    __block BOOL result = YES;
    [self.queue inDatabase:^(FMDatabase *db) {
        if ([db inTransaction]){
            result = [db commit];
        }
    }];
    return result;
}

- (BOOL) startTransaction {
    __block BOOL result = YES;
    [self.queue inDatabase:^(FMDatabase *db){
        if (![db inTransaction]){
            result = [db beginTransaction];
        }
    }];
    return result;
}

- (BOOL) rollback {
    __block BOOL result = YES;
    [self.queue inDatabase:^(FMDatabase *db){
        [db rollback];
    }];
    return result;
}

@end
