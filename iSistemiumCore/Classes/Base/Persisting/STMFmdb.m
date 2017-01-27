//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

//Note: The calls to FMDatabaseQueue's methods are blocking. So even though you are passing along blocks, they will not be run on another thread.

#import "STMFmdb+Private.h"
#import "STMFunctions.h"
#import "FMDB.h"
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
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        
        self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        self.pool = [FMDatabasePool databasePoolWithPath:dbPath];

        [self.queue inDatabase:^(FMDatabase *database){
            self.columnsByTable = [self createTablesWithModelling:modelling inDatabase:database];
        }];
    }
    
    return self;
    
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

- (NSUInteger) count:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate {
    
    __block NSUInteger rez;
    
    [self.pool inDatabase:^(FMDatabase *db) {
        
        NSString* query = [NSString stringWithFormat:@"SELECT count(*) FROM %@", [STMFunctions removePrefixFromEntityName:name]];
        
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
    
    NSString* destroySQL = [NSString stringWithFormat:@"DELETE FROM %@%@", [STMFunctions removePrefixFromEntityName:tablename],where];
    
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

- (BOOL) hasTable:(NSString * _Nonnull)name {
    name = [STMFunctions removePrefixFromEntityName:name];
    if ([self.columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
}

- (NSArray * _Nonnull) allKeysForObject:(NSString * _Nonnull)obj {
    obj = [STMFunctions removePrefixFromEntityName:obj];
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
