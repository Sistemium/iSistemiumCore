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

#define SQLiteBeforeInsert @"BEFORE INSERT"
#define SQLiteBeforeDelete @"BEFORE DELETE"
#define SQLiteBeforeUpdateOf(column) [@"BEFORE UPDATE OF " stringByAppendingString:column]


@interface STMFmdbSchema()

@property (nonatomic,weak) FMDatabase *database;

@property (nonatomic, strong) NSArray *builtInAttributes;
@property (nonatomic, strong) NSArray *ignoredAttributes;

@property (nonatomic, strong) NSMutableDictionary *columnsDictionary;


@end


@implementation STMFmdbSchema

+ (instancetype)fmdbSchemaForDatabase:(FMDatabase *)database {
    return [[self alloc] initWithDatabase:database];
}

+ (NSArray *)builtInAttributes {
    
    return @[STMPersistingKeyPrimary,
             STMPersistingKeyCreationTimestamp,
             STMPersistingKeyVersion,
             STMPersistingOptionLts,
             STMPersistingKeyPhantom];
    
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

- (NSArray *)builtInAttributes {
    
    if (!_builtInAttributes) {
        _builtInAttributes = [[self class] builtInAttributes];
    }
    return _builtInAttributes;
    
}

- (NSArray *)ignoredAttributes {
    
    if (!_ignoredAttributes) {
        _ignoredAttributes = [self.builtInAttributes arrayByAddingObjectsFromArray:@[@"xid"]];
    }
    return _ignoredAttributes;
    
}

- (NSDictionary *)currentDBScheme {
    
    NSMutableDictionary *result = @{}.mutableCopy;

    FMResultSet *tablesSet = [self.database executeQuery:@"SELECT * FROM sqlite_master WHERE type='table' ORDER BY name"];
    
    while ([tablesSet next]) {
        
        NSString *tableName = [tablesSet stringForColumn:@"name"];
//        NSLog(@"%@", tableName);
        
        NSString *query = [NSString stringWithFormat:@"PRAGMA table_info('%@')", tableName];
        FMResultSet *columnsSet = [self.database executeQuery:query];
        
        NSMutableArray *columns = @[].mutableCopy;
        
        while ([columnsSet next]) {
            
            NSString *columnName = [columnsSet stringForColumn:@"name"];
//            NSLog(@"    %@", columnName);

            [columns addObject:columnName];
            
        }
        
        result[tableName] = columns;
        
    }

    return result.copy;
    
}


#pragma mark - createTablesWithModelMapping

- (NSDictionary *)createTablesWithModelMapping:(id <STMModelMapping>)modelMapping {

    self.migrationSuccessful = YES;
    self.columnsDictionary = [self currentDBScheme].mutableCopy;

// handle added entities
    for (NSEntityDescription *entityDescription in modelMapping.addedEntities) {
        [self addEntity:entityDescription];
    }
    
// handle removed entities
    for (NSEntityDescription *entityDescription in modelMapping.removedEntities) {
        [self deleteEntity:entityDescription];
    }
    
// handle removed properties
    [modelMapping.removedProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSPropertyDescription *> * _Nonnull obj, BOOL * _Nonnull stop) {
        
        NSEntityDescription *entity = modelMapping.destinationModel.entitiesByName[entityName];
        
        [self deleteEntity:entity];
        [self addEntity:entity];
                
    }];

// handle added properties
    if (modelMapping.addedProperties.count) {
        
        [modelMapping.addedAttributes enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSAttributeDescription *> * _Nonnull attributesArray, BOOL * _Nonnull stop) {
            
            [self addPropertiesArray:attributesArray
                    toEntityWithName:entityName
                        modelMapping:modelMapping];
            
        }];
        
        [modelMapping.addedRelationships enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull entityName, NSArray<NSRelationshipDescription *> * _Nonnull relationshipsArray, BOOL * _Nonnull stop) {
            
            [self addPropertiesArray:relationshipsArray
                    toEntityWithName:entityName
                        modelMapping:modelMapping];

        }];
        
    }
    
