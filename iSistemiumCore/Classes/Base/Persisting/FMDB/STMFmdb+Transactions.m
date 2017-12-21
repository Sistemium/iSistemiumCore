//
//  STMFmdb+Transactions.m
//  iSisSales
//
//  Created by Alexander Levin on 19/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb+Transactions.h"
#import "STMFunctions.h"

@interface STMFmdbTransaction ()

@property (nonatomic,weak) FMDatabase *database;
@property (nonatomic,weak) STMFmdb *stmFMDB;
@property (nonatomic,readonly) STMPredicateToSQL *predicator;

@end

@implementation STMFmdbTransaction

+ (instancetype)persistingTransactionWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB {
    return [[[self class] alloc] initWithFMDatabase:database stmFMDB:stmFMDB];
}

- (instancetype)initWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB{
    
    self = [self init];
    self.database = database;
    self.stmFMDB = stmFMDB;
    return self;
    
}

- (STMPredicateToSQL *)predicator {
    return self.stmFMDB.predicateToSQL;
}

#pragma mark - PersistingTransaction protocol

- (id <STMModelling>)modellingDelegate {
    return self.stmFMDB.modellingDelegate;
}

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    NSString *now = [STMFunctions stringFromNow];
    NSMutableDictionary *savingAttributes = attributes.mutableCopy;
    
    BOOL returnSaved = YES;
    
    if ([options[STMPersistingOptionReturnSaved] isEqual:@NO]) returnSaved = NO;
    
    if (options[STMPersistingOptionLts]) {
        [savingAttributes setValue:options[STMPersistingOptionLts] forKey:STMPersistingOptionLts];
        [savingAttributes removeObjectForKey:STMPersistingKeyVersion];
    } else {
        [savingAttributes setValue:now forKey:STMPersistingKeyVersion];
        [savingAttributes removeObjectForKey:STMPersistingOptionLts];
    }
    
    savingAttributes[@"deviceAts"] = now;
    
    if (![STMFunctions isNotNull:savingAttributes[STMPersistingKeyCreationTimestamp]]) {
        savingAttributes[STMPersistingKeyCreationTimestamp] = now;
    }
    
    NSString *tableName = [STMFunctions removePrefixFromEntityName:entityName];
    
    NSString *pk = [self mergeInto:tableName dictionary:savingAttributes.copy error:error];
    
    if (!pk || !returnSaved) return nil;
    
    return [self selectFrom:tableName where:[NSString stringWithFormat:@"id = '%@'", pk] orderBy:nil].firstObject;
    
}


- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {

    NSString *where = [self.predicator SQLFilterForPredicate:predicate];
    NSString *tablename = [STMFunctions removePrefixFromEntityName:entityName];
    
    if ([where isEqualToString:@"( )"] || [where isEqualToString:@"()"]){
        where = @"";
    }else{
        where = [@" WHERE " stringByAppendingString:where];
    }
    
    NSUInteger result = 0;
    
    NSString *limit = @"";
    
    if (options[STMPersistingOptionPageSize]) {
        limit = [NSString stringWithFormat:@" LIMIT %@", options[STMPersistingOptionPageSize]];
    }
    
    NSString* destroySQL = [NSString stringWithFormat:@"DELETE FROM %@%@%@", tablename, where, limit];
    
    if([self.database executeUpdate:destroySQL values:nil error:error]){
        result = [self.database changes];
    }
    
    return result;

}

