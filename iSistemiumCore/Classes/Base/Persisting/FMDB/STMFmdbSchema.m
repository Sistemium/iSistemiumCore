//
//  STMFmdbSchema.m
//  iSisSales
//
//  Created by Alexander Levin on 05/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdbSchema.h"
#import "STMFunctions.h"
#import "FMDatabaseAdditions.h"

#define SQLiteText @"TEXT"
#define SQLiteInt @"INTEGER"
#define SQLiteNumber @"NUMERIC"

#define SQLiteDefaultNow @"DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW'))"

#define SQLiteStatementSeparator @"; "

@interface STMFmdbSchema()

@property (nonatomic,weak) FMDatabase *database;

@end



@implementation STMFmdbSchema


+ (instancetype)fmdbSchemaForDatabase:(FMDatabase *)database {
    return [[self alloc] initWithDatabase:database];
}


- (instancetype)initWithDatabase:(FMDatabase *)database {
    self = [self init];
    self.database = database;
    return self;
}


- (NSString *)sqliteTypeForAttributeType:(NSAttributeType)attributeType {
    
    switch (attributeType) {
        case NSStringAttributeType:
        case NSDateAttributeType:
        case NSUndefinedAttributeType:
        case NSBinaryDataAttributeType:
        case NSTransformableAttributeType:
            return SQLiteText;
        case NSInteger64AttributeType:
        case NSBooleanAttributeType:
        case NSObjectIDAttributeType:
        case NSInteger16AttributeType:
        case NSInteger32AttributeType:
            return SQLiteInt;
        case NSDecimalAttributeType:
        case NSFloatAttributeType:
        case NSDoubleAttributeType:
            return SQLiteNumber;
        default:
            return SQLiteText;
    }
    
}