//    NSLog(@"columnsDictionary %@", self.columnsDictionary);
    
    if (self.migrationSuccessful) {
        
        [modelMapping migrationComplete];
        return self.columnsDictionary.copy;

    } else {
        return nil;
    }
    
}

- (void)addPropertiesArray:(NSArray <NSPropertyDescription *> *)propertiesArray toEntityWithName:(NSString *)entityName modelMapping:(id <STMModelMapping>)modelMapping {
    
    if (modelMapping.removedProperties[entityName]) {
        
        // this entity was added earlier
        return;
        
    }
    
    NSEntityDescription *entity = modelMapping.destinationModel.entitiesByName[entityName];
    
    NSString *tableName = [STMFunctions removePrefixFromEntityName:entity.name];
    
    NSMutableArray *columns = [self.columnsDictionary[tableName] mutableCopy];
    if (!columns) columns = @[].mutableCopy;
    
    NSArray *result = nil;
    
    if ([propertiesArray.firstObject isKindOfClass:[NSRelationshipDescription class]]) {
    
        result = [self addRelationships:(NSArray <NSRelationshipDescription *> *)propertiesArray
                                toTable:tableName];
        
    } else if ([propertiesArray.firstObject isKindOfClass:[NSAttributeDescription class]]) {
        
        result = [self addColumns:(NSArray <NSAttributeDescription *> *)propertiesArray
                          toTable:tableName];
    }
    
    if (result.count) [columns addObjectsFromArray:result];
    
    self.columnsDictionary[tableName] = columns;

}

- (void)addEntity:(NSEntityDescription *)entity {
    
    NSMutableArray <NSString *> *columns = self.builtInAttributes.mutableCopy;
    NSString *tableName = [STMFunctions removePrefixFromEntityName:entity.name];
    BOOL tableExisted = [self.database tableExists:tableName];
    
    if (!tableExisted) {
        self.migrationSuccessful &= [self executeDDL:[self createTableDDL:tableName]];
    }
    
    NSArray *propertiesColumns = [self processPropertiesForEntity:entity
                                                        tableName:tableName];
    
    [columns addObjectsFromArray:propertiesColumns];
    
    if (!columns) {
        
        [self.columnsDictionary removeObjectForKey:tableName];
        return;
        
    }
    
    self.columnsDictionary[tableName] = columns;
    
}

- (void)deleteEntity:(NSEntityDescription *)entity {
    
    NSString *tableName = [STMFunctions removePrefixFromEntityName:entity.name];
    
    BOOL result = [self executeDDL:[self dropTable:tableName]];
    
    if (result) {
        [self.columnsDictionary removeObjectForKey:tableName];
    }

    self.migrationSuccessful &= result;
    
}

- (NSArray <NSString *> *)processPropertiesForEntity:(NSEntityDescription *)entity tableName:(NSString *)tableName {
    
    NSMutableArray <NSString *> *columns = @[].mutableCopy;

    NSArray <NSAttributeDescription *> *columnAttributes = entity.attributesByName.allValues;
    NSPredicate *excludeBuiltIn = [NSPredicate predicateWithFormat:@"NOT (name IN %@)", self.ignoredAttributes];
    
    columnAttributes = [columnAttributes filteredArrayUsingPredicate:excludeBuiltIn];
    
    // it is noticeable faster (on a real device) to create columns with one statement with the table
    // but for now columns creation is separated to simplify code
    
    NSArray *addedColumns = [self addColumns:columnAttributes
                                     toTable:tableName];
    
    [columns addObjectsFromArray:addedColumns];
    
    NSArray <NSRelationshipDescription *> *relationships = entity.relationshipsByName.allValues;
    
    NSArray *addedRelationships = [self addRelationships:relationships
                                                 toTable:tableName];
    
    [columns addObjectsFromArray:addedRelationships];

    return columns.copy;
    
}