- (NSArray *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset groupBy:(NSArray *)groupBy{
    
    NSString *options = @"";
    NSString *columns = @"";
    
    if (groupBy.count) {
        
        groupBy = [STMFunctions mapArray:groupBy withBlock:^id (id value) {
            return [NSString stringWithFormat:@"[%@]", value];
        }];
        options = [groupBy componentsJoinedByString:@", "];
        options = [@"GROUP BY " stringByAppendingString:options];

        NSMutableArray *columnKeys = groupBy.mutableCopy;
        [columnKeys addObjectsFromArray:[self sumKeysForEntityName:entityName]];
        [columnKeys addObject:@"count(*) [count()]"];
        
        columns = [columnKeys componentsJoinedByString:@", "];
        
    } else {
        columns = @"*";
    }
    
    if (orderBy) {
        orderBy = [[orderBy componentsSeparatedByString:@","] componentsJoinedByString:ascending?@" ASC,":@" DESC,"];
        NSString *order = [NSString stringWithFormat:@" ORDER BY %@ %@", orderBy, ascending ? @"ASC" : @"DESC"];
        options = [options stringByAppendingString:order];
    }
    
    if (fetchLimit > 0) {
        NSString *limit = [NSString stringWithFormat:@" LIMIT %lu", (unsigned long)fetchLimit];
        options = [options stringByAppendingString:limit];
    }
    
    if (fetchOffset > 0) {
        NSString *offset = [NSString stringWithFormat:@" OFFSET %lu", (unsigned long)fetchOffset];
        options = [options stringByAppendingString:offset];
    }
    
    entityName = [STMFunctions removePrefixFromEntityName:entityName];
    
    NSString* where = @"";
    
    if (predicate){
        where = [self.predicator SQLFilterForPredicate:predicate];
        where = [where stringByReplacingOccurrencesOfString:@" AND ()"
                                                 withString:@""];
        where = [where stringByReplacingOccurrencesOfString:@"?uncapitalizedTableName?"
                                                 withString:[STMFunctions lowercaseFirst:entityName]];
        where = [where stringByReplacingOccurrencesOfString:@"?capitalizedTableName?"
                                                 withString:entityName];
    }
    
    return [self selectFrom:entityName columns:columns where:where orderBy:options];
    
}

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error{
    
    NSUInteger pageSize = [options[STMPersistingOptionPageSize] integerValue];
    NSUInteger offset = [options[STMPersistingOptionStartPage] integerValue];
    NSArray *groupBy = options[STMPersistingOptionGroupBy];
    
    if (offset) {
        offset -= 1;
        offset *= pageSize;
    }
    
    NSString *orderBy = options[STMPersistingOptionOrder];
    
    BOOL asc = options[STMPersistingOptionOrderDirection] && [[options[STMPersistingOptionOrderDirection] lowercaseString] isEqualToString:@"asc"];
    
    if (!orderBy) orderBy = @"id";
    
    return [self findAllSync:entityName predicate:predicate orderBy:orderBy ascending:asc fetchLimit:pageSize fetchOffset:offset groupBy:groupBy];
    
}


- (NSDictionary *)updateWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    
    NSString *pk = attributes[@"id"];
    
    NSMutableArray* keys = @[].mutableCopy;
    NSMutableArray* values = @[].mutableCopy;
    
    NSString *tablename = [STMFunctions removePrefixFromEntityName:entityName];
    
    NSString* updateSQL = [self updateTablename:tablename attributes:attributes keys:keys values:values primaryKey:pk];
    
    [self.database executeUpdate:updateSQL values:values error:error];
    
    return [self selectFrom:tablename where:[NSString stringWithFormat:@"id = '%@'", pk] orderBy:nil].firstObject;
    
}

- (NSUInteger)count:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {

    NSUInteger count = 0;
    
    if (options[STMPersistingOptionForceStorage] && ![self.stmFMDB hasTable:entityName]) return 0;
    
    NSString *where = [self.predicator SQLFilterForPredicate:predicate];
    
    if (where.length) {
        where = [NSString stringWithFormat:@"WHERE %@", where];
    } else {
        where = @"";
    }
    
    NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM %@ %@",
                       [STMFunctions removePrefixFromEntityName:entityName], where];
    
    FMResultSet *s = [self.database executeQuery:query];
    
    while ([s next]) {
        count = (NSUInteger)[s.resultDictionary[@"count(*)"] integerValue];
    }
    
    return count;
    
}


#pragma mark - Private helpers

- (NSArray *)selectFrom:(NSString *)tableName where:(NSString *)where orderBy:(NSString *)orderBy {

    return [self selectFrom:tableName columns:@"*" where:where orderBy:orderBy];
    
}

- (NSArray *)selectFrom:(NSString *)tableName columns:(NSString *)columns where:(NSString *)where orderBy:(NSString *)orderBy {
    
    NSMutableArray *rez = @[].mutableCopy;
    
    if (where.length) {
        where = [@" WHERE " stringByAppendingString:where];
    } else {
        where = @"";
    }
    
    if (!orderBy) orderBy = @"";
    
    NSString *query = [NSString stringWithFormat:@"SELECT %@ FROM [%@]%@ %@", columns, tableName, where, orderBy];
    
    FMResultSet *s = [self.database executeQuery:query];
    
    NSArray *booleanKeys = [self.stmFMDB.columnsByTable[tableName] allKeysForObject:[NSNumber numberWithUnsignedInteger:NSBooleanAttributeType]];
    
    NSArray *jsonKeys = [self.stmFMDB.columnsByTable[tableName] allKeysForObject:[NSNumber numberWithUnsignedInteger:NSTransformableAttributeType]];

    while ([s next]) {
        
        NSMutableDictionary *dict = (NSMutableDictionary*)s.resultDictionary;

        for (NSString *key in booleanKeys){
            if ([STMFunctions isNotNull:[dict valueForKey:key]]){
                dict[key] = (__bridge id _Nullable)([dict[key] boolValue] ? kCFBooleanTrue : kCFBooleanFalse);
            }
        }
        
        for (NSString *key in jsonKeys){
            if ([STMFunctions isNotNull:[dict valueForKey:key]]){
                dict[key] = [STMFunctions jsonObjectFromString:dict[key]];
            }
        }
        
        [rez addObject:dict.copy];
    }
    
    // there will be memory warnings loading catalogue on an old device if no copy
    return rez.copy;
    
}