- (NSDictionary*)createTablesWithModelling:(id <STMModelling>)modelling {
    
    NSArray *builtInAttributes = @[STMPersistingKeyPrimary,
                                   STMPersistingKeyCreationTimestamp,
                                   STMPersistingKeyVersion,
                                   STMPersistingOptionLts,
                                   STMPersistingKeyPhantom];
    
    NSArray *ignoredAttributes = [builtInAttributes arrayByAddingObjectsFromArray:@[@"xid"]];
    
    NSMutableDictionary *columnsDictionary = @{}.mutableCopy;

    NSString *createLtsTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_check_lts BEFORE UPDATE OF lts ON %@ FOR EACH ROW WHEN OLD.deviceTs > OLD.lts BEGIN SELECT RAISE(ABORT, 'ignored') WHERE OLD.deviceTs <> NEW.lts; END";
    
    NSString *fantomIndexFormat = @"CREATE INDEX IF NOT EXISTS %@_isFantom on %@ (isFantom);";
    
    NSString *cascadeTriggerFormat = @"DROP TRIGGER IF EXISTS %@_cascade_%@; CREATE TRIGGER IF NOT EXISTS %@_cascade_%@ BEFORE DELETE ON %@ FOR EACH ROW BEGIN DELETE FROM %@ WHERE %@ = OLD.id; END";
    
    NSString *isRemovedTriggerFormat = @"CREATE TRIGGER IF NOT EXISTS %@_isRemoved BEFORE INSERT ON %@ FOR EACH ROW BEGIN SELECT RAISE(IGNORE) FROM RecordStatus WHERE isRemoved = 1 AND objectXid = NEW.id LIMIT 1; END";
    
    for (NSString *entityName in modelling.entitiesByName){
        
        if ([modelling storageForEntityName:entityName] != STMStorageTypeFMDB){
            NSLog(@"STMFmdb ignore entity: %@", entityName);
            continue;
        }
        
        
        NSMutableArray <NSString *> *columns = builtInAttributes.mutableCopy;
        NSString *tableName = [STMFunctions removePrefixFromEntityName:entityName];
        BOOL tableExisted = [self.database tableExists:tableName];
        
        if (!tableExisted) {
            
            [self executeDDL:[self createTableDDL:tableName]];
            [self executeDDL:[NSString stringWithFormat:fantomIndexFormat, tableName, tableName]];
            [self executeDDL:[NSString stringWithFormat:createLtsTriggerFormat, tableName, tableName, tableName]];
            [self executeDDL:[NSString stringWithFormat:isRemovedTriggerFormat, tableName, tableName]];
            
        }
        
        NSArray *columnAttributes = [modelling fieldsForEntityName:entityName].allValues;
        NSPredicate *excludeBuiltIn = [NSPredicate predicateWithFormat:@"NOT (name IN %@)", ignoredAttributes];
        
        columnAttributes = [columnAttributes filteredArrayUsingPredicate:excludeBuiltIn];
        
        for (NSAttributeDescription *attribute in columnAttributes) {
            [columns addObject:attribute.name];
            // if the column exists we get an error
            // tableExisted check will replaced by modelMapping
            if (!tableExisted) {
                [self executeDDL:[self addAttributeDDL:attribute tableName:tableName]];
            }
        }
        
        NSArray *relationships = [modelling objectRelationshipsForEntityName:entityName isToMany:@NO cascade:nil].allValues;
        
        for (NSRelationshipDescription *relationship in relationships) {
            [columns addObject:[relationship.name stringByAppendingString:STMPersistingRelationshipSuffix]];
            if (!tableExisted) {
                [self executeDDL:[self addRelationshipDDL:relationship tableName:tableName]];
            }
        }
        
        columnsDictionary[tableName] = columns.copy;
        
        NSDictionary <NSString *, NSRelationshipDescription*> *cascadeRelations = [modelling objectRelationshipsForEntityName:entityName isToMany:@(YES) cascade:@YES];
        
        for (NSString* relationKey in cascadeRelations.allKeys){
            
            NSRelationshipDescription *relation = cascadeRelations[relationKey];
            NSString *childTableName = [STMFunctions removePrefixFromEntityName:relation.destinationEntity.name];
            NSString *fkColumn = [relation.inverseRelationship.name stringByAppendingString:STMPersistingRelationshipSuffix];
            
            [self executeDDL:[NSString stringWithFormat:cascadeTriggerFormat, tableName, relationKey,tableName, relationKey,tableName, childTableName, fkColumn]];
            
        }
        
    }
    
    return columnsDictionary.copy;
    
}


- (NSString *)createTableDDL:(NSString *)tableName {
    
    NSString *format = @"CREATE TABLE IF NOT EXISTS %@ (%@)";
    
    NSMutableArray *builtInColumns = [NSMutableArray array];
    
    [builtInColumns addObject:[self columnDDL:STMPersistingKeyPrimary datatype:SQLiteText constraints:@"PRIMARY KEY"]];
    
    [builtInColumns addObject:[self columnDDL:STMPersistingKeyCreationTimestamp datatype:SQLiteText constraints:SQLiteDefaultNow]];

    [builtInColumns addObject:[self columnDDL:STMPersistingKeyVersion datatype:SQLiteText constraints:nil]];

    [builtInColumns addObject:[self columnDDL:STMPersistingOptionLts datatype:SQLiteText constraints:@"DEFAULT('')"]];

    [builtInColumns addObject:[self columnDDL:STMPersistingKeyPhantom datatype:SQLiteInt constraints:nil]];

    return [NSString stringWithFormat:format, [self quoted:tableName], [builtInColumns componentsJoinedByString:@", "]];
    
}


- (NSString *)createIndexDDL:(NSString *)tableName columnName:(NSString *)columnName {
    NSString *format = @"CREATE INDEX IF NOT EXISTS %@_%@ on %@ (%@);";
    return [NSString stringWithFormat:format, tableName, columnName, tableName, columnName];
}

