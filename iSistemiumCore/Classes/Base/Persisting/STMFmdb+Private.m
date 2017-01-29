//
//  STMFmdb+Private.m
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb+Private.h"
#import "STMFunctions.h"
#import "STMPersisting.h"

#define ExecDDL(ddlString) [self executeDDL:ddlString inDatabase:database]

@implementation STMFmdb (Private)

@dynamic columnsByTable;
@dynamic predicateToSQL;

- (NSString *)sqliteTypeForAttribute:(NSAttributeDescription *)attribute {
    
    switch (attribute.attributeType) {
        case NSStringAttributeType:
        case NSDateAttributeType:
        case NSUndefinedAttributeType:
        case NSBinaryDataAttributeType:
        case NSTransformableAttributeType:
            return @"TEXT";
        case NSInteger64AttributeType:
        case NSBooleanAttributeType:
        case NSObjectIDAttributeType:
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
            return @"INTEGER";
        case NSDecimalAttributeType:
        case NSFloatAttributeType:
        case NSDoubleAttributeType:
            return @"NUMERIC";
            break;
        default:
            return @"TEXT";
    }
    
}

- (NSDictionary*)createTablesWithModelling:(id <STMModelling>)modelling inDatabase:(FMDatabase *)database {
    
    NSDictionary <NSString *, NSEntityDescription *> *entities = modelling.entitiesByName;
    
    NSArray *ignoredAttributes = @[@"xid", @"id"];
    
    NSMutableDictionary *columnsDictionary = @{}.mutableCopy;
    
    NSString *createIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_%@ on %@ (%@);";
    NSString *fkColFormat = @"%@ TEXT REFERENCES %@(id) ON DELETE %@";
    NSString *createTableFormat = @"CREATE TABLE IF NOT EXISTS %@ (id TEXT PRIMARY KEY";
    
    NSString *createLtsTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_check_lts BEFORE UPDATE OF lts ON %@ FOR EACH ROW WHEN OLD.deviceTs > OLD.lts BEGIN SELECT RAISE(ABORT, 'ignored') WHERE OLD.deviceTs <> NEW.lts; END";
    
    NSString *createFantomTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_fantom_%@ BEFORE INSERT ON %@ FOR EACH ROW WHEN NEW.%@ is not null BEGIN INSERT INTO %@ (id, isFantom, lts, deviceTs) SELECT NEW.%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %@ WHERE id = NEW.%@); END";
    
    NSString *updateFantomTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_fantom_%@_update BEFORE UPDATE OF %@ ON %@ FOR EACH ROW WHEN NEW.%@ is not null BEGIN INSERT INTO %@ (id, isFantom, lts, deviceTs) SELECT NEW.%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %@ WHERE id = NEW.%@); END";
    
    NSString *fantomIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_isFantom on %@ (isFantom);";
    
    NSString *createCascadeTriggerFormat = @"DROP TRIGGER IF EXISTS %@_cascade_%@; CREATE TRIGGER IF NOT EXISTS %@_cascade_%@ BEFORE DELETE ON %@ FOR EACH ROW BEGIN DELETE FROM %@ WHERE %@ = OLD.id; END";
    
    NSString *isRemovedTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_isRemoved BEFORE INSERT ON %@ FOR EACH ROW BEGIN SELECT RAISE(IGNORE) FROM RecordStatus WHERE isRemoved = 1 AND objectXid = NEW.id LIMIT 1; END";
    
    for (NSString *entityName in entities){
        
        if ([modelling storageForEntityName:entityName] != STMStorageTypeFMDB){
            NSLog(@"STMFmdb ignore entity: %@", entityName);
            continue;
        }
        
        NSString *tableName = [STMFunctions removePrefixFromEntityName:entityName];
        NSMutableArray *columns = @[].mutableCopy;
        NSString *sql_stmt = [NSString stringWithFormat:createTableFormat, tableName];
        
        NSDictionary *tableColumns = [modelling fieldsForEntityName:entityName];
        
        for (NSString* columnName in tableColumns.allKeys){
            
            if ([ignoredAttributes containsObject:columnName]) continue;
            
            [columns addObject:columnName];
            
            NSAttributeDescription* atribute = tableColumns[columnName];
            
            NSMutableArray <NSString*> *columnDefinition = @[@","].mutableCopy;
            
            [columnDefinition addObject:columnName];
            [columnDefinition addObject:[self sqliteTypeForAttribute:atribute]];
            
            if ([columnName isEqualToString:@"deviceCts"]) {
                [columnDefinition addObject:@"DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW'))"];
            }
            
            if ([columnName isEqualToString:STMPersistingOptionLts]) {
                [columnDefinition addObject:@"DEFAULT('')"];
            }
            
            NSString* unique = [atribute.userInfo valueForKey:@"UNIQUE"];
            
            if (unique) {
                [columnDefinition addObject:[NSString stringWithFormat:@"UNIQUE ON CONFLICT %@", unique]];
            }
            
            sql_stmt = [sql_stmt stringByAppendingString:[columnDefinition componentsJoinedByString:@" "]];
            
        }
        
        NSDictionary *relationships = [modelling toOneRelationshipsForEntityName:entityName];
        
        for (NSString* entityKey in relationships.allKeys){
            
            sql_stmt = [sql_stmt stringByAppendingString:@", "];
            
            NSString *fkColumn = [entityKey stringByAppendingString:RELATIONSHIP_SUFFIX];
            
            NSString *fkTable = [STMFunctions removePrefixFromEntityName:relationships[entityKey]];
            
            NSString *cascadeAction = @"SET NULL";
            NSString *fkSQL = [NSString stringWithFormat:fkColFormat, fkColumn, fkTable, cascadeAction];
            
            [columns addObject:fkColumn];
            sql_stmt = [sql_stmt stringByAppendingString:fkSQL];
        }
        
        columnsDictionary[tableName] = columns.copy;
        
        sql_stmt = [sql_stmt stringByAppendingString:@" ); "];
        
        ExecDDL(sql_stmt);
        
        sql_stmt = [NSString stringWithFormat:fantomIndexFormat, tableName, tableName];
        ExecDDL(sql_stmt);
        
        sql_stmt = [NSString stringWithFormat:createLtsTriggerFormat, tableName, tableName, tableName];
        ExecDDL(sql_stmt);
        
        sql_stmt = [NSString stringWithFormat:isRemovedTriggerFormat, tableName, tableName];
        ExecDDL(sql_stmt);
        
        for (NSString* entityKey in [modelling toOneRelationshipsForEntityName:entityName].allKeys){
            NSString *fkColumn = [entityKey stringByAppendingString:RELATIONSHIP_SUFFIX];
            
            sql_stmt = [NSString stringWithFormat:createIndexFormat, tableName, entityKey, tableName, fkColumn];
            
            ExecDDL(sql_stmt);
            
            NSString *fkTable = [STMFunctions removePrefixFromEntityName:[modelling toOneRelationshipsForEntityName:entityName][entityKey]];
            
            sql_stmt = [NSString stringWithFormat:createFantomTriggerFormat, tableName, fkColumn, tableName, fkColumn, fkTable, fkColumn, fkTable, fkColumn];
            
            ExecDDL(sql_stmt);
            
            sql_stmt = [NSString stringWithFormat:updateFantomTriggerFormat, tableName, fkColumn, fkColumn, tableName, fkColumn, fkTable, fkColumn, fkTable, fkColumn];
            
            ExecDDL(sql_stmt);
            
        }
        
        NSDictionary <NSString *, NSRelationshipDescription*> *cascadeRelations = [modelling objectRelationshipsForEntityName:entityName isToMany:@(YES) cascade:@YES];
        
        for (NSString* relationKey in cascadeRelations.allKeys){
            
            NSRelationshipDescription *relation = cascadeRelations[relationKey];
            NSString *childTableName = [STMFunctions removePrefixFromEntityName:relation.destinationEntity.name];
            NSString *fkColumn = [relation.inverseRelationship.name stringByAppendingString:@"Id"];
            
            sql_stmt = [NSString stringWithFormat:createCascadeTriggerFormat, tableName, relationKey,tableName, relationKey,tableName, childTableName, fkColumn];
            
            ExecDDL(sql_stmt);
            
        }
        
        for (NSString* columnName in tableColumns.allKeys){
            
            NSAttributeDescription* atribute = tableColumns[columnName];
            
            if (!atribute.indexed || [ignoredAttributes containsObject:columnName]) continue;
            
            sql_stmt = [NSString stringWithFormat:createIndexFormat, tableName, atribute.name, tableName, atribute.name];

            ExecDDL(sql_stmt);
            
        }
        
    }
    
    return columnsDictionary.copy;
    
}

- (BOOL)executeDDL:(NSString *)ddl inDatabase:(FMDatabase *)database{
    BOOL res = [database executeStatements:ddl];
    if (!res) {
        NSLog(@"%@ (%@)", ddl, res ? @"YES" : @"NO");
    }
    return res;
}

- (NSString *) mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error db:(FMDatabase *)db{
    
    tablename = [STMFunctions removePrefixFromEntityName:tablename];
    
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
    
    name = [STMFunctions removePrefixFromEntityName:name];
    
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


@end