- (NSString *) mergeInto:(NSString *)tablename dictionary:(NSDictionary<NSString *, id> *)dictionary error:(NSError **)error {
    
    NSString *pk = dictionary [STMPersistingKeyPrimary] ? dictionary [STMPersistingKeyPrimary] : [STMFunctions uuidString];
    
    NSMutableArray* keys = @[].mutableCopy;
    NSMutableArray* values = @[].mutableCopy;
    
    NSString* updateSQL = [self updateTablename:tablename attributes:dictionary keys:keys values:values primaryKey:pk];
    
    if(![self.database executeUpdate:updateSQL values:values error:error]){
        
        if ([[*error localizedDescription] isEqualToString:@"ignored"]){
            *error = nil;
            return pk;
        }
        
        return nil;
        
    }
    
    if (!self.database.changes) {
        
        NSArray *questionMarks = [STMFunctions mapArray:keys withBlock:^id (id key) {return @"?";}];
        
        NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@, [isFantom], [id]) VALUES(%@, 0, ?)", tablename, [keys componentsJoinedByString:@", "], [questionMarks componentsJoinedByString:@", "]];
        
        if (![self.database executeUpdate:insertSQL values:values error:error]) {
            return nil;
        }
        
    }
    
    return pk;
    
}

- (NSArray *)sumKeysForEntityName:(NSString *)entityName {
    
    NSString *tableName = [STMFunctions removePrefixFromEntityName:entityName];
    
    NSArray <NSNumber *> *numericTypes = self.stmFMDB.numericAttributes;
    NSArray <NSNumber *> *minMaxTypes = self.stmFMDB.minMaxAttributes;
    
    NSDictionary *tableColumns = self.stmFMDB.columnsByTable[tableName];
    
    NSMutableArray *result = [NSMutableArray array];
    
    [tableColumns enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull field, id  _Nonnull type, BOOL * _Nonnull stop) {
        
        if ([self.stmFMDB.ignoredAttributes containsObject:field]) {
            return;
        }
        
        BOOL valueIsNumeric = [numericTypes containsObject:type];
        
        if (valueIsNumeric) {
            [result addObject:[NSString stringWithFormat:@"sum([%1$@]) [sum(%1$@)]", field]];
        } else if ([minMaxTypes containsObject:type]) {
            [result addObject:[NSString stringWithFormat:@"max([%1$@]) [max(%1$@)]", field]];
            [result addObject:[NSString stringWithFormat:@"min([%1$@]) [min(%1$@)]", field]];
        }
        
    }];

    return result.copy;
    
}

- (NSString*) updateTablename:(NSString *)tablename attributes:(NSDictionary *)attributes keys:(NSMutableArray *)keys values:(NSMutableArray *)values primaryKey:(NSString *)primaryKey{
    
    NSArray *columns = [self.stmFMDB.columnsByTable[tablename] allKeys];
    
    NSArray *jsonColumns = [self.stmFMDB.columnsByTable[tablename] allKeysForObject:@(NSTransformableAttributeType)];
    
    for (NSString* key in attributes) {
        
        if ([columns containsObject:key] && ![@[STMPersistingKeyPrimary, STMPersistingKeyPhantom, STMPersistingKeyCreationTimestamp] containsObject:key]){
            
            [keys addObject:[STMPredicateToSQL quotedName:key]];
            id value = [attributes objectForKey:key];
            
            if ([value isKindOfClass:[NSDate class]]) {
                
                [values addObject:[STMFunctions stringFromDate:(NSDate *)value]];
                
            } else if([jsonColumns containsObject:key]) {
                
                [values addObject:[STMFunctions jsonStringFromObject:value]];
                
            } else {
                
                [values addObject:(NSString*)value];
                
            }
            
        }
        
    }
    
    [values addObject:primaryKey];
    
    NSString* updateSQL = [NSString stringWithFormat:@"UPDATE %@ SET [isFantom] = 0, %@ = ? WHERE [id] = ?", tablename, [keys componentsJoinedByString:@" = ?, "]];
    
    return updateSQL;
    
}

@end