- (NSArray <NSString *> *)addColumns:(NSArray <NSAttributeDescription *> *)columnAttributes toTable:(NSString *)tableName {
    
    NSMutableArray <NSString *> *columns = @[].mutableCopy;

    for (NSAttributeDescription *attribute in columnAttributes) {
        
        [columns addObject:attribute.name];
        self.migrationSuccessful &= [self executeDDL:[self addAttributeDDL:attribute tableName:tableName]];
        
    }
    
    return columns.copy;

}

- (NSArray <NSString *> *)addRelationships:(NSArray <NSRelationshipDescription *> *)relationships toTable:(NSString *)tableName {
    
    NSMutableArray <NSString *> *columns = @[].mutableCopy;

    for (NSRelationshipDescription *relationship in relationships) {
        
        if (relationship.isToMany) {
            self.migrationSuccessful &= [self executeDDL:[self addToManyRelationshipDDL:relationship tableName:tableName]];
            continue;
        }
        
        [columns addObject:[relationship.name stringByAppendingString:STMPersistingRelationshipSuffix]];
        self.migrationSuccessful &= [self executeDDL:[self addRelationshipDDL:relationship tableName:tableName]];
        
    }
    
    return columns.copy;

}

- (NSString *)createTableDDL:(NSString *)tableName {
    
    NSString *format = @"CREATE TABLE IF NOT EXISTS [%@] (%@)";
    
    NSMutableArray *builtInColumns = [NSMutableArray array];
    
    [builtInColumns addObject:[self columnDDL:STMPersistingKeyPrimary datatype:SQLiteText constraints:@"PRIMARY KEY"]];
    
    [builtInColumns addObject:[self columnDDL:STMPersistingKeyCreationTimestamp datatype:SQLiteText constraints:SQLiteDefaultNow]];

    [builtInColumns addObject:[self columnDDL:STMPersistingKeyVersion datatype:SQLiteText constraints:nil]];

    [builtInColumns addObject:[self columnDDL:STMPersistingOptionLts datatype:SQLiteText constraints:@"DEFAULT('')"]];

    [builtInColumns addObject:[self columnDDL:STMPersistingKeyPhantom datatype:SQLiteInt constraints:nil]];

    NSMutableArray *clauses = [NSMutableArray array];
    
    // Add columns
    
    [clauses addObject:[NSString stringWithFormat:format, tableName, [builtInColumns componentsJoinedByString:@", "]]];
    
    // Index phantom column
    
    [clauses addObject:[self createIndexDDL:tableName columnName:STMPersistingKeyPhantom]];
    
    // Check Lts trigger
    
    NSString *whenUpdated = [NSString stringWithFormat:@"OLD.%@ > OLD.%@", STMPersistingKeyVersion, STMPersistingOptionLts];
    
    NSString *abortChanges = [NSString stringWithFormat:@"SELECT RAISE(ABORT, 'ignored') WHERE OLD.%@ <> NEW.%@", STMPersistingKeyVersion, STMPersistingOptionLts];
    
    [clauses addObject:[self createTriggerDDL:@"check_lts"
                                        event:SQLiteBeforeUpdateOf(STMPersistingOptionLts)
                                    tableName:tableName
                                         body:abortChanges
                                         when:whenUpdated]];
    
    // Check isRemoved trigger
    
    NSString *ignoreRemoved = [@[@"SELECT RAISE(IGNORE) FROM RecordStatus",
                                 @"WHERE isRemoved = 1 AND objectXid = NEW.%@ LIMIT 1"
                                 ] componentsJoinedByString:@" "];
    
    ignoreRemoved = [NSString stringWithFormat:ignoreRemoved, STMPersistingKeyPrimary];
    
    [clauses addObject:[self createTriggerDDL:@"isRemoved"
                                        event:SQLiteBeforeInsert
                                    tableName:tableName
                                         body:ignoreRemoved
                                         when:nil]];

    return [clauses componentsJoinedByString:SQLiteStatementSeparator];
    
}

