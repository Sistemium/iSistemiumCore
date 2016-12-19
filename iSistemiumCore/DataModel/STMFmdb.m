//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMFmdb.h"

#import "FMDB.h"

@implementation STMFmdb

FMDatabase *database;
NSArray* tableNames;

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        database = [FMDatabase databaseWithPath:dbPath];
        
        if ([database open]){
            [database beginTransaction];
            NSString *sql_stmt = @"CREATE TABLE IF NOT EXISTS STMPrice (id TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, price NUMERIC, articleId TEXT REFERENCES STMArticle(id), priceTypeId TEXT REFERENCES STMPriceType(id) ) ";
            [database executeStatements:sql_stmt];
            sql_stmt = @"CREATE TABLE IF NOT EXISTS STMArticle (id TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, barcode TEXT, code TEXT, extraLabel TEXT,factor INTEGER, name TEXT, packageRel INTEGER, pieceVolume NUMERIC, pieceWeight NUMERIC, price NUMERIC, articleGroupId TEXT REFERENCES STMArticleGroup(id)) ";
            [database executeStatements:sql_stmt];
            sql_stmt = @"CREATE TABLE IF NOT EXISTS STMStock (id TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, displayVolume TEXT, volume INTEGER, articleId TEXT REFERENCES STMArticle(id)) ";
            [database executeStatements:sql_stmt];
            sql_stmt = @"CREATE TABLE IF NOT EXISTS STMArticleGroup (id TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, name TEXT, articleGroupId TEXT REFERENCES STMArticleGroup(id)) ";
            [database executeStatements:sql_stmt];
            sql_stmt = @"CREATE TABLE IF NOT EXISTS STMSaleOrderPosition (id TEXT PRIMARY KEY, commentText TEXT, deviceCts TEXT, deviceTs TEXT, INTEGER, lts TEXT, ownerXid TEXT, source TEXT, target TEXT, backVolume INTEGER, cost NUMERIC, price NUMERIC, priceDoc NUMERIC, priceOrigin NUMERIC, volume INTEGER, articleId TEXT REFERENCES STMArticle(id), saleorderId TEXT REFERENCES STMSaleOrder(id)) ";
            [database executeStatements:sql_stmt];
            
            NSMutableArray* names = @[].mutableCopy;
            sql_stmt = @"SELECT name FROM sqlite_master WHERE type='table'";
            FMResultSet* rs =[database executeQuery:sql_stmt];
            while ([rs next]) {
                [names addObject:[rs stringForColumn:@"name"]];
            }
            tableNames = names;
            [database commit];
            [database close];
        }
    }
    return self;
}

+ (STMFmdb *)sharedInstance {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
    
}

- (void)insertWithTablename:(NSString * _Nonnull)tablename array:(NSArray<NSDictionary<NSString *, id> *> * _Nonnull)array withCompletionHandler:(void (^ _Nonnull)(BOOL success))completionHandler{
    
    NSLog(@"Started inserting %@", tablename);
    if ([database open]) {
        [database beginTransaction];
        for (NSDictionary* dict in array){
            [self insertWithTablename:tablename dictionary:dict];
        }
        [database commit];
        [database close];
        completionHandler(true);
    } else {
        NSLog(@"STMFmdb error:  %@", [database lastErrorMessage])
        completionHandler(false);
    }
    NSLog(@"Done inserting %@", tablename);
    
}

- (void)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary {
    NSMutableArray* keys = @[].mutableCopy;
    
    NSMutableArray* values = @[].mutableCopy;
    
    for(NSString* key in dictionary){
        if ([key isEqualToString:@"ts"] || [key isEqualToString:@"discountPercent"]|| [key isEqualToString:@"author"]|| [key isEqualToString:@"articleSameId"]|| [key isEqualToString:@"productionInfoType"]){
        }else{
            [keys addObject:key];
            [values addObject:[dictionary objectForKey:key]];
        }
    }
    
    [keys addObject:@"lts"];
    [values addObject:[NSDate date]];
    NSMutableArray* v = @[].mutableCopy;
    for (int i=0;i<[keys count];i++){
        [v addObject:@"?"];
    }
    NSString* insertSQL = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) VALUES (%@)",tablename,[keys componentsJoinedByString:@", "], [v componentsJoinedByString:@", "]];
    
    [database executeUpdate:insertSQL withArgumentsInArray:values];
    
}

- (void)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary withCompletionHandler:(void (^ _Nonnull)(BOOL success))completionHandler{
    if ([database open]) {
        [self insertWithTablename:tablename dictionary:dictionary];
        completionHandler(true);
    } else {
        NSLog(@"STMFmdb error: %@", [database lastErrorMessage]);
        completionHandler(false);
    }
}

-(NSArray<NSDictionary *> * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name{
    
    NSMutableArray *rez = @[].mutableCopy;
    
    if ([database open]) {
        FMResultSet *s = [database executeQuery:[@"SELECT * FROM " stringByAppendingString:name]];
        while ([s next]) {
            [rez addObject:[s resultDictionary]];
        }
        [database close];
    } else {
        NSLog(@"STMFmdb error: \(database?.lastErrorMessage())")
    }
    return rez;
    
}

- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name{
    if ([tableNames containsObject:name]){
        return true;
    }
    NSLog(@"%@",name);
    return false;
}

@end
