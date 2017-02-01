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
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
#warning database name should be with user id and iSisDB
    NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
    
    self.predicateToSQL = [STMPredicateToSQL predicateToSQLWithModelling:modelling];
    self.queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    self.pool = [FMDatabasePool databasePoolWithPath:dbPath];

    [self.queue inDatabase:^(FMDatabase *database){
        self.columnsByTable = [self createTablesWithModelling:modelling inDatabase:database];
    }];
    
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

- (NSUInteger) count:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate {
    
    __block NSUInteger rez;
    
    [self.pool inDatabase:^(FMDatabase *db) {
        
        NSString *where = [self.predicateToSQL SQLFilterForPredicate:predicate];
        
        if (where.length) {
            where = [NSString stringWithFormat:@"WHERE %@", where];
        } else {
            where = @"";
        }
        
        NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM %@ %@",
                           [STMFunctions removePrefixFromEntityName:name], where];
        
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

- (BOOL) hasTable:(NSString * _Nonnull)name {
    name = [STMFunctions removePrefixFromEntityName:name];
    if ([self.columnsByTable.allKeys containsObject:name]){
        return true;
    }
    return false;
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