- (NSString *)dropTable:(NSString *)tableName {
    return [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tableName];
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
    
    NSMutableArray *clauses = [NSMutableArray array];
    
    NSString *columnName = attribute.name;
    NSString *dataType = [self sqliteTypeForAttributeType:attribute.attributeType];
    NSString *columnDDL = [self columnDDL:columnName datatype:dataType constraints:nil];
        
    [clauses addObject:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@", tableName, columnDDL]];
    
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

    NSString *name = relationship.name;
    NSString *childTableName = [STMFunctions removePrefixFromEntityName:relationship.destinationEntity.name];
    NSString *fkColumn = [relationship.inverseRelationship.name stringByAppendingString:STMPersistingRelationshipSuffix];

    NSString *deleteChildren = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = OLD.%@", childTableName, fkColumn, STMPersistingKeyPrimary];
    
    return [self createTriggerDDL:[@"cascade_" stringByAppendingString:name]
                            event:SQLiteBeforeDelete
                        tableName:tableName
                             body:deleteChildren
                             when:nil];

}

- (NSString *)addRelationshipDDL:(NSRelationshipDescription *)relationship tableName:(NSString *)tableName {
    
    if (relationship.isToMany) {
        NSLog(@"attempt to add non-to-one relationship with addRelationshipDDL");
        return nil;
    }
    
    NSMutableArray *clauses = [NSMutableArray array];
    
    NSString *columnName = [relationship.name stringByAppendingString:STMPersistingRelationshipSuffix];
    NSString *parentName = [STMFunctions removePrefixFromEntityName:relationship.destinationEntity.name];
    NSString *constraints = [NSString stringWithFormat:@"REFERENCES %@ ON DELETE SET NULL", parentName];
    NSString *columnDDL = [self columnDDL:columnName datatype:SQLiteText constraints:constraints];
    
    [clauses addObject:[NSString stringWithFormat: @"ALTER TABLE [%@] ADD COLUMN %@", tableName, columnDDL]];
    
    // Index the column
    
    [clauses addObject:[self createIndexDDL:tableName columnName:columnName]];

    // Create Phantom triggers
    
    NSString *phantomFields = [NSString stringWithFormat:@"INSERT INTO [%@] (%@, %@, %@, %@)", parentName, STMPersistingKeyPrimary, STMPersistingKeyPhantom, STMPersistingOptionLts, STMPersistingKeyVersion];
    
    NSString *phantomData = [NSString stringWithFormat:@"SELECT NEW.%@, 1, null, null", columnName];
    
    NSString *phantomSource = [NSString stringWithFormat:@"WHERE NOT EXISTS (SELECT * FROM %@ WHERE %@ = NEW.%@)", parentName, STMPersistingKeyPrimary, columnName];
    
    NSString *columnNotNull = [NSString stringWithFormat:@"NEW.%@ is not null", columnName];
    
    
    NSString *createPhantom = [@[phantomFields, phantomData, phantomSource] componentsJoinedByString:@" "];
    
    
    [clauses addObject:[self createTriggerDDL:[@"phantom_" stringByAppendingString:columnName]
                                        event:SQLiteBeforeInsert
                                    tableName:tableName
                                         body:createPhantom
                                         when:columnNotNull]];

    [clauses addObject:[self createTriggerDDL:[@"phantom_update_" stringByAppendingString:columnName]
                                        event:SQLiteBeforeUpdateOf(columnName)
                                    tableName:tableName
                                         body:createPhantom
                                         when:columnNotNull]];
    
    
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

- (NSString *)createTriggerDDL:(NSString *)name event:(NSString *)event tableName:(NSString *)tableName body:(NSString *)body when:(NSString *)when {
    
    when = when ? [@"WHEN " stringByAppendingString:when] : @"";
    
    NSArray *formats = @[[NSString stringWithFormat:@"CREATE TRIGGER IF NOT EXISTS %@_%@", tableName, name],
                         [NSString stringWithFormat:@"%@ ON [%@] FOR EACH ROW %@", event, tableName, when],
                         [NSString stringWithFormat:@"BEGIN %@; END", body]];
    
    return [formats componentsJoinedByString:@" "];
    
}


@end
