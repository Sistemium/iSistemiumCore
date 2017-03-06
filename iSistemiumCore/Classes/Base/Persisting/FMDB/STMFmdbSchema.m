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

    // TODO: create only the new tables of the modelMapping, not all the modelling.entitiesByName
    
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
        }
        
        NSArray *columnAttributes = [modelling fieldsForEntityName:entityName].allValues;
        NSPredicate *excludeBuiltIn = [NSPredicate predicateWithFormat:@"NOT (name IN %@)", ignoredAttributes];
        
        columnAttributes = [columnAttributes filteredArrayUsingPredicate:excludeBuiltIn];
        
        // it is noticeable faster (on a real device) to create columns with one statement with the table
        // but for now columns creation is separated to simplify code
        
        for (NSAttributeDescription *attribute in columnAttributes) {
            [columns addObject:attribute.name];
            // if the column exists we get an error
            // TODO: add only new columns from modelMapping
            if (!tableExisted) {
                [self executeDDL:[self addAttributeDDL:attribute tableName:tableName]];
            }
        }
        
        NSArray *relationships = [modelling objectRelationshipsForEntityName:entityName isToMany:nil cascade:nil].allValues;
        
        for (NSRelationshipDescription *relationship in relationships) {
            if (relationship.isToMany) {
                [self executeDDL:[self addToManyRelationshipDDL:relationship tableName:tableName]];
            } else {
                [columns addObject:[relationship.name stringByAppendingString:STMPersistingRelationshipSuffix]];
                if (!tableExisted) {
                    [self executeDDL:[self addRelationshipDDL:relationship tableName:tableName]];
                }
            }
        }
        
        columnsDictionary[tableName] = columns.copy;
        
    }
    
    return columnsDictionary.copy;
    
}

+ (NSString *)ltsTriggerFormat {
    
    NSArray *formatParts = @[@"CREATE TRIGGER IF NOT EXISTS %%1$@_check_lts",
                             @"BEFORE UPDATE OF %1$@ ON %%1$@ FOR EACH ROW",
                             @"WHEN OLD.%2$@ > OLD.%1$@ BEGIN",
                             @"SELECT RAISE(ABORT, 'ignored') WHERE OLD.%2$@ <> NEW.%1$@; END"];
    
    NSString *format = [formatParts componentsJoinedByString:@" "];
    
    return [NSString stringWithFormat:format, STMPersistingOptionLts, STMPersistingKeyVersion];
    
}

- (NSString *)createTableDDL:(NSString *)tableName {
    
    NSString *format = @"CREATE TABLE IF NOT EXISTS %@ (%@)";
    
    NSMutableArray *builtInColumns = [NSMutableArray array];
    
    [builtInColumns addObject:[self columnDDL:STMPersistingKeyPrimary datatype:SQLiteText constraints:@"PRIMARY KEY"]];
    
    [builtInColumns addObject:[self columnDDL:STMPersistingKeyCreationTimestamp datatype:SQLiteText constraints:SQLiteDefaultNow]];

    [builtInColumns addObject:[self columnDDL:STMPersistingKeyVersion datatype:SQLiteText constraints:nil]];

    [builtInColumns addObject:[self columnDDL:STMPersistingOptionLts datatype:SQLiteText constraints:@"DEFAULT('')"]];

    [builtInColumns addObject:[self columnDDL:STMPersistingKeyPhantom datatype:SQLiteInt constraints:nil]];

    NSMutableArray *clauses = [NSMutableArray array];
    
    [clauses addObject:[NSString stringWithFormat:format, [self quoted:tableName], [builtInColumns componentsJoinedByString:@", "]]];
    
    [clauses addObject:[self createIndexDDL:tableName columnName:STMPersistingKeyPhantom]];
    
    NSArray *parts = @[@"CREATE TRIGGER IF NOT EXISTS %1$@_isRemoved",
                       @"BEFORE INSERT ON %1$@ FOR EACH ROW BEGIN",
                       @"SELECT RAISE(IGNORE) FROM RecordStatus",
                       [NSString stringWithFormat:@"WHERE isRemoved = 1 AND objectXid = NEW.%@ LIMIT 1; END", STMPersistingKeyPrimary]
                       ];
    
    NSString *isRemovedTriggerFormat = [parts componentsJoinedByString:@" "];

    [clauses addObject:[NSString stringWithFormat:[self.class ltsTriggerFormat], tableName]];
    [clauses addObject:[NSString stringWithFormat:isRemovedTriggerFormat, tableName]];

    return [clauses componentsJoinedByString:SQLiteStatementSeparator];
    
}