- (NSString *)columnDDL:(NSString *)columnName datatype:(NSString *)datatype constraints:(NSString *)constraints {
    
    NSMutableArray *clauses = [NSMutableArray array];
    
    [clauses addObject:[self quoted:columnName]];
    
    if (datatype) [clauses addObject:datatype];
    
    if (constraints) [clauses addObject:constraints];
    
    return [clauses componentsJoinedByString:@" "];
    
}


- (NSString *)addAttributeDDL:(NSAttributeDescription *)attribute tableName:(NSString *)tableName {
    
    NSString *dataType = [self sqliteTypeForAttributeType:attribute.attributeType];
//    NSString *constraints = [attribute.userInfo valueForKey:@"UNIQUE"];
//    
//    if (constraints) {
//        constraints = [NSString stringWithFormat:@"UNIQUE ON CONFLICT %@", constraints];
//    }
    
    NSString *columnName = attribute.name;
    
    NSString *columnDDL = [self columnDDL:columnName datatype:dataType constraints:nil];
    
    NSString *format = @"ALTER TABLE %@ ADD COLUMN %@";
    
    NSMutableArray *clauses = [NSMutableArray arrayWithObject:[NSString stringWithFormat:format, tableName, columnDDL]];
    
    if (attribute.indexed) {
        [clauses addObject:[self createIndexDDL:tableName columnName:columnName]];
    }
    
    return [clauses componentsJoinedByString:SQLiteStatementSeparator];
    
}

- (NSString *)addRelationshipDDL:(NSRelationshipDescription *)relationship tableName:(NSString *)tableName {
    
    NSString *columnName = [relationship.name stringByAppendingString:STMPersistingRelationshipSuffix];
    NSString *parentName = [STMFunctions removePrefixFromEntityName:relationship.destinationEntity.name];
    NSString *constraints = [NSString stringWithFormat:@"REFERENCES %@ ON DELETE SET NULL", parentName];
    NSString *columnDDL = [self columnDDL:columnName datatype:SQLiteText constraints:constraints];
    NSString *format = @"ALTER TABLE %@ ADD COLUMN %@";
    
    
    NSMutableArray *clauses = [NSMutableArray arrayWithObject:[NSString stringWithFormat:format, tableName, columnDDL]];
    
    [clauses addObject:[self createIndexDDL:tableName columnName:columnName]];

    // FIXME: too long line and too many parameters
    NSString *phantomTriggerFormat = [NSString stringWithFormat:@"CREATE TRIGGER IF NOT EXISTS %%@_fantom_%%@ BEFORE %%@ ON %%@ FOR EACH ROW WHEN NEW.%%@ is not null BEGIN INSERT INTO %%@ (%@, %@, %@, %@) SELECT NEW.%%@, 1, null, null WHERE NOT EXISTS (SELECT * FROM %%@ WHERE %@ = NEW.%%@); END", STMPersistingKeyPrimary, STMPersistingKeyPhantom, STMPersistingOptionLts, STMPersistingKeyVersion, STMPersistingKeyPrimary];
    
    [clauses addObject:[NSString stringWithFormat:phantomTriggerFormat, tableName, parentName, @"INSERT", tableName, columnName, parentName, columnName, parentName, columnName]];
    
    
    NSString *action = [@"UPDATE OF " stringByAppendingString:columnName];
    
    [clauses addObject:[NSString stringWithFormat:phantomTriggerFormat, tableName, [parentName stringByAppendingString:@"_update"], action, tableName, columnName, parentName, columnName, parentName, columnName]];
    
    
    return [clauses componentsJoinedByString:SQLiteStatementSeparator];
    
}


- (NSString *)quoted:(NSString *)aString {
    return [NSString stringWithFormat:@"[%@]", aString];
}

- (BOOL)executeDDL:(NSString *)ddl {
    BOOL res = [self.database executeStatements:ddl];
    if (!res) {
        NSLog(@"%@ (%@)", ddl, res ? @"YES" : @"NO");
    }
    return res;
}


@end
