//
//  STMFmdb+Transactions.m
//  iSisSales
//
//  Created by Alexander Levin on 19/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb+Transactions.h"
#import "STMFunctions.h"

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

#pragma mark - PersistingTransaction protocol

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error {
    
    NSString *now = [STMFunctions stringFromNow];
    NSMutableDictionary *savingAttributes = attributes.mutableCopy;
    
    BOOL returnSaved = YES;
    
    if ([options[STMPersistingOptionReturnSaved] isEqual:@NO]) returnSaved = NO;
    
    if (options[STMPersistingOptionLts]) {
        [savingAttributes setValue:options[STMPersistingOptionLts] forKey:STMPersistingOptionLts];
        [savingAttributes removeObjectForKey:@"deviceTs"];
    } else {
        [savingAttributes setValue:now forKey:@"deviceTs"];
        [savingAttributes removeObjectForKey:STMPersistingOptionLts];
    }
    
    savingAttributes[@"deviceAts"] = now;
    
    if (!savingAttributes[@"deviceCts"] || [savingAttributes[@"deviceCts"] isEqual:[NSNull null]]) {
        savingAttributes[@"deviceCts"] = now;
    }
    
    if(!returnSaved){
        [self.stmFMDB mergeInto:entityName dictionary:savingAttributes error:error db:self.database];
        return nil;
    }
    
    NSString *pk = [self.stmFMDB mergeInto:entityName dictionary:savingAttributes error:error db:self.database];
    
    if (!pk) return nil;
    
    NSArray *results = [self findAllSync:entityName
                               predicate:[NSPredicate predicateWithFormat:@"id == %@", pk]
                                 orderBy:nil
                               ascending:NO
                              fetchLimit:1
                             fetchOffset:0];
    
    return [results firstObject];
    
}


- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error {
    return [self.stmFMDB destroy:entityName predicate:predicate options:options error:error inDatabase:self.database];
}

- (NSArray *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset {
    return [self.stmFMDB getDataWithEntityName:entityName withPredicate:predicate orderBy:orderBy ascending:ascending fetchLimit:fetchLimit fetchOffset:fetchOffset db:self.database];
}


- (NSDictionary *)updateWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError *__autoreleasing *)error {
    return [self.stmFMDB update:entityName attributes:attributes error:error inDatabase:self.database];
}

@end


#pragma mark - Category methods

@implementation STMFmdb (Transactions)

- (NSString *) mergeInto:(NSString *)tablename dictionary:(NSDictionary<NSString *, id> *)dictionary error:(NSError **)error db:(FMDatabase *)db{
    
    tablename = [STMFunctions removePrefixFromEntityName:tablename];
    
    NSArray *columns = self.columnsByTable[tablename];
    NSString *pk = dictionary [@"id"] ? dictionary [@"id"] : [[[NSUUID alloc] init].UUIDString lowercaseString];
    
    NSMutableArray* keys = @[].mutableCopy;
    NSMutableArray* values = @[].mutableCopy;
    
    for (NSString* key in dictionary) {
        
        if ([columns containsObject:key] && ![@[@"id", @"isFantom"] containsObject:key]){
            
            [keys addObject:[STMPredicateToSQL quotedName:key]];
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
    
    NSString* updateSQL = [NSString stringWithFormat:@"UPDATE %@ SET [isFantom] = 0, %@ = ? WHERE [id] = ?", tablename, [keys componentsJoinedByString:@" = ?, "]];
    
    if(![db executeUpdate:updateSQL values:values error:error]){
        if ([[*error localizedDescription] isEqualToString:@"ignored"]){
            *error = nil;
            return pk;
        } else{
            return nil;
        }
    }
    
    if (!db.changes) {
        NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@, [isFantom], [id]) VALUES(%@, 0, ?)", tablename, [keys componentsJoinedByString:@", "], [v componentsJoinedByString:@", "]];
        if (![db executeUpdate:insertSQL values:values error:error]){
            return nil;
        }
    }
    
    return pk;
}


- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset db:(FMDatabase *)db{
    
    NSString* options = @"";
    
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

- (NSUInteger)destroy:(NSString *)tablename predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error inDatabase:(FMDatabase *)db {
    
    NSString *where = [self.predicateToSQL SQLFilterForPredicate:predicate];
    
    if ([where isEqualToString:@"( )"] || [where isEqualToString:@"()"]){
        where = @"";
    }else{
        where = [@" WHERE " stringByAppendingString:where];
    }
    
    NSUInteger result = 0;
    
    tablename = [STMFunctions removePrefixFromEntityName:tablename];
    NSString *limit = @"";
    
    if (options[STMPersistingOptionPageSize]) {
        limit = [NSString stringWithFormat:@" LIMIT %@", options[STMPersistingOptionPageSize]];
    }
    
    NSString* destroySQL = [NSString stringWithFormat:@"DELETE FROM %@%@%@", tablename, where, limit];
    
    if([db executeUpdate:destroySQL values:nil error:error]){
        result = [db changes];
    }
    
    return result;
}

- (NSDictionary *)update:(NSString *)tablename attributes:(NSDictionary<NSString *, id> *)attributes error:(NSError **)error inDatabase:(FMDatabase *)db {
    
    tablename = [STMFunctions removePrefixFromEntityName:tablename];
    
    NSArray *columns = self.columnsByTable[tablename];
    NSString *pk = attributes[@"id"];
    
    NSMutableArray* keys = @[].mutableCopy;
    NSMutableArray* values = @[].mutableCopy;
    
    for(NSString* key in attributes){
        if ([columns containsObject:key] && ![@[@"id", @"isFantom"] containsObject:key]){
            [keys addObject:key];
            id value = [attributes objectForKey:key];
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
    
    [db executeUpdate:updateSQL values:values error:error];
    
    NSUInteger fetchLimit = 1;
    NSUInteger fetchOffset = 0;
    
    NSArray *results = [self getDataWithEntityName:tablename
                                     withPredicate:[NSPredicate predicateWithFormat:@"id == %@", pk]
                                           orderBy:nil
                                         ascending:NO
                                        fetchLimit:fetchLimit
                                       fetchOffset:fetchOffset
                                                db:db];
    
    return [results firstObject];
    
}


@end