- (NSString *)createIndexDDL:(NSString *)tableName columnName:(NSString *)columnName {
    NSString *format = @"CREATE INDEX IF NOT EXISTS %1$@_%2$@ on %1$@ (%2$@);";
    return [NSString stringWithFormat:format, tableName, columnName];
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

- (NSString *)addToManyRelationshipDDL:(NSRelationshipDescription *)relationship tableName:(NSString *)tableName {

    if (!relationship.isToMany) {
        NSLog(@"attempt to add non-to-many relationship with addToManyRelationshipDDL");
        return nil;
    }
    
    if (relationship.deleteRule != NSCascadeDeleteRule) return nil;

    NSArray *formatParts = @[@"DROP TRIGGER IF EXISTS %%1$@_cascade_%%2$@;",
                             @"CREATE TRIGGER IF NOT EXISTS %%1$@_cascade_%%2$@",
                             @"BEFORE DELETE ON %%1$@",
                             @"FOR EACH ROW BEGIN DELETE FROM %%3$@",
                             @"WHERE %%4$@ = OLD.%@; END"];
    
    NSString *format = [formatParts componentsJoinedByString:@" "];
    
    NSString *cascadeTriggerFormat = [NSString stringWithFormat:format, STMPersistingKeyPrimary];

    NSString *name = relationship.name;
    NSString *childTableName = [STMFunctions removePrefixFromEntityName:relationship.destinationEntity.name];
    NSString *fkColumn = [relationship.inverseRelationship.name stringByAppendingString:STMPersistingRelationshipSuffix];
    
    return [NSString stringWithFormat:cascadeTriggerFormat, tableName, name, childTableName, fkColumn];

}

- (NSString *)addRelationshipDDL:(NSRelationshipDescription *)relationship tableName:(NSString *)tableName {
    
    if (relationship.isToMany) {
        NSLog(@"attempt to add non-to-one relationship with addRelationshipDDL");
        return nil;
    }
    
    NSString *columnName = [relationship.name stringByAppendingString:STMPersistingRelationshipSuffix];
    NSString *parentName = [STMFunctions removePrefixFromEntityName:relationship.destinationEntity.name];
    NSString *constraints = [NSString stringWithFormat:@"REFERENCES %@ ON DELETE SET NULL", parentName];
    NSString *columnDDL = [self columnDDL:columnName datatype:SQLiteText constraints:constraints];
    NSString *format = @"ALTER TABLE %@ ADD COLUMN %@";
    
    
    NSMutableArray *clauses = [NSMutableArray arrayWithObject:[NSString stringWithFormat:format, tableName, columnDDL]];
    
    [clauses addObject:[self createIndexDDL:tableName columnName:columnName]];

    // FIXME: too long line and too many parameters
    
    NSArray *formatParts = @[@"CREATE TRIGGER IF NOT EXISTS %%1$@_fantom_%%2$@",
                             @"BEFORE %%3$@ ON %%1$@ FOR EACH ROW",
                             @"WHEN NEW.%%4$@ is not null",
                             @"BEGIN INSERT INTO %%5$@ (%1$@, %@, %@, %@)",
                             @"SELECT NEW.%%4$@, 1, null, null",
                             @"WHERE NOT EXISTS (SELECT * FROM %%5$@ WHERE %1$@ = NEW.%%4$@); END"];
    
    format = [formatParts componentsJoinedByString:@" "];

    NSString *phantomTriggerFormat = [NSString stringWithFormat:format, STMPersistingKeyPrimary, STMPersistingKeyPhantom, STMPersistingOptionLts, STMPersistingKeyVersion];
    
    [clauses addObject:[NSString stringWithFormat:phantomTriggerFormat, tableName, parentName, @"INSERT", columnName, parentName]];
    
    
    NSString *action = [@"UPDATE OF " stringByAppendingString:columnName];

    [clauses addObject:[NSString stringWithFormat:phantomTriggerFormat, tableName, [parentName stringByAppendingString:@"_update"], action, columnName, parentName]];
    
    
    return [clauses componentsJoinedByString:SQLiteStatementSeparator];
    
}

- (NSString *)quoted:(NSString *)aString {
    return [NSString stringWithFormat:@"[%@]", aString];
}

- (BOOL)executeDDL:(NSString *)ddl {
    
    if (!ddl.length) return YES;
    
    BOOL res = [self.database executeStatements:ddl];
    
    if (!res) {
        NSLog(@"%@ (%@)", ddl, res ? @"YES" : @"NO");
    }
    
    return res;

}


@end
