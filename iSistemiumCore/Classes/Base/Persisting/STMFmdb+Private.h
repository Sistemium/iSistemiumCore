//
//  STMFmdb+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb.h"
#import "FMDB.h"
#import "STMPredicateToSQL.h"

CF_ASSUME_NONNULL_BEGIN

@interface STMFmdb (Private)

@property (nonatomic, strong) NSDictionary * columnsByTable;
@property (nonatomic, strong) STMPredicateToSQL *predicateToSQL;

- (NSString *)sqliteTypeForAttribute:(NSAttributeDescription *)attribute;


- (NSDictionary*)createTablesWithModelling:(id <STMModelling>)modelling
                                inDatabase:(FMDatabase *)database;

- (NSString *)mergeInto:(NSString * _Nonnull)tablename
             dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary
                  error:(NSError *_Nonnull * _Nonnull)error
                     db:(FMDatabase * _Nonnull)db;

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name
                              withPredicate:(NSPredicate * _Nonnull)predicate
                                    orderBy:(NSString * _Nullable)orderBy
                                  ascending:(BOOL)ascending
                                 fetchLimit:(NSUInteger * _Nullable)fetchLimit
                                fetchOffset:(NSUInteger * _Nullable)fetchOffset
                                         db:(FMDatabase *)db;

CF_ASSUME_NONNULL_END

@end
